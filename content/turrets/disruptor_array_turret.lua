return {
    id = "disruptor_array_turret",
    type = "laser",
    name = "Disruptor Array",
    description = "Multi-phase emitter that disrupts shields and destabilizes energy systems.",
    price = 3000,
    module = { type = "turret" },
    icon = {
        size = 32,
        shapes = {
            { type = "rectangle", mode = "fill", color = {0.06, 0.08, 0.14, 1}, x = 8, y = 11, w = 18, h = 15, rx = 2 },
            { type = "circle", mode = "fill", color = {0.15, 0.25, 0.45, 1}, x = 16, y = 17, r = 5 },
            { type = "polygon", mode = "fill", color = {0.45, 0.95, 1.00, 0.9}, points = {12, 6, 20, 6, 18, 2, 14, 2} },
            { type = "polygon", mode = "line", color = {0.35, 0.85, 1.00, 0.8}, points = {12, 10, 20, 10, 16, 4}, lineWidth = 1 },
        }
    },
    spread = { minDeg = 0.05, maxDeg = 0.3, decay = 1000 },
    projectile = "disruptor_wave",
    tracer = { color = {0.45, 0.95, 1.00, 0.9}, width = 2.0, coreRadius = 1.1 },
    impact = {
        shield = { spanDeg = 100, color1 = {0.45, 0.95, 1.0, 0.7}, color2 = {0.25, 0.75, 1.0, 0.45} },
        hull = { spark = {0.55, 0.90, 1.0, 0.55}, ring = {0.30, 0.70, 1.0, 0.4} },
    },
    optimal = 1500,
    falloff = 900,
    damage_range = { min = 3, max = 5 },
    cycle = 1.4,
    capCost = 5.5,
    projectileSpeed = 5400,
    maxRange = 2100,
    shieldBreaker = 1.6,
    maxHeat = 130,
    heatPerShot = 18,
    cooldownRate = 30,
    overheatCooldown = 5.0,
    heatCycleMult = 0.75,
    heatEnergyMult = 1.35,
    fireMode = "automatic"
}
