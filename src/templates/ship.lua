local Util = require("src.core.util")
local Content = require("src.content.content")
local Log = require("src.core.log")
local Position = require("src.components.position")
local Collidable = require("src.components.collidable")
local Velocity = require("src.components.velocity")
local Health = require("src.components.health")
local Equipment = require("src.components.equipment")
local Renderable = require("src.components.renderable")
local PhysicsComponent = require("src.components.physics")
local Collidable = require("src.components.collidable")
local Health = require("src.components.health")
local Equipment = require("src.components.equipment")
local Velocity = require("src.components.velocity")
local Lootable = require("src.components.lootable")
local PlayerComponent = require("src.components.player")
local Position = require("src.components.position")
local EngineTrail = require("src.components.engine_trail")
local ModelUtil = require("src.core.model_util")
local CargoComponent = require("src.components.cargo")
local ProgressionComponent = require("src.components.progression")
local QuestLogComponent = require("src.components.quest_log")

local Ship = {}
Ship.__index = Ship

-- *** This is the crucial fix ***
-- The function signature now matches the call from the EntityFactory.
-- The 'angle' and 'friendly' arguments are unused here but are necessary
-- to ensure 'shipConfig' receives the correct table argument.
function Ship.new(x, y, angle, friendly, shipConfig)
  local self = setmetatable({}, Ship)
  
  -- Store extra config properties (like isEnemy from EntityFactory)
  local extraConfig = {}
  
  -- Load ship configuration if an ID string is passed
  if type(shipConfig) == "string" then
    shipConfig = Content.getShip and Content.getShip(shipConfig)
    if not shipConfig then
      Log.warn("Ship not found by id; using defaults")
      shipConfig = {}
    end
  else
    -- Separate standard ship properties from extra properties (like isEnemy)
    local standardKeys = {
      id = true, name = true, class = true, description = true, visuals = true,
      hull = true, engine = true, hardpoints = true, sig = true, cargo = true,
      ai = true, loot = true
    }
    for key, value in pairs(shipConfig) do
      if not standardKeys[key] then
        extraConfig[key] = value
      end
    end
  end

  -- Physics setup (moved into components)
  local mass = (shipConfig.engine and shipConfig.engine.mass) or 500
  local physics = PhysicsComponent.new({ mass = mass, x = x, y = y })
  -- Radius lives on the underlying body
  physics.body.radius = ModelUtil.calculateModelWidth(shipConfig.visuals) / 2

  -- Engine configuration
  if shipConfig.engine then
    local baseThrust = mass * 50
    local accelMultiplier = (shipConfig.engine.accel or 500) / 500
    physics.body.thrusterPower = {
      main = baseThrust * accelMultiplier * 1.2,
      lateral = baseThrust * accelMultiplier * 0.4,
      rotational = baseThrust * accelMultiplier * 0.3
    }
    -- Apply ship-specific engine characteristics to physics body
    physics.body.maxSpeed = shipConfig.engine.maxSpeed or 300
    -- No drag in space - realistic physics
    physics.body.dragCoefficient = 1.0
  else
    physics.body.thrusterPower = { main = 50000, lateral = 20000, rotational = 15000 }
    physics.body.maxSpeed = 300
    -- No drag in space - realistic physics
    physics.body.dragCoefficient = 1.0
  end

  -- Ship properties from config
  self.name = shipConfig.name or "Unknown Ship"
  self.class = shipConfig.class or "Ship"
  self.description = shipConfig.description or ""
  -- Keep reference to config fragments for UI (engine/misc)
  self.engine = shipConfig.engine or { mass = 1000, accel = 500 }

  -- Hull stats (standardize via components.health)
  local maxHP, maxShield, maxEnergy
  if shipConfig.hull then
    maxHP = shipConfig.hull.hp or 100
    maxShield = shipConfig.hull.shield or 50
    maxEnergy = shipConfig.hull.cap or 100
  else
    maxHP, maxShield, maxEnergy = 100, 50, 100
  end
  local hp, shield, energy = maxHP, maxShield, maxEnergy

  -- Other properties
  self.sig = shipConfig.sig or 100
  self.cargoCapacity = (shipConfig.cargo and shipConfig.cargo.capacity) or 100
  self.sig = shipConfig.sig or self.sig

  -- Visuals
  self.visuals = shipConfig.visuals or {
    size = 1.0,
    hullColor = {0.5, 0.5, 0.5, 1.0},
    shapes = {}
  }
  -- Set engine trail color based on ship type
  if extraConfig.isEnemy then
    self.visuals.engineColor = {1.0, 0.0, 0.0}  -- Red for enemies
  end

  -- Configure engine trail colors based on ship visuals - more subtle
  local equipment = Equipment.new()
  local engineColors = {
    color1 = (self.visuals.engineColor and {self.visuals.engineColor[1], self.visuals.engineColor[2], self.visuals.engineColor[3], 0.8}) or {0.0, 0.0, 1.0, 0.8},
    color2 = (self.visuals.engineColor and {self.visuals.engineColor[1] * 0.5, self.visuals.engineColor[2] * 0.5, self.visuals.engineColor[3], 0.4}) or {0.0, 0.0, 0.5, 0.4},
    size = (self.visuals.size or 1.0) * 0.8,  -- Smaller size for minimal effect
    offset = ModelUtil.calculateModelWidth(shipConfig.visuals) * 0.3  -- Slightly smaller offset
  }

  self.components = {
      position = Position.new({ x = x, y = y, angle = angle or 0 }),
      collidable = Collidable.new({
        radius = physics.body.radius,
        shape = (shipConfig.collidable and shipConfig.collidable.shape) or shipConfig.collisionShape or "circle",
        vertices = (shipConfig.collidable and shipConfig.collidable.vertices) or shipConfig.collisionVertices,
        friendly = friendly,
        signature = self.sig,
      }),
      physics = physics,
      velocity = Velocity.new({ x = 0, y = 0 }),
      health = Health.new({ maxHP = maxHP, maxShield = maxShield, maxEnergy = maxEnergy, hp = hp, shield = shield, energy = energy }),
      equipment = equipment,
      renderable = Renderable.new(
          "enemy", -- Use the 'enemy' renderer by default
          { visuals = self.visuals }
      ),
      cargo = CargoComponent.new({
        capacity = (shipConfig.cargo and shipConfig.cargo.capacity) or 100,
        volumeLimit = (shipConfig.cargo and shipConfig.cargo.volumeLimit) or math.huge
      }),
      progression = ProgressionComponent.new(),
      questLog = QuestLogComponent.new(),
  }

  -- Attach engine trail for all ships with consistent colors
  -- Engine trail colors remain the same regardless of entity type
  self.components.engine_trail = EngineTrail.new(engineColors)

  -- Attach loot drop definition if provided by content
  if shipConfig.loot and shipConfig.loot.drops then
    self.components.lootable = Lootable.new({ drops = shipConfig.loot.drops })
  end

  -- Add AI component if this is an enemy
  if extraConfig.isEnemy then
    local AIComponent = require("src.components.ai")
    
    -- Use AI configuration from ship data if available
    local aiConfig = {}
    if shipConfig.ai then
      aiConfig.intelligenceLevel = shipConfig.ai.intelligenceLevel
      aiConfig.aggressiveType = shipConfig.ai.aggressiveType
      aiConfig.wanderSpeed = shipConfig.ai.wanderSpeed
      aiConfig.detectionRange = shipConfig.ai.detectionRange
    end

    -- Set spawn position and patrol center for AI
    aiConfig.spawnPos = { x = x, y = y }
    aiConfig.patrolCenter = { x = x, y = y }

    -- Create proper AI component with intelligence levels
    self.components.ai = AIComponent.new(aiConfig)
    
  end

  -- Add player component if this is a player
  if extraConfig.isPlayer then
    self.components.player = PlayerComponent.new({ id = shipConfig.id, faction = shipConfig.faction, isPlayer = true })
  end

  -- Equipment grid setup
  local gridSize = shipConfig.equipmentSlots or 9
  local layoutBySlot = {}
  if type(shipConfig.equipmentLayout) == "table" then
    for _, slotDef in ipairs(shipConfig.equipmentLayout) do
      local idx = tonumber(slotDef.slot or slotDef.index)
      if idx then
        layoutBySlot[idx] = slotDef
      end
    end
  end

  for i = 1, gridSize do
    local slotDef = layoutBySlot[i]
    local baseType = slotDef and slotDef.type or nil
    equipment:addSlot({
      id = nil,
      module = nil,
      enabled = false,
      slot = i,
      type = baseType,
      baseType = baseType,
      label = slotDef and slotDef.label or nil,
      icon = slotDef and slotDef.icon or nil,
      meta = slotDef and slotDef.meta or nil
    })
  end

  if type(shipConfig.equipmentLayout) == "table" then
    self.components.equipment.layout = shipConfig.equipmentLayout
  end

  -- Will be re-added once the basic fitting system is working

  -- Legacy turret setup for backward compatibility (will be migrated to grid)
  if shipConfig.hardpoints then
  end

  -- Combat properties
  self.aggro = false
  self.target = nil
  self.moveTarget = nil
  self.dead = false
  self.xpReward = extraConfig.xpReward or 0
  
  -- Apply extra config properties (like shipId, isEnemy flags, etc.)
  for key, value in pairs(extraConfig) do
    self[key] = value
  end

  return self
end

-- Ship update function
function Ship:update(dt, player, shootCallback, world)
  if self.weaponsDisabled then return end
  if self.updateMovement then
    self:updateMovement(dt)
  end

  -- Update turrets from the grid system
  if self.components.equipment and self.components.equipment.grid then
    for _, gridData in ipairs(self.components.equipment.grid) do
      if gridData.type == "turret" and gridData.module and gridData.enabled and gridData.module.update and type(gridData.module.update) == "function" then
        gridData.module:update(dt, self.target, true, world)
      end
    end
  end
end

-- Simple movement
function Ship:updateMovement(dt)
  if self.moveTarget then
    local dx, dy = self.moveTarget.x - self.components.position.x, self.moveTarget.y - self.components.position.y
    local dist = math.sqrt(dx*dx + dy*dy)
    if dist < 25 then
      self.moveTarget = nil
      if self.components.physics and self.components.physics.body then
        self.components.physics.body:resetThrusters()
      end
      return
    end
    local targetAngle = math.atan(dy/dx)
    if dx < 0 then
        targetAngle = targetAngle + math.pi
    elseif dy < 0 then
        targetAngle = targetAngle + 2 * math.pi
    end
    local angleDiff = targetAngle - self.components.position.angle
    while angleDiff > math.pi do angleDiff = angleDiff - 2 * math.pi end
    while angleDiff < -math.pi do angleDiff = angleDiff + 2 * math.pi end
    
    -- Physics-based turning towards target
    if math.abs(angleDiff) > 0.1 then
      local body = self.components.physics and self.components.physics.body
      if body then
        -- Use physics-based turning instead of direct thruster activation
        local desiredAngularVel = angleDiff * 6.0  -- Slightly less aggressive than player
        local currentAngularVel = body.angularVel
        local angularVelDiff = desiredAngularVel - currentAngularVel
        
        local torqueStrength = body.thrusterPower.rotational
        local appliedTorque = angularVelDiff * torqueStrength * 0.08  -- AI ships turn a bit slower
        
        -- Limit maximum torque
        local maxTorque = torqueStrength * 0.8  -- AI ships have slightly less agile turning
        appliedTorque = math.max(-maxTorque, math.min(maxTorque, appliedTorque))
        
        body:applyTorque(appliedTorque, dt)
      end
    end
    
    -- Only move forward when reasonably aligned with target direction
    -- This prevents the ship from moving in the wrong direction while turning
    local alignmentThreshold = math.pi / 4  -- 45 degrees
    if math.abs(angleDiff) < alignmentThreshold then
      local currentSpeed = (self.components.physics and self.components.physics.body and self.components.physics.body:getSpeed()) or 0
      local targetSpeed = self.moveTarget.maxSpeed or self.maxSpeed
      if currentSpeed < targetSpeed * 0.8 then
        if self.components.physics then self.components.physics:setThruster("forward", true) end
      elseif currentSpeed > targetSpeed * 1.1 then
        if self.components.physics then self.components.physics:setThruster("backward", true) end
      end
    end
  else
    if self.components.physics and self.components.physics.body then
      self.components.physics.body:resetThrusters()
    end
  end
end

-- Damage handling
function Ship:hit(damage)
  local h = self.components and self.components.health
  if not h then return damage end
  local shieldAbsorbed = math.min(h.shield or 0, damage or 0)
  h.shield = math.max(0, (h.shield or 0) - shieldAbsorbed)
  local remainingDamage = (damage or 0) - shieldAbsorbed
  if remainingDamage > 0 then
    h.hp = math.max(0, (h.hp or 0) - remainingDamage)
    if (h.hp or 0) <= 0 then self.dead = true end
  end
  return damage
end

function Ship:isAlive()
  local h = self.components and self.components.health
  return not self.dead and h and (h.hp or 0) > 0
end

function Ship:getTurretInSlot(slotNum)
    if not self.components or not self.components.equipment or not self.components.equipment.grid then
        return nil
    end
    local gridData = self.components.equipment.grid[slotNum]
    if gridData and gridData.type == "turret" then
        return gridData.module
    end
    return nil
end

return Ship
