return {
  id = "giant_cannon",
  type = "gun",
  name = "Giant Cannon",
  description = "Fires a massive singular projectile with devastating damage.",
  price = 2000,
  module = { type = "turret" },
  icon = {
    size = 32,
    shapes = {
      -- Massive armored cradle
      { type = "polygon", mode = "fill", color = {0.08, 0.11, 0.16, 1}, points = {4, 24, 7, 10, 25, 10, 28, 24, 16, 30} },
      { type = "polygon", mode = "fill", color = {0.18, 0.22, 0.30, 1}, points = {6, 20, 10, 12, 22, 12, 26, 20, 16, 26} },
      -- Reinforced rails
      { type = "rectangle", mode = "fill", color = {0.14, 0.28, 0.42, 1}, x = 9, y = 14, w = 14, h = 4, rx = 1.2 },
      { type = "rectangle", mode = "fill", color = {0.14, 0.28, 0.42, 1}, x = 11, y = 19, w = 10, h = 3, rx = 1.2 },
      -- Cannon spine
      { type = "rectangle", mode = "fill", color = {0.30, 0.40, 0.50, 1}, x = 13, y = 6, w = 6, h = 16, rx = 2 },
      { type = "rectangle", mode = "fill", color = {0.60, 0.70, 0.80, 1}, x = 14, y = 4, w = 4, h = 18, rx = 2 },
      -- Muzzle coil and bloom
      { type = "circle", mode = "fill", color = {0.95, 0.60, 0.25, 0.95}, x = 16, y = 4, r = 3.2 },
      { type = "circle", mode = "line", color = {1.00, 0.80, 0.40, 0.8}, x = 16, y = 4, r = 4.2, lineWidth = 1.5 },
      -- Side capacitors
      { type = "circle", mode = "fill", color = {0.00, 0.70, 0.95, 0.75}, x = 10, y = 18, r = 1.4 },
      { type = "circle", mode = "fill", color = {0.00, 0.70, 0.95, 0.75}, x = 22, y = 18, r = 1.4 },
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
  overheatCooldown = 5.0,
  heatCycleMult = 0.8,
  heatEnergyMult = 1.5,

  -- Firing mode: "manual" or "automatic"
  fireMode = "manual"
}
