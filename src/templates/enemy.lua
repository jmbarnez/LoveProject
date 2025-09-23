local Util = require("src.core.util")
local Turret = require("src.systems.turret.core")
local Content = require("src.content.content")
local PhysicsComponent = require("src.components.physics")
local Position = require("src.components.position")
local Renderable = require("src.components.renderable")
local Collidable = require("src.components.collidable")
local Health = require("src.components.health")
local AI = require("src.components.ai")
local EngineTrail = require("src.components.engine_trail")
local PhysicsComponent = require("src.components.physics")

local Enemy = {}
Enemy.__index = Enemy

function Enemy.new(x, y, options)
  local self = setmetatable({}, Enemy)
  options = options or {}
  
  -- Initialize physics component (lighter mass for nimbleness)
  local physics = PhysicsComponent.new({ mass = 150, x = x, y = y })
  physics.body.radius = 10
  self.sig = 80
  
  -- Basic enemy properties
  self.aggro = false
  
  -- Hardcoded enemy type
  self.name = "Scout Drone"
  -- No legacy hp fields; use components.health
  self.bounty = 8
  self.xpReward = 10
  -- No legacy shield fields; use components.health
  
  -- Shared turret system: basic drones use laser for testing
  local turretId = "laser_mk1"
  local tDef = (Content.getTurret and Content.getTurret(turretId))
  if tDef then
    tDef = Util.copy(tDef)
    tDef.capCost = 0 -- Drones don't use energy
    tDef.cycle = 3.0 -- Slower firing rate for enemies
    tDef.fireMode = "automatic" -- Enemy turrets should fire automatically
  end
  self.turret = Turret.new(self, tDef or {
    type = "laser",
    optimal = 380, falloff = 260,
    cycle = 4.5, capCost = 0,
    fireMode = "automatic"  -- Enemy turrets should fire automatically
  })
  self.dead = false
  -- Simple loot table (placeholder items)
  self.lootTable = {
    { id = "ore_tritanium", min = 1, max = 3, chance = 0.7 },
    { id = "ore_palladium", min = 1, max = 2, chance = 0.35 },
  }
  
  -- Visual definition for Scout Drone
  self.visuals = {
    size = 0.8,
    shapes = {
      { type = "circle", mode = "fill", color = {0.42, 0.45, 0.50, 1.0}, x = 0, y = 0, r = 10 },
      { type = "circle", mode = "line", color = {0.20, 0.22, 0.26, 0.9}, x = 0, y = 0, r = 10 },
      { type = "circle", mode = "fill", color = {1.0, 0.35, 0.25, 0.9}, x = 3, y = 0, r = 3.2 },
      { type = "rect", mode = "fill", color = {0.32, 0.35, 0.39, 1.0}, x = -6, y = -12, w = 18, h = 4, rx = 1 },
      { type = "rect", mode = "fill", color = {0.32, 0.35, 0.39, 1.0}, x = -6, y = 8,  w = 18, h = 4, rx = 1 },
      { type = "rect", mode = "fill", color = {0.28, 0.30, 0.34, 1.0}, x = 8, y = -1, w = 8, h = 2, rx = 1 },
      { type = "circle", mode = "fill", color = {1.0, 0.25, 0.2, 0.8}, x = -6, y = -10, r = 1.5 },
      { type = "circle", mode = "fill", color = {1.0, 0.25, 0.2, 0.8}, x = -6, y = 10,  r = 1.5 },
    }
  }
  
  -- Create equipment grid for turrets
  local equipmentGrid = {}

  -- Add turret to equipment grid slot 1
  table.insert(equipmentGrid, {
    id = "laser_mk1",
    module = self.turret,
    enabled = true,
    slot = 1,
    type = "turret"
  })

  -- ECS components (for systems and standardized access)
  self.components = {
    position   = Position.new({ x = x, y = y, angle = 0 }),
    collidable = Collidable.new({ radius = physics.body.radius }),
    health     = Health.new({ hp = 5, maxHP = 5, shield = 3, maxShield = 3 }),
    physics    = physics,
    renderable = Renderable.new("enemy", { visuals = self.visuals }),
    ai         = AI.new({
      spawnPos = {x = x, y = y},  -- Set spawn position for patrolling
      patrolCenter = {x = x, y = y}  -- Patrol around spawn location
    }),
    equipment  = { grid = equipmentGrid },
    engine_trail = EngineTrail.new({
        size = 0.6,  -- Smaller size for minimal effect
        offset = 10,  -- Slightly smaller offset
        color1 = {1.0, 0.2, 0.1, 0.8},  -- Red primary, slightly more subtle
        color2 = {1.0, 0.2, 0.1, 0.4}   -- Red secondary, more subtle
    }),  -- Red thrusters for AI
  }


  return self
end

function Enemy:hit(dmg)
  local h = self.components and self.components.health
  if h then
    local s = math.min((h.shield or 0), dmg or 0)
    h.shield = math.max(0, (h.shield or 0) - s)
    local rem = (dmg or 0) - s
    if rem > 0 then
      h.hp = math.max(0, (h.hp or 0) - rem)
      if (h.hp or 0) <= 0 then self.dead = true end
    end
  end
  -- Taking damage triggers aggro and marks as attacked for neutral AIs
  if not self.aggro then self.aggro = true end
  self.wasAttacked = true
  if self.components.ai then
    self.components.ai.wasAttacked = true
  end
end


function Enemy:update(dt, player, shoot)
    -- Update physics and sync position
    if self.components.physics and self.components.physics.update then
      self.components.physics:update(dt)
    end
    local b = self.components.physics.body
    local pos = self.components.position
    pos.x, pos.y, pos.angle = b.x, b.y, b.angle

    -- AI system now handles all movement and firing logic
    -- This template only handles basic physics updates
end


-- Rendering handled by central RenderSystem using components.renderable

return Enemy
