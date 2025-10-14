local Util = require("src.core.util")
local Content = require("src.content.content")
local Log = require("src.core.log")
local Position = require("src.components.position")
local Collidable = require("src.components.collidable")
local Velocity = require("src.components.velocity")
local Hull = require("src.components.hull")
local Shield = require("src.components.shield")
local Energy = require("src.components.energy")
local Equipment = require("src.components.equipment")
local Renderable = require("src.components.renderable")
local WindfieldPhysics = require("src.components.windfield_physics")
-- PhysicsComponent removed - using windfield_physics instead
local Collidable = require("src.components.collidable")
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
  local visualWidth = ModelUtil.calculateModelWidth(shipConfig.visuals)
  local radius = visualWidth and visualWidth > 0 and (visualWidth / 2) or nil
  if not radius or radius <= 0 then
    radius = (shipConfig.collidable and shipConfig.collidable.radius) or 20
  end

  -- Engine configuration (moved to windfield_physics component)
  -- Engine properties are now handled by the windfield_physics component

  -- Ship properties from config
  self.name = shipConfig.name or "Unknown Ship"
  self.class = shipConfig.class or "Ship"
  self.description = shipConfig.description or ""
  -- Keep reference to config fragments for UI (engine/misc)
  self.engine = shipConfig.engine or { mass = 1000, accel = 500 }

  -- Hull stats (standardize via components.hull)
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
        radius = radius,
        shape = (shipConfig.collidable and shipConfig.collidable.shape) or shipConfig.collisionShape or "circle",
        vertices = (shipConfig.collidable and shipConfig.collidable.vertices) or shipConfig.collisionVertices,
        friendly = friendly,
        signature = self.sig,
      }),
      velocity = Velocity.new({ x = 0, y = 0 }),
      windfield_physics = WindfieldPhysics.new({
        mass = mass,
        radius = radius,
        x = x,
        y = y,
        colliderType = "circle",
        bodyType = "dynamic",
        restitution = 0.1,
        friction = 0.3,
        fixedRotation = shipConfig.fixedRotation == false and false or true,
      }),
      hull = Hull.new({ maxHP = maxHP, hp = hp }),
      shield = Shield.new({ maxShield = maxShield, shield = shield }),
      energy = Energy.new({ maxEnergy = maxEnergy, energy = energy }),
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

  -- Update weapons from the grid system
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
      -- Thruster reset handled by windfield_physics component
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
    
    -- Turning towards target (handled by windfield_physics component)
    if math.abs(angleDiff) > 0.1 then
      -- Turning is handled by the windfield_physics component
      -- The AI system will set thruster states appropriately
    end
    
    -- Only move forward when reasonably aligned with target direction
    -- This prevents the ship from moving in the wrong direction while turning
    local alignmentThreshold = math.pi / 4  -- 45 degrees
    if math.abs(angleDiff) < alignmentThreshold then
      -- Movement is handled by the windfield_physics component
      -- The AI system will set thruster states appropriately
    end
  else
    -- Thruster reset handled by windfield_physics component
  end
end

-- Damage handling
function Ship:hit(damage)
  local hull = self.components and self.components.hull
  local shield = self.components and self.components.shield
  if not hull then return damage end
  
  local shieldAbsorbed = 0
  if shield then
    shieldAbsorbed = math.min(shield.shield or 0, damage or 0)
    shield.shield = math.max(0, (shield.shield or 0) - shieldAbsorbed)
  end
  
  local remainingDamage = (damage or 0) - shieldAbsorbed
  if remainingDamage > 0 then
    hull.hp = math.max(0, (hull.hp or 0) - remainingDamage)
    if (hull.hp or 0) <= 0 then self.dead = true end
  end
  return damage
end

function Ship:isAlive()
  local hull = self.components and self.components.hull
  return not self.dead and hull and (hull.hp or 0) > 0
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
