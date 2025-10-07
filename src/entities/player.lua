local Util = require("src.core.util")
local Turret = require("src.systems.turret.core")
local Content = require("src.content.content")
local Config = require("src.content.config")
local EntityFactory = require("src.templates.entity_factory")
local Log = require("src.core.log")
local PlayerStateComponent = require("src.components.player_state")
local DockingStatusComponent = require("src.components.docking_status")
local PlayerHotbar = require("src.systems.player.hotbar")

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
  self.shipId = shipId or "starter_frigate_basic"
  self.isPlayer = true -- Ensure this flag is set.
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
    -- Set drag coefficient for space drag (uses constant from physics system)
    local CorePhysics = require("src.core.physics")
    self.components.physics.body.dragCoefficient = CorePhysics.constants.SPACE_DRAG_COEFFICIENT
  end

  -- Player-specific defaults now live in dedicated components
  self.components.player_state = self.components.player_state or PlayerStateComponent.new({
    move_target = nil,
    weapons_disabled = false,
    was_in_hub = false,
  })
  self.components.docking_status = self.components.docking_status or DockingStatusComponent.new()

  -- Ensure progression component exists
  if not self.components.progression then
      local ProgressionComponent = require("src.components.progression")
      self.components.progression = ProgressionComponent.new()
  end
  if not self.components.questLog then
      local QuestLogComponent = require("src.components.quest_log")
      self.components.questLog = QuestLogComponent.new()
  end


  if self.components and self.components.renderable then
      self.components.renderable.type = "player"
  end

  -- Turrets are provided by the ship template via components.equipment.turrets.
  -- No additional default turrets are added here.

  -- Default inventory will be initialized by game setup (see Game.load).

  self:resetDurability()

  -- Start with no modules equipped
  if self.components and self.components.equipment and self.components.equipment.grid then
      for i = 1, #self.components.equipment.grid do
          local slot = self.components.equipment.grid[i]
          slot.id = nil
          slot.module = nil
          slot.enabled = false
          slot.hotbarSlot = nil
          slot.type = slot.baseType or slot.type or nil
      end
  end

  local equipment = self.components and self.components.equipment
  if equipment and equipment.grid then
      local function equipStartingModule(slotNum, moduleId)
          local cargo = self.components and self.components.cargo
          local seeded = false
          if cargo and not cargo:has(moduleId, 1) then
              self:addItem(moduleId, 1)
              seeded = true
          end
          local equipped = self:equipModule(slotNum, moduleId)
          if not equipped and seeded and cargo then
              cargo:remove(moduleId, 1)
          end
          return equipped
      end

      -- Equip starting combat turrets
      if not equipStartingModule(1, "kinetic_turret") and self.components and self.components.cargo then
          self:addItem("kinetic_turret", 1)
      end

      if not equipStartingModule(2, "low_power_laser") and self.components and self.components.cargo then
          self:addItem("low_power_laser", 1)
      end

      if not equipStartingModule(3, "missile_launcher_mk1") and self.components and self.components.cargo then
          self:addItem("missile_launcher_mk1", 1)
      end

      if not equipStartingModule(4, "shield_module_basic") and self.components and self.components.cargo then
          self:addItem("shield_module_basic", 1)
      end

      -- Add utility turrets to cargo hold (combat turrets are already equipped)
      if self.components and self.components.cargo then
          self:addItem("mining_laser", 1)
          self:addItem("salvaging_laser", 1)
      end
  end

  -- Initialize shield HP based on equipped modules (after modules are equipped)
  self:updateShieldHP()

  PlayerHotbar.populate(self)

  return self
end

function Player:resetDurability()
    if self.shield_durability then
        ShieldDurability.reset(self.shield_durability)
    end
end

function Player:addXP(amount)
  if self.components and self.components.progression then
    local leveledUp = self.components.progression:addXP(amount)
    return leveledUp
  end
  return false
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

function Player:equipTurret(slotNum, turretId)
    if not self.components or not self.components.equipment or not self.components.equipment.turrets then
        return false
    end

    -- Find the turret slot
    for i, turretData in ipairs(self.components.equipment.turrets) do
            if turretData.slot == slotNum then
                -- Remove old turret if present
                if turretData.turret then
                    local oldId = turretData.id
                    if oldId then
                        self:addItem(oldId, 1)
                    end
                end

            local cargo = self.components.cargo
            local turretMeta = cargo and cargo:extract(turretId) or nil
            local turretDef
            if type(turretMeta) == "table" then
                turretDef = turretMeta
            else
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
                PlayerHotbar.populate(self)
                PlayerHotbar.clearAssignments()
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
    if not self.components.cargo then
        return false
    end
    -- Find the turret slot
    for i, turretData in ipairs(self.components.equipment.turrets) do
        if turretData.slot == slotNum and turretData.turret then
            -- Return turret to inventory
            local turretId = turretData.id
            if turretId then
                -- Return turret back to cargo (procedural turrets serialize via meta)
                if turretData.turret and turretData.turret._sourceData then
                    self:addItem(turretId, 1, turretData.turret._sourceData)
                else
                    self:addItem(turretId, 1)
                end
            end

            -- Remove turret from slot
            self.components.equipment.turrets[i] = {
                id = nil,
                turret = nil,
                enabled = false,
                slot = slotNum
            }

            PlayerHotbar.populate(self)
            PlayerHotbar.clearAssignments()
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

    -- Check if player has the item in inventory, or if it's a turret available from content
    local hasItem = false
    local inventoryValue = nil

    local cargo = self.components and self.components.cargo
    if cargo and cargo:has(moduleId, 1) then
        hasItem = true
    end

    -- Allow equipping turrets directly from content system if not in inventory
    local turretDef = Content.getTurret(moduleId)
    if not hasItem and turretDef and turretDef.module and turretDef.module.type == "turret" then
        hasItem = true
    end

    if not hasItem then
        return false -- Don't have this item in inventory or content
    end

    -- Get the module definition (could be any module type)
    local moduleDef = Content.getItem(moduleId)
    local turretDef = Content.getTurret(moduleId)

    -- Determine module type
    local moduleType = nil
    local actualModule = nil

    local function instantiateTurret(def, instanceId, baseId)
        if not def then return nil end
        local turretBlueprint = Util.deepCopy(def)
        local turretInstance = Turret.new(self, turretBlueprint)
        turretInstance.id = instanceId
        turretInstance.baseId = baseId or turretBlueprint.baseId or turretBlueprint.id or instanceId
        turretInstance.slot = slotNum
        turretInstance._sourceData = turretBlueprint
        return turretInstance
    end

    if moduleDef and moduleDef.module then
        local declaredType = moduleDef.module.type or "module"
        if declaredType == "turret" then
            moduleType = "turret"
            local sourceDef = turretDef or moduleDef.def or moduleDef
            actualModule = instantiateTurret(sourceDef, moduleId, moduleId)
            if not actualModule then
                return false
            end
        else
            moduleType = declaredType
            actualModule = moduleDef
        end
    elseif turretDef then
        moduleType = "turret"
        actualModule = instantiateTurret(turretDef, moduleId, moduleId)
        if not actualModule then
            return false
        end
    elseif turretData then
        moduleType = "turret"
        local baseId = turretData.baseId or turretData.id
        actualModule = instantiateTurret(turretData, moduleId, baseId)
        if not actualModule then
            return false
        end
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

            local baseType = gridData.baseType
            if baseType and moduleType ~= baseType then
                return false
            end

            if gridData.module then
                self:unequipModule(slotNum)
                gridData = self.components.equipment.grid[i]
                baseType = gridData.baseType
            end

            gridData.id = moduleId
            gridData.module = actualModule
            gridData.enabled = true
            gridData.slot = slotNum
            gridData.type = moduleType
            gridData.baseType = baseType

            -- Remove from inventory only if it was actually in inventory
            if cargo then
                cargo:remove(moduleId, 1)
            end

            -- Update systems based on module type
            if moduleType == "shield" then
                self:updateShieldHP()
            elseif moduleType == "turret" then
                PlayerHotbar.populate(self, moduleId, slotNum)
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
    local cargo = self.components and self.components.cargo
    if not cargo then
        return false
    end

    -- Find the grid slot
    for i, gridData in ipairs(self.components.equipment.grid) do
        if gridData.slot == slotNum and gridData.module then
            local moduleId = gridData.id
            local moduleType = gridData.type

            -- Return module to inventory (stackable modules handled directly; turrets handled below)
            if moduleId and (moduleType == "shield" or moduleType == "module") then
                cargo:add(moduleId, 1)
            elseif moduleType == "turret" then
                local turretObj = gridData.module
                if turretObj then
                    local baseId = turretObj.baseId or moduleId
                    if turretObj._sourceData then
                        cargo:add(moduleId, 1, turretObj._sourceData)
                    else
                        cargo:add(moduleId, 1, Content.getTurret(baseId))
                    end
                end
            end

            local slotRef = self.components.equipment.grid[i]
            slotRef.id = nil
            slotRef.module = nil
            slotRef.enabled = false
            slotRef.type = slotRef.baseType or nil
            slotRef.hotbarSlot = nil

            -- Update systems based on module type
            if moduleType == "shield" then
                self:updateShieldHP()
            elseif moduleType == "turret" then
                PlayerHotbar.populate(self, nil, slotNum)
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
        local oldMaxShield = self.components.health.maxShield
        local oldShield = self.components.health.shield
        self.components.health.maxShield = totalShieldHP
        -- Initialize current shield to max if it's 0 (new player) or ensure it doesn't exceed max
        if self.components.health.shield == 0 and totalShieldHP > 0 then
            self.components.health.shield = totalShieldHP
        elseif self.components.health.shield > totalShieldHP then
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

-- The large update function has been moved to PlayerSystem.
-- The player entity is now primarily a data container.

-- GC management functions
function Player:getGC()
  if self.components and self.components.progression then
    return self.components.progression.gc
  end
  return 0
end

function Player:setGC(amount)
  if self.components and self.components.progression then
    self.components.progression.gc = math.max(0, amount)
  end
end

function Player:addGC(amount)
  if self.components and self.components.progression then
    return self.components.progression:addGC(amount)
  end
  return 0
end

function Player:spendGC(amount)
  if self.components and self.components.progression then
    return self.components.progression:spendGC(amount)
  end
  return false
end

function Player:addQuest(quest)
  if self.components and self.components.questLog then
    self.components.questLog:add(quest)
  end
end

function Player:removeQuest(id)
  if self.components and self.components.questLog then
    self.components.questLog:remove(id)
  end
end

function Player:addItem(itemId, qty, meta)
    if self.components and self.components.cargo then
        local result = self.components.cargo:add(itemId, qty, meta)
        return result
    end
    return false
end

function Player:removeItem(itemId, qty)
    if self.components and self.components.cargo then
        local result = self.components.cargo:remove(itemId, qty)
        return result
    end
    return false
end

function Player:getItemCount(itemId)
    if self.components and self.components.cargo then
        return self.components.cargo:getQuantity(itemId)
    end
    return 0
end

function Player:iterCargo(cb)
    if self.components and self.components.cargo then
        self.components.cargo:iterate(cb)
    end
end

return Player
