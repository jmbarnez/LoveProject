return {
  id = "basic_gun",
  type = "gun",
  name = "Basic Gun",
  description = "Standard projectile turret with moderate range and damage.",
  price = 500,
  icon = {
    size = 32,
    shapes = {
      -- Gun barrel
      { type = "rectangle", mode = "fill", color = {0.7, 0.7, 0.7, 1}, x = 8, y = 12, w = 16, h = 8, rx = 1 },
      -- Gun housing
      { type = "rectangle", mode = "fill", color = {0.5, 0.5, 0.5, 1}, x = 4, y = 8, w = 24, h = 16, rx = 2 },
      -- Muzzle
      { type = "rectangle", mode = "fill", color = {0.9, 0.8, 0.6, 1}, x = 24, y = 14, w = 4, h = 4, rx = 0.5 },
      -- Details
      { type = "rectangle", mode = "fill", color = {0.3, 0.3, 0.3, 1}, x = 6, y = 10, w = 3, h = 2, rx = 0.5 },
      { type = "rectangle", mode = "fill", color = {0.3, 0.3, 0.3, 1}, x = 23, y = 10, w = 3, h = 2, rx = 0.5 },
    }
  },
  spread = { minDeg = 0.15, maxDeg = 1.2, decay = 600 }, -- Much tighter spread for excellent accuracy
  projectile = "gun_bullet", -- Specify the projectile to be fired
  tracer = { color = {0.35, 0.70, 1.00, 1.0}, width = 1, coreRadius = 2 },
  impact = {
    shield = { spanDeg = 70, color1 = {0.26, 0.62, 1.0, 0.55}, color2 = {0.50, 0.80, 1.0, 0.35} },
    hull = { spark = {1.0, 0.6, 0.1, 0.6}, ring = {1.0, 0.3, 0.0, 0.4} },
  },
  -- Balanced medium range with moderate damage falloff
  optimal = 800, falloff = 600, tracking = 1.2, sigRes = 150,
  damage_range = { min = 1, max = 2 },
  cycle = 0.6, capCost = 2, turnRate = 3.2,
  projectileSpeed = 4800, -- Even faster projectiles (4x original baseline)
  maxRange = 2000, -- Bullets disappear after traveling 2000 units
  -- Overheating parameters
  maxHeat = 100, -- Heat capacity
  heatPerShot = 10, -- Heat generated per shot
  cooldownRate = 15, -- Heat dissipated per second
  overheatDuration = 2.5, -- Seconds disabled when overheated
  heatCycleMult = 0.7, -- Slower firing when hot (cycle * 0.7 at max heat)
  heatEnergyMult = 1.3 -- More energy cost when hot
}
