return {
  id = "lightning_turret",
  type = "laser",
  name = "Lightning Turret",
  description = "A turret that shoots lightning.",
  price = 1000,
  module = { type = "turret" },
  icon = {
    size = 32,
    shapes = {
      -- Suspended coil cradle
      { type = "polygon", mode = "fill", color = {0.08, 0.10, 0.18, 1}, points = {6, 22, 10, 12, 22, 12, 26, 22, 16, 28} },
      { type = "polygon", mode = "fill", color = {0.16, 0.20, 0.28, 1}, points = {8, 20, 12, 14, 20, 14, 24, 20, 16, 24} },
      -- Electromagnetic containment rings
      { type = "circle", mode = "line", color = {0.35, 0.80, 1.00, 0.7}, x = 16, y = 16, r = 6, lineWidth = 2 },
      { type = "circle", mode = "line", color = {0.20, 0.65, 1.00, 0.45}, x = 16, y = 16, r = 8, lineWidth = 1.5 },
      -- Charged capacitor core
      { type = "circle", mode = "fill", color = {0.05, 0.18, 0.30, 1}, x = 16, y = 16, r = 4 },
      { type = "circle", mode = "fill", color = {0.45, 0.90, 1.00, 1}, x = 16, y = 16, r = 2.6 },
      -- Lightning discharge
      { type = "polygon", mode = "fill", color = {0.70, 0.95, 1.00, 1}, points = {14, 4, 19, 6, 16, 10, 21, 12, 12, 22, 15, 14, 11, 12} },
      -- Spark accents
      { type = "circle", mode = "fill", color = {0.55, 0.95, 1.00, 0.8}, x = 11, y = 18, r = 1.2 },
      { type = "circle", mode = "fill", color = {0.55, 0.95, 1.00, 0.8}, x = 21, y = 18, r = 1.2 },
    }
  },
  tracer = { color = {0.5, 0.8, 1.0, 1.0}, width = 2.0, coreRadius = 1 },
  chainChance = 0.5,
  chainRange = 300,
  maxChains = 3,
  spread = { minDeg = 0, maxDeg = 0, decay = 0 },
  projectile = "laser_beam",
  optimal = 1000, falloff = 200,
  damage_range = { min = 5, max = 10 },
  cycle = 1.0, capCost = 10,
  projectileSpeed = 5000,
  maxRange = 1200,
  maxHeat = 100,
  heatPerShot = 20,
  cooldownRate = 25,
  overheatDuration = 3,
  heatCycleMult = 1.0,
  heatEnergyMult = 1.0,
  fireMode = "manual"
}
