local Util = require("src.core.util")
local Turret = require("src.systems.turret.core")
local Content = require("src.content.content")
local Log = require("src.core.log")
local Renderable = require("src.components.renderable")
local PhysicsComponent = require("src.components.physics")
local ModelUtil = require("src.core.model_util")

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

  -- Create the component table
  local Position = require("src.components.position")
  local EngineTrail = require("src.components.engine_trail")
  
  -- Configure engine trail colors based on ship visuals
  local engineColors = {
    color1 = (self.visuals.engineColor and {self.visuals.engineColor[1], self.visuals.engineColor[2], self.visuals.engineColor[3], 1}) or {1, 1, 1, 1},
    color2 = (self.visuals.engineColor and {self.visuals.engineColor[1] * 0.5, self.visuals.engineColor[2] * 0.5, self.visuals.engineColor[3], 0.5}) or {0.5, 0.5, 1, 0.5},
    size = self.visuals.size or 1.0,
    offset = ModelUtil.calculateModelWidth(shipConfig.visuals) * 0.4  -- Position emitter behind ship proportional to ship size
  }
  
  self.components = {
      position = Position.new({ x = x, y = y, angle = 0 }),
      collidable = {
        radius = physics.body.radius,
        shape = shipConfig.collisionShape or "circle",
        vertices = shipConfig.collisionVertices
      },
      physics = physics,
      velocity = { x = 0, y = 0 },
      health = { maxHP = maxHP, maxShield = maxShield, maxEnergy = maxEnergy, hp = hp, shield = shield, energy = energy },
      equipment = {
          grid = {}
      },
      renderable = Renderable.new(
          "enemy", -- Use the 'enemy' renderer by default
          { visuals = self.visuals }
      )
  }

  -- Attach engine trail for all ships with consistent colors
  -- Engine trail colors remain the same regardless of entity type
  self.components.engine_trail = EngineTrail.new(engineColors)

  -- Attach loot drop definition if provided by content
  if shipConfig.loot and shipConfig.loot.drops then
    self.components.lootable = { drops = shipConfig.loot.drops }
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
    end

    -- Create proper AI component with intelligence levels
    self.components.ai = AIComponent.new(aiConfig)
    
    -- Add velocity component for movement
    self.components.velocity = { x = 0, y = 0 }
  end
  
  -- Add player component if this is a player
  if extraConfig.isPlayer then
    self.components.player = {}
  end

  -- Equipment grid setup - 3x3 grid for all ships
  local gridSize = 9  -- 3x3 grid
  for i = 1, gridSize do
    table.insert(self.components.equipment.grid, { 
      id = nil, 
      module = nil, 
      enabled = false, 
      slot = i,
      type = nil  -- Will be set when module is equipped
    })
  end

  -- Legacy turret setup for backward compatibility (will be migrated to grid)
  if shipConfig.hardpoints then
    for i, hardpoint in ipairs(shipConfig.hardpoints) do
      if hardpoint.turret and i <= gridSize then
        local turretId = hardpoint.turret
        local tDef = Content.getTurret and Content.getTurret(turretId)
        if tDef then
          local turret = Turret.new(self, Util.copy(tDef))
          turret.id = turretId
          turret.slot = i

          -- Enemy ships should have automatic firing turrets
          if extraConfig.isEnemy then
            turret.fireMode = "automatic"
          end

          self.components.equipment.grid[i] = {
            id = turretId,
            module = turret,
            enabled = true,
            slot = i,
            type = "turret"
          }
        end
      end
    end
  end

  -- Combat properties
  self.aggro = false
  self.target = nil
  self.moveTarget = nil
  self.dead = false
  self.bounty = extraConfig.bounty or 0
  self.xpReward = extraConfig.xpReward or 0
  
  -- Apply extra config properties (like shipId, isEnemy flags, etc.)
  for key, value in pairs(extraConfig) do
    self[key] = value
  end

  return self
end

-- Ship update function
function Ship:update(dt, player, shootCallback)
  if self.updateMovement then
    self:updateMovement(dt)
  end

  -- Update turrets from the grid system
  if self.components.equipment and self.components.equipment.grid then
    for _, gridData in ipairs(self.components.equipment.grid) do
      if gridData.type == "turret" and gridData.module and gridData.enabled then
        gridData.module:update(dt, self.target, true, shootCallback)
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

return Ship
