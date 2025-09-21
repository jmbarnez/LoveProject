return {
  id = "boss_cone_gun",
  type = "gun",
  name = "Boss Cone Blaster",
  description = "Fires a 4-shot cone spray of kinetic slugs.",
  price = 0,
  icon = {
    size = 32,
    shapes = {
      { type = "rectangle", mode = "fill", color = {0.4, 0.4, 0.45, 1}, x = 6, y = 10, w = 22, h = 12, rx = 2 },
      { type = "rectangle", mode = "fill", color = {0.85, 0.4, 0.2, 1}, x = 24, y = 13, w = 6, h = 6, rx = 1 },
      { type = "polygon", mode = "line", color = {1.0, 0.6, 0.2, 0.9}, points = { 6,16,  18,10,  28,16,  18,22 } },
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
