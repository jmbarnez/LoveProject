return {
    id = "heavy_gauss_turret",
    type = "gun",
    name = "Heavy Gauss Driver",
    description = "High-mass coilgun that fires super-dense slugs for armor piercing damage.",
    price = 2100,
    module = { type = "turret" },
    icon = {
        size = 32,
        shapes = {
            { type = "rectangle", mode = "fill", color = {0.06, 0.08, 0.14, 1}, x = 7, y = 10, w = 18, h = 14, rx = 2 },
            { type = "rectangle", mode = "fill", color = {0.18, 0.22, 0.30, 1}, x = 11, y = 6, w = 10, h = 20, rx = 2 },
            { type = "rectangle", mode = "fill", color = {0.70, 0.85, 1.00, 0.9}, x = 14, y = 2, w = 4, h = 8 },
            { type = "circle", mode = "fill", color = {0.35, 0.70, 1.00, 0.8}, x = 16, y = 20, r = 2.5 },
        }
    },
    spread = { minDeg = 0.05, maxDeg = 0.25, decay = 800 },
    projectile = "gauss_slug",
    tracer = { color = {0.65, 0.85, 1.00, 1.0}, width = 1.8, coreRadius = 2.5 },
    impact = {
        shield = { spanDeg = 90, color1 = {0.40, 0.85, 1.0, 0.6}, color2 = {0.25, 0.55, 1.0, 0.4} },
        hull = { spark = {0.85, 0.95, 1.0, 0.6}, ring = {0.45, 0.65, 1.0, 0.5} },
    },
    optimal = 1400,
    falloff = 800,
    damage_range = { min = 4, max = 7 },
    cycle = 3.5,
    capCost = 6,
    projectileSpeed = 6000,
    maxRange = 2600,
    maxHeat = 120,
    heatPerShot = 22,
    cooldownRate = 18,
    overheatCooldown = 6.0,
    heatCycleMult = 0.7,
    heatEnergyMult = 1.4,
    fireMode = "manual"
}
