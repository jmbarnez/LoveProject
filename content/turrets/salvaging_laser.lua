return {
  id = "salvaging_laser",
  type = "salvaging_laser",
  name = "Salvaging Laser",
  description = "Specialized equipment for salvaging valuable materials from ship wreckage.",
  price = 2500,
  icon = {
    size = 32,
    shapes = {
      -- Salvaging laser housing
      { type = "rectangle", mode = "fill", color = {0.2, 0.5, 0.2, 1}, x = 6, y = 10, w = 20, h = 12, rx = 1 },
      -- Lens
      { type = "circle", mode = "fill", color = {0.4, 0.8, 0.4, 1}, x = 16, y = 16, r = 3 },
      -- Salvaging beam
      { type = "rectangle", mode = "fill", color = {0.5, 1.0, 0.5, 0.7}, x = 15, y = 4, w = 2, h = 12 },
      -- Salvage particles
      { type = "circle", mode = "fill", color = {0.6, 1.0, 0.6, 0.5}, x = 16, y = 8, r = 1 },
      { type = "circle", mode = "fill", color = {0.6, 1.0, 0.6, 0.5}, x = 14, y = 12, r = 1 },
      { type = "circle", mode = "fill", color = {0.6, 1.0, 0.6, 0.5}, x = 18, y = 10, r = 1 },
      -- Magnet attachment
      { type = "circle", mode = "fill", color = {0.3, 0.6, 0.3, 1}, x = 16, y = 22, r = 4 },
      { type = "rectangle", mode = "fill", color = {0.4, 0.7, 0.4, 1}, x = 14, y = 20, w = 4, h = 2 },
    }
  },
  -- Visuals: green salvaging beam
  tracer = { color = {0.2, 1.0, 0.3, 0.8}, width = 2.0, coreRadius = 3 },
  impact = {
    wreckage = { spark = {0.3, 1.0, 0.3, 0.8}, ring = {0.2, 0.8, 0.2, 0.6} },
  },
  -- Pulsed salvaging beam, 1 second cycles
  optimal = 850, falloff = 250, tracking = 1.0, sigRes = 120,
  damageMin = 1, damageMax = 2, -- Salvaging damage per pulse
  cycle = 1.0, -- 1 second cycles for pulsing behavior
  capCost = 20, -- Energy cost per pulse
  turnRate = 2.0, -- Slower tracking, salvaging equipment
  spread = { minDeg = 0.05, maxDeg = 0.1, decay = 1000 }, -- Very precise for salvaging
  salvagePower = 1.5, -- Salvaging damage per pulse
  beamDuration = 0.3, -- Visible beam duration per pulse
  -- Heat management for pulsed beam
  maxHeat = 15.0, -- Higher max heat for sustained use
  heatPerShot = 3.0, -- Heat per pulse
  cooldownRate = 8.0, -- Fast cooling between pulses
  overheatDuration = 2.0, -- Quick recovery from overheat
}
