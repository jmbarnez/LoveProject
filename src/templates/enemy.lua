local Enemy = {}
Enemy.__index = Enemy

function Enemy.new(x, y, options)
    local self = setmetatable({}, Enemy)
    options = options or {}

    local physics = PhysicsComponent.new({ mass = 150, x = x, y = y })
    physics.body.radius = 10
    self.sig = 80
    self.aggro = false
    self.name = "Scout Drone"
    self.bounty = 8
    self.xpReward = 10
    self.dead = false

    self.lootTable = {
        { id = "ore_tritanium", min = 1, max = 3, chance = 0.7 },
        { id = "ore_palladium", min = 1, max = 2, chance = 0.35 },
    }

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

    self.components = {
        position   = Position.new({ x = x, y = y, angle = 0 }),
        collidable = Collidable.new({ radius = physics.body.radius }),
        health     = Health.new({ hp = 5, maxHP = 5, shield = 3, maxShield = 3 }),
        physics    = physics,
        renderable = Renderable.new("enemy", { visuals = self.visuals }),
        ai         = AI.new({
            spawnPos = {x = x, y = y},
            patrolCenter = {x = x, y = y}
        }),
        equipment  = { grid = {} },
        engine_trail = EngineTrail.new({
            size = 0.6,
            offset = 10,
            color1 = {1.0, 0.2, 0.1, 0.8},
            color2 = {1.0, 0.2, 0.1, 0.4}
        }),
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
