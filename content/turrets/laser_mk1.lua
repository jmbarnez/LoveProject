return {
  id = "laser_mk1",
  type = "laser",
  name = "Tech 1 Laser",
  description = "Advanced energy turret with excellent precision and tracking, high energy cost.",
  price = 1500,
  module = { type = "turret" },
  icon = {
    size = 32,
    shapes = {
      -- Angular emitter frame
      { type = "polygon", mode = "fill", color = {0.08, 0.12, 0.18, 1}, points = {6, 22, 9, 10, 23, 10, 26, 22, 16, 28} },
      { type = "polygon", mode = "fill", color = {0.16, 0.22, 0.30, 1}, points = {8, 18, 11, 12, 21, 12, 24, 18, 16, 24} },
      -- Energy conduits
      { type = "rectangle", mode = "fill", color = {0.05, 0.35, 0.55, 1}, x = 9, y = 14, w = 14, h = 3, rx = 1 },
      { type = "rectangle", mode = "fill", color = {0.05, 0.35, 0.55, 1}, x = 11, y = 18, w = 10, h = 2, rx = 1 },
      -- Focused lens cluster
      { type = "circle", mode = "fill", color = {0.05, 0.22, 0.32, 1}, x = 16, y = 8, r = 5 },
      { type = "circle", mode = "fill", color = {0.15, 0.70, 0.95, 1}, x = 16, y = 8, r = 3.2 },
      { type = "circle", mode = "fill", color = {0.70, 1.00, 1.00, 0.9}, x = 16, y = 8, r = 1.8 },
      -- Projection spike
      { type = "polygon", mode = "fill", color = {0.55, 0.95, 1.00, 0.9}, points = {14, 2, 18, 2, 20, 8, 12, 8} },
      -- Containment rings
      { type = "arc", mode = "line", color = {0.15, 0.75, 1.00, 0.6}, x = 16, y = 8, r = 7, angle1 = -0.7, angle2 = 0.7, segments = 14, lineWidth = 1.5 },
      { type = "arc", mode = "line", color = {0.25, 0.85, 1.00, 0.45}, x = 16, y = 8, r = 9, angle1 = -0.5, angle2 = 0.5, segments = 12, lineWidth = 1 },
    }
  },
  -- Embedded projectile definition
  projectile = {
    id = "laser_beam",
    name = "Laser Beam",
    class = "Projectile",
    physics = {
      speed = 0, -- Beams should not advance position; collision handles ray
      drag = 0,
    },
    renderable = {
      type = "bullet",
      props = {
        kind = "laser",
        length = 1500, -- Maximum beam length
        tracerWidth = 4,
        angle = 0, -- Will be set when fired
        color = {0.30, 0.85, 1.00, 0.9}
      }
    },
    collidable = {
      radius = 2, -- small collision radius so the beam is included in collision queries
    },
    damage = 15,
    timed_life = {
      duration = 0.15, -- 0.1s buildup + 0.05s flash
    },
    charged_pulse = {
      buildup_time = 0.1,  -- Energy charging phase
      flash_time = 0.05,   -- Intense beam flash
    }
  },
  
  -- Visual effects
  tracer = { color = {0.0, 0.0, 1.0, 0.8}, width = 1.5, coreRadius = 1 },
  impact = {
    shield = { spanDeg = 80, color1 = {0.35, 0.85, 1.0, 0.65}, color2 = {0.65, 0.95, 1.0, 0.45} },
    hull = { spark = {0.85, 0.95, 1.0, 0.5}, ring = {0.55, 0.75, 1.0, 0.4} },
  },
  -- Superior at long range with excellent precision
  optimal = 1200, falloff = 600,
  damage_range = { min = 1, max = 2 },
  cycle = 2.0, capCost = 5,  -- 2 second cycle time
  spread = { minDeg = 0.1, maxDeg = 0.3, decay = 800 }, -- Very precise
  maxRange = 1500, -- Hard cap: full accuracy up to this distance
  -- Overheating parameters (reduced to allow more frequent firing)
  maxHeat = 100, -- Increased heat capacity
  heatPerShot = 10, -- Reduced heat per shot
  cooldownRate = 30, -- Faster heat dissipation
  overheatCooldown = 5.0, -- Fixed cooldown window after overheating
  heatCycleMult = 0.8, -- Less slowdown when hot
  heatEnergyMult = 1.2, -- Reduced energy cost increase when hot

  -- Firing mode: "manual" or "automatic"
  fireMode = "automatic" -- Lasers are good for sustained fire
}
