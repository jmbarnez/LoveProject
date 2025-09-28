return {
  id = "salvaging_laser",
  type = "salvaging_laser",
  name = "Salvaging Laser",
  description = "Specialized equipment for salvaging valuable materials from ship wreckage.",
  price = 2500,
  module = { type = "turret" },
  icon = {
    size = 32,
    shapes = {
      -- Adaptive salvage frame
      { type = "polygon", mode = "fill", color = {0.08, 0.12, 0.10, 1}, points = {6, 24, 9, 10, 23, 10, 26, 24, 16, 30} },
      { type = "polygon", mode = "fill", color = {0.16, 0.36, 0.20, 1}, points = {8, 20, 12, 12, 20, 12, 24, 20, 16, 26} },
      -- Stabilized emitter core
      { type = "circle", mode = "fill", color = {0.12, 0.35, 0.18, 1}, x = 16, y = 12, r = 3.2 },
      { type = "circle", mode = "fill", color = {0.40, 0.85, 0.45, 0.95}, x = 16, y = 12, r = 2 },
      -- Salvage beam
      { type = "polygon", mode = "fill", color = {0.45, 1.00, 0.60, 0.75}, points = {14, 13, 18, 13, 22, 28, 10, 28} },
      { type = "polygon", mode = "fill", color = {0.70, 1.00, 0.80, 0.85}, points = {15, 13, 17, 13, 20, 28, 12, 28} },
      -- Magnetized recovery claws
      { type = "polygon", mode = "fill", color = {0.05, 0.45, 0.28, 1}, points = {10, 20, 6, 24, 10, 24, 12, 22} },
      { type = "polygon", mode = "fill", color = {0.05, 0.45, 0.28, 1}, points = {22, 20, 26, 24, 22, 24, 20, 22} },
      -- Salvaged fragment
      { type = "polygon", mode = "fill", color = {0.65, 0.82, 0.65, 0.9}, points = {13, 26, 16, 29, 19, 26, 16, 23} },
      { type = "polygon", mode = "line", color = {0.80, 1.00, 0.80, 0.65}, points = {13, 26, 16, 29, 19, 26, 16, 23}, lineWidth = 1 },
      -- Scanner lights
      { type = "circle", mode = "fill", color = {0.40, 1.00, 0.60, 0.9}, x = 12, y = 18, r = 1.1 },
      { type = "circle", mode = "fill", color = {0.40, 1.00, 0.60, 0.9}, x = 20, y = 18, r = 1.1 },
    }
  },
  -- Visuals: green salvaging beam
  tracer = { color = {0.2, 1.0, 0.3, 0.8}, width = 2.0, coreRadius = 3 },
  impact = {
    wreckage = { spark = {0.3, 1.0, 0.3, 0.8}, ring = {0.2, 0.8, 0.2, 0.6} },
  },
  -- Continuous salvaging beam, tuned for gentle stripping of wreckage
  optimal = 850, falloff = 250,
  damageMin = 1, damageMax = 2, -- Salvaging damage per pulse
  cycle = 3.0, -- Seconds required to apply salvagePower worth of extraction
  capCost = 20, -- Energy cost budget per cycle window
  spread = { minDeg = 0.05, maxDeg = 0.1, decay = 1000 }, -- Very precise for salvaging
  salvagePower = 1, -- Total salvage progress applied across each cycle window
  beamDuration = 0.3, -- Legacy rendering hint for beam visuals
  -- Heat management for continuous beam
  maxHeat = 15.0, -- Higher max heat for sustained use
  heatPerShot = 3.0, -- Heat generated across each cycle window
  cooldownRate = 8.0, -- Fast cooling between pulses/pauses
  overheatCooldown = 5.0, -- Fixed cooldown window after overheating

  -- Firing mode: "manual" or "automatic"
  fireMode = "manual" -- Salvaging lasers should be manually controlled
}

