return {
    id = "inferno_caster_turret",
    type = "laser",
    name = "Inferno Caster",
    description = "Continuous flame beam that applies stacking burn damage over time.",
    price = 2300,
    module = { type = "turret" },
    icon = {
        size = 32,
        shapes = {
            { type = "rectangle", mode = "fill", color = {0.09, 0.07, 0.05, 1}, x = 8, y = 12, w = 18, h = 14, rx = 3 },
            { type = "polygon", mode = "fill", color = {0.60, 0.20, 0.05, 1}, points = {12, 10, 20, 10, 18, 4, 14, 4} },
            { type = "circle", mode = "fill", color = {1.00, 0.45, 0.05, 0.9}, x = 16, y = 18, r = 3.5 },
            { type = "polygon", mode = "fill", color = {1.00, 0.70, 0.25, 0.8}, points = {14, 6, 18, 6, 19, 2, 13, 2} },
        }
    },
    spread = { minDeg = 0.0, maxDeg = 0.1, decay = 1000 },
    projectile = "inferno_stream",
    tracer = { color = {1.00, 0.45, 0.05, 0.9}, width = 2.2, coreRadius = 1.2 },
    impact = {
        shield = { spanDeg = 70, color1 = {1.0, 0.55, 0.20, 0.6}, color2 = {1.0, 0.35, 0.05, 0.4} },
        hull = { spark = {1.0, 0.45, 0.05, 0.6}, ring = {1.0, 0.30, 0.02, 0.45} },
    },
    optimal = 900,
    falloff = 400,
    damage_range = { min = 2, max = 4 },
    cycle = 0.4,
    capCost = 3.5,
    projectileSpeed = 4600,
    maxRange = 1200,
    damageOverTime = { amount = 1.5, duration = 3.5 },
    maxHeat = 100,
    heatPerShot = 5,
    cooldownRate = 25,
    overheatCooldown = 4.0,
    heatCycleMult = 0.55,
    heatEnergyMult = 1.2,
    fireMode = "automatic"
}
