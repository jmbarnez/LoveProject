return {
    id = "corrosion_ray_turret",
    type = "laser",
    name = "Corrosion Ray",
    description = "Chemical beam that corrodes hull plating and reduces armor effectiveness.",
    price = 2100,
    module = { type = "turret" },
    icon = {
        size = 32,
        shapes = {
            { type = "rectangle", mode = "fill", color = {0.07, 0.09, 0.11, 1}, x = 9, y = 12, w = 16, h = 14, rx = 3 },
            { type = "circle", mode = "fill", color = {0.25, 0.35, 0.20, 1}, x = 16, y = 18, r = 4 },
            { type = "polygon", mode = "fill", color = {0.65, 0.85, 0.35, 0.9}, points = {12, 8, 20, 8, 18, 4, 14, 4} },
            { type = "polygon", mode = "fill", color = {0.85, 1.00, 0.45, 0.8}, points = {14, 6, 18, 6, 19, 2, 13, 2} },
        }
    },
    spread = { minDeg = 0.1, maxDeg = 0.4, decay = 900 },
    projectile = "corrosion_stream",
    tracer = { color = {0.75, 0.95, 0.45, 0.9}, width = 1.6, coreRadius = 1.1 },
    impact = {
        shield = { spanDeg = 70, color1 = {0.75, 0.95, 0.45, 0.55}, color2 = {0.55, 0.80, 0.30, 0.4} },
        hull = { spark = {0.75, 0.90, 0.35, 0.55}, ring = {0.55, 0.70, 0.25, 0.45} },
    },
    optimal = 900,
    falloff = 500,
    damage_range = { min = 2, max = 3.5 },
    cycle = 0.7,
    capCost = 3.2,
    projectileSpeed = 4200,
    maxRange = 1400,
    armorCorrosion = { multiplier = 0.7, duration = 3.0 },
    maxHeat = 85,
    heatPerShot = 6,
    cooldownRate = 24,
    overheatCooldown = 4.0,
    heatCycleMult = 0.6,
    heatEnergyMult = 1.15,
    fireMode = "automatic"
}
