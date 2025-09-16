local Util = require("src.core.util")
local Turret = require("src.systems.turret.core")
local Content = require("src.content.content")
local Config = require("src.content.config")
local EntityFactory = require("src.templates.entity_factory")
local Log = require("src.core.log")

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

  -- Player-specific defaults
  self.moveTarget = nil
  self.level = 1
  self.xp = 0
  self.gc = 10000
  self.docked = false
  self.weaponsDisabled = false
  self.wasInHub = false
  self.canDock = false

  -- Lock-on targeting system
  self.lockOnState = {
    target = nil,           -- Currently targeted enemy
    lockProgress = 0,       -- Lock-on progress (0-1)
    lockDuration = 2.5,     -- Time needed to acquire lock (seconds)
    isLocked = false,       -- Whether target is fully locked
    maxRange = 2500,        -- Maximum lock-on range
    lockCone = math.rad(15), -- Lock-on cone angle (15 degrees)
    lastUpdateTime = 0      -- For tracking time
  }

  self.active_quests = {}
  self.quest_progress = {}
  -- Override the renderable type to use the specific 'player' renderer
  if self.components and self.components.renderable then
      self.components.renderable.type = "player"
  end

  -- Turrets are provided by the ship template via components.equipment.turrets.
  -- No additional default turrets are added here.

  -- Default inventory will be initialized by game setup (see Game.load).

  return self
end

-- Player update method
function Player:update(dt, world, shootCallback)
    -- Call parent Ship update first
    Ship.update(self, dt, self, shootCallback)
    
    -- Update lock-on targeting
    self:updateLockOn(dt, world)
end

-- Lock-on targeting system update
function Player:updateLockOn(dt, world)
  if not world or self.docked then return end
  
  local lockState = self.lockOnState
  local playerPos = self.components.position
  local playerAngle = playerPos.angle or 0
  
  -- Find potential targets in lock-on cone
  local potentialTarget = nil
  local bestDistance = math.huge
  
  local enemies = world:get_entities_with_components("ai", "position")
  for _, enemy in ipairs(enemies) do
    if not enemy.dead and enemy.components.position then
      local ex, ey = enemy.components.position.x, enemy.components.position.y
      local dx, dy = ex - playerPos.x, ey - playerPos.y
      local distance = math.sqrt(dx * dx + dy * dy)
      
      -- Check if within range
      if distance <= lockState.maxRange then
        -- Check if within lock-on cone
        local angleToTarget = math.atan2(dy, dx)
        local angleDiff = math.abs(((angleToTarget - playerAngle + math.pi) % (2 * math.pi)) - math.pi)
        
        if angleDiff <= lockState.lockCone then
          -- Find closest target in cone
          if distance < bestDistance then
            bestDistance = distance
            potentialTarget = enemy
          end
        end
      end
    end
  end
  
  -- Update lock-on state
  if potentialTarget and potentialTarget == lockState.target then
    -- Continue locking onto same target
    lockState.lockProgress = math.min(1.0, lockState.lockProgress + dt / lockState.lockDuration)
    if lockState.lockProgress >= 1.0 then
      lockState.isLocked = true
    end
  elseif potentialTarget then
    -- New target found, start locking
    lockState.target = potentialTarget
    lockState.lockProgress = dt / lockState.lockDuration
    lockState.isLocked = false
  else
    -- No target in cone, lose lock
    lockState.target = nil
    lockState.lockProgress = 0
    lockState.isLocked = false
  end
  
  -- Validate locked target still exists and is in range
  if lockState.target and (lockState.target.dead or not lockState.target.components.position) then
    lockState.target = nil
    lockState.lockProgress = 0
    lockState.isLocked = false
  elseif lockState.target and lockState.target.components.position then
    local tx, ty = lockState.target.components.position.x, lockState.target.components.position.y
    local dx, dy = tx - playerPos.x, ty - playerPos.y
    local distance = math.sqrt(dx * dx + dy * dy)
    if distance > lockState.maxRange * 1.2 then -- Allow some margin before losing lock
      lockState.target = nil
      lockState.lockProgress = 0
      lockState.isLocked = false
    end
  end
end

-- Get the currently locked target (if any)
function Player:getLockedTarget()
  local lockState = self.lockOnState
  if lockState.isLocked and lockState.target and not lockState.target.dead then
    return lockState.target
  end
  return nil
end

-- Check if player has a missile launcher equipped
function Player:hasMissileLauncher()
  if not self.components.equipment or not self.components.equipment.turrets then
    return false
  end
  
  for _, tslot in ipairs(self.components.equipment.turrets) do
    local turret = tslot and tslot.turret
    if turret and (turret.kind == "missile" or turret.type == "missile") then
      return true
    end
  end
  return false
end

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
end

function Player:undock()
    self.docked = false
    -- Hide docked UI
    local DockedUI = require("src.ui.docked")
    DockedUI.hide()
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
      local sigRes = shipTargeting.sigRes or shipTargeting.resolution or 100
      
      -- Calculate final lock time based on target signature vs ship's sensor resolution
      local sigRatio = sigRes / math.max(20, sig)
      self.lockTime = baseLockTime * (1.0 - (sigRatio - 1.0) * 0.2) -- Better sensors = faster lock
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
    if not self.components or not self.components.equipment or not self.components.equipment.turrets then
        return nil
    end
    for _, turretData in ipairs(self.components.equipment.turrets) do
        if turretData.slot == slotNum then
            return turretData.turret
        end
    end
    return nil
end

function Player:equipTurret(slotNum, turretId)
    -- Initialize inventory if it doesn't exist
    if not self.inventory then
        self.inventory = {}
    end

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

            -- Equip new turret
            local turretDef = Content.getTurret(turretId)
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
                -- Remove from inventory
                self.inventory[turretId] = self.inventory[turretId] - 1
                if self.inventory[turretId] <= 0 then
                    self.inventory[turretId] = nil  -- Remove completely when count reaches 0
                end
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

    -- Initialize inventory if it doesn't exist
    if not self.inventory then
        self.inventory = {}
    end

    -- Find the turret slot
    for i, turretData in ipairs(self.components.equipment.turrets) do
        if turretData.slot == slotNum and turretData.turret then
            -- Return turret to inventory
            local turretId = turretData.id
            if turretId then
                self.inventory[turretId] = (self.inventory[turretId] or 0) + 1
            end

            -- Remove turret from slot
            self.components.equipment.turrets[i] = {
                id = nil,
                turret = nil,
                enabled = false,
                slot = slotNum
            }
            return true
        end
    end
    return false
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
