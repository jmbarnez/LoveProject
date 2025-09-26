return {
  id = "rocket_mk1",
  type = "missile",
  name = "Tech 1 Rocket Launcher",
  description = "Guided missile launcher with strong homing capability and heavy damage.",
  price = 3000,
  module = { type = "turret" },
  icon = {
    size = 32,
    shapes = {
      -- Rocket launcher housing
      { type = "rectangle", mode = "fill", color = {0.4, 0.4, 0.4, 1}, x = 4, y = 12, w = 24, h = 8, rx = 1 },
      -- Rocket
      { type = "rectangle", mode = "fill", color = {0.8, 0.3, 0.1, 1}, x = 12, y = 6, w = 8, h = 16 },
      -- Rocket nose
      { type = "polygon", mode = "fill", color = {0.9, 0.4, 0.2, 1}, points = {12, 6, 16, 2, 20, 6} },
      -- Fins
      { type = "rectangle", mode = "fill", color = {0.6, 0.6, 0.6, 1}, x = 10, y = 18, w = 2, h = 4 },
      { type = "rectangle", mode = "fill", color = {0.6, 0.6, 0.6, 1}, x = 20, y = 18, w = 2, h = 4 },
      -- Exhaust
      { type = "rectangle", mode = "fill", color = {1.0, 0.8, 0.3, 0.8}, x = 14, y = 22, w = 4, h = 6 },
      -- Launch rails
      { type = "rectangle", mode = "fill", color = {0.3, 0.3, 0.3, 1}, x = 2, y = 14, w = 28, h = 2 },
    }
  },
  -- Visuals: warm orange rocket + exhaust
  tracer = { color = {1.00, 0.70, 0.25}, width = 2, coreRadius = 6 },
  impact = {
    shield = { spanDeg = 70, color1 = {1.0, 0.75, 0.35, 0.55}, color2 = {1.0, 0.55, 0.25, 0.40} },
    hull = { spark = {1.0, 0.55, 0.15, 0.6}, ring = {1.0, 0.35, 0.05, 0.5} },
  },
  -- Long range with homing, heavy damage but slow
  optimal = 1500, falloff = 2500,
  damage_range = { min = 3, max = 5 },
  cycle = 6.0, capCost = 8,
  spread = { minDeg = 1.2, maxDeg = 3.5, decay = 300 }, -- Less accurate initially
  -- Homing properties
  homingStrength = 0.8, -- Strong homing capability
  missileTurnRate = 4.5, -- How fast the missile can change direction
  maxRange = 3000, -- Missiles explode after traveling 3000 units
  -- Overheating parameters (missiles generate less heat due to slower firing)
  maxHeat = 60, -- Lower heat capacity due to slower cycle
  heatPerShot = 15, -- Moderate heat per shot
  cooldownRate = 12, -- Heat dissipation rate
  overheatDuration = 5.0, -- Longer disable time due to complex systems
  heatCycleMult = 0.6, -- Slower firing when hot
  heatEnergyMult = 1.4, -- Energy cost increase when hot

  -- Firing mode: "manual" or "automatic"
  fireMode = "manual" -- Missile launchers should be manually controlled
}
