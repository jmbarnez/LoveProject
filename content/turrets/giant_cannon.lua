return {
  id = "giant_cannon",
  type = "gun",
  name = "Giant Cannon",
  description = "Fires a massive singular projectile with devastating damage.",
  price = 2000,
  icon = {
    size = 32,
    shapes = {
      -- Giant gun barrel
      { type = "rectangle", mode = "fill", color = {0.7, 0.7, 0.7, 1}, x = 6, y = 10, w = 20, h = 12, rx = 2 },
      -- Gun housing
      { type = "rectangle", mode = "fill", color = {0.5, 0.5, 0.5, 1}, x = 2, y = 6, w = 28, h = 20, rx = 3 },
      -- Muzzle
      { type = "rectangle", mode = "fill", color = {0.9, 0.8, 0.6, 1}, x = 24, y = 12, w = 6, h = 8, rx = 1 },
      -- Details
      { type = "rectangle", mode = "fill", color = {0.3, 0.3, 0.3, 1}, x = 4, y = 8, w = 4, h = 3, rx = 0.5 },
      { type = "rectangle", mode = "fill", color = {0.3, 0.3, 0.3, 1}, x = 24, y = 8, w = 4, h = 3, rx = 0.5 },
    }
  },
  spread = { minDeg = 0.1, maxDeg = 1.0, decay = 600 },
  projectile = "giant_bullet",
  tracer = { color = {0.8, 0.4, 0.2, 1.0}, width = 2, coreRadius = 3 },
  impact = {
    shield = { spanDeg = 90, color1 = {0.8, 0.4, 0.2, 0.6}, color2 = {1.0, 0.6, 0.3, 0.4} },
    hull = { spark = {1.0, 0.5, 0.1, 0.7}, ring = {1.0, 0.3, 0.0, 0.5} },
  },
  optimal = 1000, falloff = 800,
  damage_range = { min = 8, max = 12 },
  cycle = 5.0, capCost = 5,
  projectileSpeed = 3000,
  maxRange = 2500,
  -- Overheating parameters
  maxHeat = 150,
  heatPerShot = 20,
  cooldownRate = 20,
  overheatDuration = 3.0,
  heatCycleMult = 0.8,
  heatEnergyMult = 1.5,

  -- Firing mode: "manual" or "automatic"
  fireMode = "manual"
}