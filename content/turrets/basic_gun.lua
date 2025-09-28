return {
  id = "basic_gun",
  type = "gun",
  name = "Basic Gun",
  description = "Standard projectile turret with moderate range and damage.",
  price = 500,
  module = { type = "turret" },
  icon = {
    size = 32,
    shapes = {
      -- Faceted chassis panels
      { type = "polygon", mode = "fill", color = {0.10, 0.14, 0.20, 1}, points = {4, 12, 8, 6, 24, 6, 28, 12, 24, 20, 8, 20} },
      { type = "polygon", mode = "fill", color = {0.22, 0.30, 0.38, 1}, points = {6, 13, 10, 9, 22, 9, 26, 13, 22, 19, 10, 19} },
      -- Magnetic rail shrouds
      { type = "rectangle", mode = "fill", color = {0.00, 0.65, 0.95, 0.85}, x = 9, y = 12, w = 14, h = 3, rx = 1 },
      { type = "rectangle", mode = "fill", color = {0.00, 0.65, 0.95, 0.7}, x = 9, y = 18, w = 14, h = 2, rx = 1 },
      -- Barrel core and muzzle bloom
      { type = "rectangle", mode = "fill", color = {0.55, 0.80, 1.00, 1}, x = 14, y = 6, w = 4, h = 13, rx = 1 },
      { type = "circle", mode = "fill", color = {0.95, 0.98, 1.00, 0.9}, x = 16, y = 6, r = 3 },
      -- Targeting lights
      { type = "circle", mode = "fill", color = {0.00, 0.85, 1.00, 0.85}, x = 11, y = 15, r = 1.2 },
      { type = "circle", mode = "fill", color = {0.00, 0.85, 1.00, 0.85}, x = 21, y = 15, r = 1.2 },
    }
  },
  spread = { minDeg = 0.15, maxDeg = 1.2, decay = 600 }, -- Much tighter spread for excellent accuracy
  
  -- Reference to embedded projectile
  projectileId = "gun_bullet",
  
  -- Embedded projectile definition
  projectile = {
    id = "gun_bullet",
    name = "Kinetic Slug",
    class = "Projectile",
    physics = {
      speed = 4800,
      drag = 0, -- No drag for simple bullets
    },
    renderable = {
      type = "bullet",
      props = {
        kind = "bullet",
        radius = 2,
        color = {0.35, 0.70, 1.00, 1.0},
      }
    },
    damage = {
      value = 1.5, -- Average of damage_range min/max
    },
    timed_life = {
      duration = 2.5,
    }
  },
  
  -- Visual effects
  tracer = { color = {0.35, 0.70, 1.00, 1.0}, width = 1, coreRadius = 2 },
  impact = {
    shield = { spanDeg = 70, color1 = {0.26, 0.62, 1.0, 0.55}, color2 = {0.50, 0.80, 1.0, 0.35} },
    hull = { spark = {1.0, 0.6, 0.1, 0.6}, ring = {1.0, 0.3, 0.0, 0.4} },
  },
  -- Balanced medium range with moderate damage falloff
  optimal = 800, falloff = 600,
  damage_range = { min = 1, max = 2 },
  cycle = 0.6, capCost = 2,
  maxRange = 2000, -- Bullets disappear after traveling 2000 units
  -- Overheating parameters
  maxHeat = 100, -- Heat capacity
  heatPerShot = 10, -- Heat generated per shot
  cooldownRate = 15, -- Heat dissipated per second
  overheatCooldown = 5.0, -- Seconds required to recover from overheating
  heatCycleMult = 0.7, -- Slower firing when hot (cycle * 0.7 at max heat)
  heatEnergyMult = 1.3, -- More energy cost when hot

  -- Firing mode: "manual" or "automatic"
  fireMode = "manual"
}
