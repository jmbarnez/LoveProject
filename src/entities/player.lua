local Util = require("src.core.util")
local Turret = require("src.systems.turret.core")
local Content = require("src.content.content")
local Config = require("src.content.config")
local EntityFactory = require("src.templates.entity_factory")
local Log = require("src.core.log")
-- ShieldDurability removed - shields now provided by equipment modules

-- Inherit from the Ship template to get shared functionality like the 'hit' method.
local Ship = require("src.templates.ship")
local Player = setmetatable({}, { __index = Ship })
Player.__index = Player

function Player.new(x, y, shipId)
  -- Create the base ship using the factory.
  local shipConfig = Content.getShip(shipId or "starter_frigate_basic")
  local ship = EntityFactory.createPlayer(shipId or "starter_frigate_basic", x, y)
  if not ship then return nil end

  -- Set the metatable to this Player object to add player-specific methods.
  local self = setmetatable(ship, Player)
  self.ship = shipConfig -- Store the ship's definition data
  self.isPlayer = true -- Ensure this flag is set.
  -- Shield system removed - shields now provided by equipment modules
    if not self.components.physics then
        self.components.physics = require("src.components.physics").new({
            mass = (shipConfig.engine and shipConfig.engine.mass) or 500,
            x = x,
            y = y
        })
    end

  -- Set direct control mode for player physics (visual thrusters only, no force)
  if self.components.physics and self.components.physics.body then
    self.components.physics.body.skipThrusterForce = true
  end

  -- Initialize inventory if it doesn't exist
  if not self.inventory then
    self.inventory = {}
  end
  -- Initialize ordered inventory slots (6x4 grid)
  if not self.inventory_slots then
    self.inventory_slots = {}
  end

  -- Initialize shield HP based on equipped modules
  self:updateShieldHP()

  -- Player-specific defaults
  self.moveTarget = nil
  self.level = 1
  self.xp = 0
  self.gc = 10000
  self.docked = false
  self.weaponsDisabled = false
  self.wasInHub = false
  self.canDock = false

  -- Lock-on targeting system removed - combat works differently now

  self.active_quests = {}
  self.quest_progress = {}
  -- Override the renderable type to use the specific 'player' renderer
  if self.components and self.components.renderable then
      self.components.renderable.type = "player"
  end

  -- Turrets are provided by the ship template via components.equipment.turrets.
  -- No additional default turrets are added here.

  -- Default inventory will be initialized by game setup (see Game.load).

  self:resetDurability()
  return self
end

-- Player update method
function Player:update(dt, world, shootCallback)
    -- Call parent Ship update first
    Ship.update(self, dt, self, shootCallback)
    
    -- Lock-on targeting removed - combat works differently now
end

-- Lock-on targeting system update
-- Lock-on targeting system removed - combat works differently now

-- Lock-on targeting system removed - combat works differently now

-- Missile launcher check removed - combat works differently now

function Player:dock(station)
    self.docked = true
    if self.components and self.components.physics and self.components.physics.body then
        self.components.physics.body.vx, self.components.physics.body.vy = 0, 0
    end
    self.moveTarget = nil
    -- Fully restore shields on docking
    if self.components and self.components.health then
        local h = self.components.health
        h.shield = h.maxShield or h.shield
    end
    -- Show docked UI
    local DockedUI = require("src.ui.docked")
    DockedUI.show(self, station)

    local Hotbar = require("src.systems.hotbar")
    Hotbar.state.active.turret_slots = {}
end

function Player:undock()
    self.docked = false
    -- Hide docked UI
    local DockedUI = require("src.ui.docked")
    DockedUI.hide()

    local Hotbar = require("src.systems.hotbar")
    Hotbar.state.active.turret_slots = {}
end

function Player:resetDurability()
    if self.shield_durability then
        ShieldDurability.reset(self.shield_durability)
    end
end

function Player:setMoveTarget(x, y)
    if self.docked then return end
    self.moveTarget = {x = x, y = y}
end

function Player:addXP(x)
  self.xp = self.xp + x
  if self.xp >= self.level * 100 then
    self.xp = 0
    self.level = self.level + 1
    self.components.health.maxHP = self.components.health.maxHP + 10
    self.components.health.maxShield = self.components.health.maxShield + 10
    self.components.health.shield = self.components.health.maxShield
  end
end

function Player:setTarget(target, targetType)
  if target == self.target then return end
  self.target = target
  self.targetType = targetType or "enemy"
  self.locked = false
  self.lockProgress = 0
  if target then
    if self.targetType == "asteroid" then
      self.lockTime = 0.3
    else
      local sig = target.sig or (target.components and target.components.collidable and target.components.collidable.signature) or 80
      
      -- Use ship's targeting module lock speed
      local shipTargeting = (self.components and self.components.targeting) or {}
      local baseLockTime = shipTargeting.lockTime or shipTargeting.baseSpeed or 2.0

      -- Simplified lock time calculation
      self.lockTime = baseLockTime
      self.lockTime = math.max(0.5, self.lockTime) -- Minimum 0.5s lock time
    end
    if self.targetType == "enemy" and target.onTargeted then
      target:onTargeted()
    end
  else
    self.lockTime = 0
  end
end

function Player:getThrusterState()
    if self.components and self.components.physics and self.components.physics.body then
        return self.components.physics.body.thrusters
    end
    return nil
end

function Player:getTurretInSlot(slotNum)
    if not self.components or not self.components.equipment or not self.components.equipment.grid then
        return nil
    end
    local gridData = self.components.equipment.grid[slotNum]
    if gridData and gridData.type == "turret" then
        return gridData.module
    end
    return nil
end

local Hotbar = require("src.systems.hotbar")

function Player:equipTurret(slotNum, turretId)
    -- Initialize inventory if it doesn't exist
    if not self.inventory then
        self.inventory = {}
    end
    self.inventory_slots = self.inventory_slots or {}

    if not self.inventory[turretId] or self.inventory[turretId] <= 0 then
        return false -- Don't have this turret in inventory
    end

    if not self.components or not self.components.equipment or not self.components.equipment.turrets then
        return false
    end

    -- Find the turret slot
    for i, turretData in ipairs(self.components.equipment.turrets) do
        if turretData.slot == slotNum then
            -- Remove old turret if present
            if turretData.turret then
                -- Return old turret to inventory if it exists
                local oldId = turretData.id
                if oldId then
                    self.inventory[oldId] = (self.inventory[oldId] or 0) + 1
                end
            end

            -- Check if this is a procedural turret (stored in inventory as full turret data)
            local turretDef
            if type(self.inventory[turretId]) == "table" and self.inventory[turretId].damage then
                -- This is a procedural turret with full data
                turretDef = self.inventory[turretId]
            else
                -- This is a regular turret, get definition from content
                turretDef = Content.getTurret(turretId)
            end

            if turretDef then
                local newTurret = Turret.new(self, turretDef)
                newTurret.id = turretId
                newTurret.slot = slotNum
                self.components.equipment.turrets[i] = {
                    id = turretId,
                    turret = newTurret,
                    enabled = true,
                    slot = slotNum
                }
                -- Remove from inventory (procedural turrets are stored as objects, regular turrets as counts)
                if type(self.inventory[turretId]) == "table" then
                    -- Procedural turret - remove the object
                    self.inventory[turretId] = nil
                else
                    -- Regular turret - decrement count
                    self.inventory[turretId] = self.inventory[turretId] - 1
                    if self.inventory[turretId] <= 0 then
                        self.inventory[turretId] = nil
                    end
                end
                -- Clear any slot pointing to this id
                for i = 1, #self.inventory_slots do
                    if self.inventory_slots[i] == turretId then
                        self.inventory_slots[i] = nil
                    end
                end

                Hotbar.populateFromPlayer(self)
                Hotbar.save()
                Hotbar.state.active = Hotbar.state.active or {}
                Hotbar.state.active.turret_slots = {}
                return true
            end
        end
    end
    return false
end

function Player:unequipTurret(slotNum)
    if not self.components or not self.components.equipment or not self.components.equipment.turrets then
        return false
    end

    -- Initialize inventory and slots if they don't exist
    if not self.inventory then
        self.inventory = {}
    end
    if not self.inventory_slots then
        self.inventory_slots = {}
    end

    -- Find the turret slot
    for i, turretData in ipairs(self.components.equipment.turrets) do
        if turretData.slot == slotNum and turretData.turret then
            -- Return turret to inventory
            local turretId = turretData.id
            if turretId then
                -- Always store the full turret data when unequipping (to preserve any procedural modifiers)
                self.inventory[turretId] = turretData.turret
                -- Place into a free slot if not already mapped
                local alreadyMapped = false
                for i = 1, #self.inventory_slots do
                    if self.inventory_slots[i] == turretId then
                        alreadyMapped = true
                        break
                    end
                end
                if not alreadyMapped then
                    for i = 1, 24 do
                        if self.inventory_slots[i] == nil then
                            self.inventory_slots[i] = turretId
                            break
                        end
                    end
                end
            end

            -- Remove turret from slot
            self.components.equipment.turrets[i] = {
                id = nil,
                turret = nil,
                enabled = false,
                slot = slotNum
            }

            Hotbar.populateFromPlayer(self)
            Hotbar.save()
            Hotbar.state.active = Hotbar.state.active or {}
            Hotbar.state.active.turret_slots = {}
            return true
        end
    end
    return false
end

-- Unified equipment grid methods
function Player:equipModule(slotNum, moduleId, turretData)
    if not self.components or not self.components.equipment or not self.components.equipment.grid then
        return false
    end

    -- Check if player has the item in inventory
    if not self.inventory or not self.inventory[moduleId] then
        return false -- Don't have this item in inventory
    end
    
    -- Check if it's a valid quantity (number > 0) or a turret object
    local inventoryValue = self.inventory[moduleId]
    local hasItem = false
    if type(inventoryValue) == "number" and inventoryValue > 0 then
        hasItem = true
    elseif type(inventoryValue) == "table" and inventoryValue.damage then
        -- This is a turret object
        hasItem = true
    end
    
    if not hasItem then
        return false -- Don't have this item in inventory
    end

    -- Get the module definition (could be any module type)
    local moduleDef = Content.getItem(moduleId)
    local turretDef = Content.getTurret(moduleId)

    -- Determine module type
    local moduleType = nil
    local actualModule = nil
    
    if moduleDef and moduleDef.module then
        -- It's a module (shield, engine, etc.)
        moduleType = moduleDef.module.type or "module"
        actualModule = moduleDef
    elseif turretDef then
        -- It's a base turret from content (non-procedural)
        moduleType = "turret"
        actualModule = Turret.new(self, Util.copy(turretDef))
        -- Use base id for non-procedural turrets
        actualModule.id = moduleId
        actualModule.baseId = moduleId
        actualModule.slot = slotNum
    elseif turretData then
        -- It's a procedural turret being dragged from inventory
        moduleType = "turret"
        local baseId = turretData.baseId or turretData.id
        actualModule = Turret.new(self, Util.copy(turretData))
        -- Preserve unique instance id for inventory bookkeeping
        actualModule.id = moduleId
        actualModule.baseId = baseId
        actualModule.slot = slotNum
    elseif type(inventoryValue) == "table" and inventoryValue.damage then
        -- It's a procedural turret stored as full data in inventory
        moduleType = "turret"
        local baseId = inventoryValue.baseId or inventoryValue.id
        actualModule = Turret.new(self, Util.copy(inventoryValue))
        -- Preserve unique instance id for inventory bookkeeping
        actualModule.id = moduleId
        actualModule.baseId = baseId
        actualModule.slot = slotNum
    else
        return false
    end

    -- Find the grid slot
    for i, gridData in ipairs(self.components.equipment.grid) do
        if gridData.slot == slotNum then
            -- Remove existing module if any
            if gridData.module then
                self:unequipModule(slotNum)
            end

            -- Equip the new module
            self.components.equipment.grid[i] = {
                id = moduleId,
                module = actualModule,
                enabled = true,
                slot = slotNum,
                type = moduleType
            }

            -- Remove from inventory
            if type(inventoryValue) == "number" then
                -- Numeric quantity - decrement
                self.inventory[moduleId] = self.inventory[moduleId] - 1
                if self.inventory[moduleId] <= 0 then
                    self.inventory[moduleId] = nil
                end
            elseif type(inventoryValue) == "table" then
                -- Turret object - remove entirely
                self.inventory[moduleId] = nil
            end

            -- Clear any inventory slot mapping for this id
            if self.inventory_slots then
                for i = 1, #self.inventory_slots do
                    if self.inventory_slots[i] == moduleId then
                        self.inventory_slots[i] = nil
                    end
                end
            end

            -- Update systems based on module type
            if moduleType == "shield" then
                self:updateShieldHP()
            elseif moduleType == "turret" then
                self:updateHotbar()
            end
            return true
        end
    end
    return false
end

function Player:unequipModule(slotNum)
    if not self.components or not self.components.equipment or not self.components.equipment.grid then
        return false
    end

    -- Initialize inventory if it doesn't exist
    if not self.inventory then
        self.inventory = {}
    end
    if not self.inventory_slots then
        self.inventory_slots = {}
    end

    -- Find the grid slot
    for i, gridData in ipairs(self.components.equipment.grid) do
        if gridData.slot == slotNum and gridData.module then
            local moduleId = gridData.id
            local moduleType = gridData.type

            -- Return module to inventory
            if moduleId then
                if moduleType == "shield" or moduleType == "module" then
                    -- For shield modules and other modules, increment count
                    self.inventory[moduleId] = (self.inventory[moduleId] or 0) + 1
                    -- Map to a free slot if not already present
                    local mapped = false
                    for i = 1, #self.inventory_slots do
                        if self.inventory_slots[i] == moduleId then
                            mapped = true
                            break
                        end
                    end
                    if not mapped then
                        for i = 1, 24 do
                            if self.inventory_slots[i] == nil then
                                self.inventory_slots[i] = moduleId
                                break
                            end
                        end
                    end
                else
                    -- For turrets, store the full turret data preserving unique id
                    local turretObj = gridData.module
                    if turretObj then
                        -- Ensure we retain the unique id key in inventory
                        local uniqueId = gridData.id or (turretObj and turretObj.id)
                        if uniqueId then
                            self.inventory[uniqueId] = turretObj
                            -- Map unique id to a free slot if not already present
                            local mapped = false
                            for i = 1, #self.inventory_slots do
                                if self.inventory_slots[i] == uniqueId then
                                    mapped = true
                                    break
                                end
                            end
                            if not mapped then
                                for i = 1, 24 do
                                    if self.inventory_slots[i] == nil then
                                        self.inventory_slots[i] = uniqueId
                                        break
                                    end
                                end
                            end
                        else
                            -- Fallback to base id if no unique id present
                            self.inventory[moduleId] = turretObj
                            local mapped = false
                            for i = 1, #self.inventory_slots do
                                if self.inventory_slots[i] == moduleId then
                                    mapped = true
                                    break
                                end
                            end
                            if not mapped then
                                for i = 1, 24 do
                                    if self.inventory_slots[i] == nil then
                                        self.inventory_slots[i] = moduleId
                                        break
                                    end
                                end
                            end
                        end
                    end
                end
            end

            -- Remove module from slot
            self.components.equipment.grid[i] = {
                id = nil,
                module = nil,
                enabled = false,
                slot = slotNum,
                type = nil
            }

            -- Update systems based on module type
            if moduleType == "shield" then
                self:updateShieldHP()
            elseif moduleType == "turret" then
                self:updateHotbar()
            end
            return true
        end
    end
    return false
end

function Player:updateShieldHP()
    if not self.components or not self.components.equipment or not self.components.equipment.grid then
        return
    end

    local totalShieldHP = 0
    for _, gridData in ipairs(self.components.equipment.grid) do
        if gridData.type == "shield" and gridData.module and gridData.module.module and gridData.module.module.shield_hp then
            totalShieldHP = totalShieldHP + gridData.module.module.shield_hp
        end
    end

    -- Update the health component
    if self.components.health then
        self.components.health.maxShield = totalShieldHP
        -- Ensure current shield doesn't exceed max
        if self.components.health.shield > totalShieldHP then
            self.components.health.shield = totalShieldHP
        end
    end
end

function Player:getShieldRegen()
    if not self.components or not self.components.equipment or not self.components.equipment.grid then
        return 0
    end

    local totalShieldRegen = 0
    for _, gridData in ipairs(self.components.equipment.grid) do
        if gridData.type == "shield" and gridData.module and gridData.module.module and gridData.module.module.shield_regen then
            totalShieldRegen = totalShieldRegen + gridData.module.module.shield_regen
        end
    end

    return totalShieldRegen
end

function Player:updateHotbar()
    -- Update hotbar with turrets from grid
    local Hotbar = require("src.systems.hotbar")
    if Hotbar.populateFromPlayer then
        Hotbar.populateFromPlayer(self)
    end
end

-- The large update function has been moved to PlayerSystem.
-- The player entity is now primarily a data container.

-- GC management functions
function Player:getGC()
  return self.gc or 0
end

function Player:setGC(amount)
  self.gc = math.max(0, amount)
end

function Player:addGC(amount)
  self:setGC(self:getGC() + amount)
end

function Player:spendGC(amount)
  local current = self:getGC()
  if current >= amount then
    self:setGC(current - amount)
    return true
  end
  return false
end

return Player
