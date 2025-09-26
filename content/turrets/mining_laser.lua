return {
  id = "mining_laser",
  type = "mining_laser",
  name = "Mining Laser",
  description = "Specialized mining equipment for extracting ore from asteroids.",
  price = 2000,
  icon = {
    size = 32,
    shapes = {
      -- Mining laser housing
      { type = "rectangle", mode = "fill", color = {0.6, 0.4, 0.2, 1}, x = 6, y = 10, w = 20, h = 12, rx = 1 },
      -- Lens
      { type = "circle", mode = "fill", color = {0.8, 0.6, 0.3, 1}, x = 16, y = 16, r = 3 },
      -- Mining beam
      { type = "rectangle", mode = "fill", color = {1.0, 0.8, 0.4, 0.7}, x = 15, y = 4, w = 2, h = 12 },
      -- Mining particles
      { type = "circle", mode = "fill", color = {1.0, 0.9, 0.5, 0.5}, x = 16, y = 8, r = 1 },
      { type = "circle", mode = "fill", color = {1.0, 0.9, 0.5, 0.5}, x = 14, y = 12, r = 1 },
      { type = "circle", mode = "fill", color = {1.0, 0.9, 0.5, 0.5}, x = 18, y = 10, r = 1 },
      -- Drill bit
      { type = "polygon", mode = "fill", color = {0.4, 0.4, 0.4, 1}, points = {14, 22, 16, 26, 18, 22} },
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
