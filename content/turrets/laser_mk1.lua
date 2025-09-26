return {
  id = "laser_mk1",
  type = "laser",
  name = "Tech 1 Laser",
  description = "Advanced energy turret with excellent precision and tracking, high energy cost.",
  price = 1500,
  icon = {
    size = 32,
    shapes = {
      -- Laser emitter housing
      { type = "rectangle", mode = "fill", color = {0.3, 0.8, 1.0, 1}, x = 4, y = 8, w = 24, h = 16, rx = 2 },
      -- Lens
      { type = "circle", mode = "fill", color = {0.5, 0.9, 1.0, 1}, x = 16, y = 16, r = 3 },
      -- Beam
      { type = "rectangle", mode = "fill", color = {0.7, 1.0, 1.0, 0.8}, x = 15, y = 4, w = 2, h = 12 },
      -- Energy arcs
      { type = "arc", mode = "line", color = {0.4, 0.9, 1.0, 0.6}, x = 16, y = 16, r = 5, angle1 = -0.3, angle2 = 0.3, segments = 8 },
      { type = "arc", mode = "line", color = {0.4, 0.9, 1.0, 0.6}, x = 16, y = 16, r = 7, angle1 = -0.2, angle2 = 0.2, segments = 6 },
    }
  },
  -- Visuals: blue combat beam, crisp shield arcs
  projectile = "laser_beam", -- Specify the projectile to be fired
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
  overheatDuration = 2.0, -- Shorter disable time
  heatCycleMult = 0.8, -- Less slowdown when hot
  heatEnergyMult = 1.2, -- Reduced energy cost increase when hot

  -- Firing mode: "manual" or "automatic"
  fireMode = "automatic" -- Lasers are good for sustained fire
}
