return {
  id = "lightning_turret",
  type = "gun",
  name = "Lightning Turret",
  description = "A turret that shoots lightning.",
  price = 1000,
  icon = {
    size = 32,
    shapes = {
      { type = "rectangle", mode = "fill", color = {0.7, 0.7, 0.7, 1}, x = 8, y = 12, w = 16, h = 8, rx = 1 },
    }
  },
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