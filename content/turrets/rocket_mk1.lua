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
      -- Reinforced launcher cradle
      { type = "polygon", mode = "fill", color = {0.10, 0.12, 0.18, 1}, points = {5, 26, 8, 10, 24, 10, 27, 26, 16, 30} },
      { type = "polygon", mode = "fill", color = {0.18, 0.22, 0.30, 1}, points = {8, 22, 10, 14, 22, 14, 24, 22, 16, 26} },
      -- Launch tubes
      { type = "rectangle", mode = "fill", color = {0.20, 0.36, 0.52, 1}, x = 9, y = 14, w = 6, h = 8, rx = 1 },
      { type = "rectangle", mode = "fill", color = {0.20, 0.36, 0.52, 1}, x = 17, y = 14, w = 6, h = 8, rx = 1 },
      -- Rocket chassis
      { type = "polygon", mode = "fill", color = {0.85, 0.32, 0.25, 1}, points = {16, 4, 20, 12, 12, 12} },
      { type = "polygon", mode = "fill", color = {1.00, 0.52, 0.30, 0.9}, points = {16, 5, 19, 11, 13, 11} },
      -- Guidance fins
      { type = "polygon", mode = "fill", color = {0.70, 0.76, 0.82, 1}, points = {12, 12, 10, 16, 14, 16} },
      { type = "polygon", mode = "fill", color = {0.70, 0.76, 0.82, 1}, points = {20, 12, 18, 16, 22, 16} },
      -- Exhaust plumes
      { type = "polygon", mode = "fill", color = {1.00, 0.70, 0.25, 0.85}, points = {14, 16, 18, 16, 21, 24, 11, 24} },
      { type = "polygon", mode = "fill", color = {1.00, 0.45, 0.15, 0.8}, points = {14, 18, 18, 18, 19, 24, 13, 24} },
      -- Targeting strip
      { type = "rectangle", mode = "fill", color = {0.00, 0.75, 0.95, 0.8}, x = 10, y = 20, w = 12, h = 2, rx = 1 },
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
