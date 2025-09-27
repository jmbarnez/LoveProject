return {
  id = "boss_cone_gun",
  type = "gun",
  name = "Boss Cone Blaster",
  description = "Fires a 4-shot cone spray of kinetic slugs.",
  price = 0,
  module = { type = "turret" },
  icon = {
    size = 32,
    shapes = {
      -- Hardened emitter wedge
      { type = "polygon", mode = "fill", color = {0.10, 0.10, 0.18, 1}, points = {6, 26, 10, 12, 22, 12, 26, 26, 16, 30} },
      { type = "polygon", mode = "fill", color = {0.28, 0.18, 0.36, 1}, points = {8, 22, 12, 14, 20, 14, 24, 22, 16, 26} },
      -- Triple plasma barrels
      { type = "circle", mode = "fill", color = {1.00, 0.58, 0.28, 1}, x = 12, y = 12, r = 2.2 },
      { type = "circle", mode = "fill", color = {1.00, 0.66, 0.32, 1}, x = 16, y = 11, r = 2.5 },
      { type = "circle", mode = "fill", color = {1.00, 0.58, 0.28, 1}, x = 20, y = 12, r = 2.2 },
      { type = "rectangle", mode = "fill", color = {0.55, 0.18, 0.30, 1}, x = 10, y = 10, w = 12, h = 4, rx = 1.5 },
      -- Cone of fire reticles
      { type = "polygon", mode = "line", color = {1.00, 0.70, 0.30, 0.9}, points = {8, 18, 16, 8, 24, 18, 16, 24}, lineWidth = 1.6 },
      { type = "polygon", mode = "line", color = {1.00, 0.45, 0.20, 0.7}, points = {10, 19, 16, 11, 22, 19, 16, 23}, lineWidth = 1.2 },
      -- Core glow
      { type = "circle", mode = "fill", color = {0.95, 0.78, 0.32, 0.85}, x = 16, y = 19, r = 2.3 },
      -- Thruster vent accent
      { type = "rectangle", mode = "fill", color = {0.10, 0.60, 0.90, 0.75}, x = 12, y = 22, w = 8, h = 2, rx = 1 },
    }
  },
  spread = { minDeg = 0.0, maxDeg = 0.0, decay = 800 },
  projectile = "gun_bullet",
  tracer = { color = {1.0, 0.55, 0.2, 1.0}, width = 1, coreRadius = 2 },
  impact = {
    shield = { spanDeg = 80, color1 = {1.0, 0.6, 0.2, 0.5}, color2 = {1.0, 0.3, 0.1, 0.4} },
    hull = { spark = {1.0, 0.7, 0.2, 0.6}, ring = {1.0, 0.4, 0.1, 0.4} },
  },
  optimal = 700, falloff = 500,
  damage_range = { min = 2, max = 3 },
  cycle = 1.0, capCost = 0,
  projectileSpeed = 800,
  baseAccuracy = 0.9,
  -- Volley settings
  volleyCount = 3,
  volleySpreadDeg = 30,
  -- Also fires a slow rocket alongside the cone
  secondaryProjectile = "missile",
  secondaryProjectileSpeed = 600,
  secondaryFireEvery = 1,

  -- Firing mode: "manual" or "automatic"
  fireMode = "manual"
}

