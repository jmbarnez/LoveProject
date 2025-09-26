return {
  id = "mining_laser",
  type = "mining_laser",
  name = "Mining Laser",
  description = "Specialized mining equipment for extracting ore from asteroids.",
  price = 2000,
  module = { type = "turret" },
  icon = {
    size = 32,
    shapes = {
      -- Articulated mining frame
      { type = "polygon", mode = "fill", color = {0.10, 0.11, 0.18, 1}, points = {6, 24, 9, 10, 23, 10, 26, 24, 16, 30} },
      { type = "polygon", mode = "fill", color = {0.28, 0.20, 0.12, 1}, points = {8, 20, 12, 12, 20, 12, 24, 20, 16, 26} },
      -- Power conduits
      { type = "rectangle", mode = "fill", color = {0.72, 0.48, 0.22, 1}, x = 10, y = 14, w = 12, h = 3, rx = 1 },
      { type = "rectangle", mode = "fill", color = {0.90, 0.64, 0.30, 1}, x = 12, y = 18, w = 8, h = 2, rx = 1 },
      -- Focused emitter core
      { type = "circle", mode = "fill", color = {0.25, 0.16, 0.10, 1}, x = 16, y = 12, r = 3 },
      { type = "circle", mode = "fill", color = {1.00, 0.78, 0.36, 0.9}, x = 16, y = 12, r = 1.8 },
      -- Mining beam
      { type = "polygon", mode = "fill", color = {1.00, 0.86, 0.42, 0.75}, points = {14, 13, 18, 13, 21, 28, 11, 28} },
      { type = "polygon", mode = "fill", color = {1.00, 0.95, 0.60, 0.8}, points = {15, 13, 17, 13, 19, 28, 13, 28} },
      -- Target crystal
      { type = "polygon", mode = "fill", color = {0.55, 0.80, 1.00, 0.9}, points = {13, 26, 16, 30, 19, 26, 16, 22} },
      { type = "polygon", mode = "line", color = {0.80, 0.95, 1.00, 0.7}, points = {13, 26, 16, 30, 19, 26, 16, 22}, lineWidth = 1 },
      -- Sensor lights
      { type = "circle", mode = "fill", color = {1.00, 0.80, 0.35, 0.85}, x = 12, y = 18, r = 1.1 },
      { type = "circle", mode = "fill", color = {1.00, 0.80, 0.35, 0.85}, x = 20, y = 18, r = 1.1 },
    }
  },
  -- Yellow mining beam
  tracer = { color = {1.0, 1.0, 0.0, 0.8}, width = 2.0, coreRadius = 2 },
  impact = {
    asteroid = {
      spark = {1.0, 0.9, 0.5, 0.8},    -- Bright sparks for visible feedback
      ring = {0.9, 0.7, 0.3, 0.6},     -- Visible ring effect
      particles = {1.0, 0.8, 0.2, 0.7} -- Bright particles
    },
  },
  -- Pulsed mining beam, 3 second cycles
  optimal = 850, falloff = 250,
  damageMin = 1, damageMax = 2, -- Mining damage per pulse
  cycle = 3.0, -- 3 second cycles for pulsing behavior
  capCost = 25, -- Energy cost per pulse
  spread = { minDeg = 0.05, maxDeg = 0.1, decay = 1000 }, -- Very precise for mining
  miningPower = 2.5, -- Mining damage per pulse
  beamDuration = 0.2, -- Visible beam duration per pulse
  -- Heat management for pulsed beam
  maxHeat = 20.0, -- Higher max heat for sustained use
  heatPerShot = 5.0, -- Heat per pulse
  cooldownRate = 10.0, -- Fast cooling between pulses
  overheatDuration = 2.0, -- Quick recovery from overheat

  -- Firing mode: "manual" or "automatic"
  fireMode = "manual" -- Mining lasers should be manually controlled
}

