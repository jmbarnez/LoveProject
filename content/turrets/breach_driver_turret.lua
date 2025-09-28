return {
    id = "breach_driver_turret",
    type = "gun",
    name = "Breach Driver",
    description = "Focused breaching cannon that specializes in hull penetration and subsystem damage.",
    price = 2900,
    module = { type = "turret" },
    icon = {
        size = 32,
        shapes = {
            { type = "rectangle", mode = "fill", color = {0.07, 0.08, 0.14, 1}, x = 9, y = 10, w = 16, h = 16, rx = 3 },
            { type = "rectangle", mode = "fill", color = {0.22, 0.26, 0.34, 1}, x = 13, y = 6, w = 8, h = 18, rx = 2 },
            { type = "polygon", mode = "fill", color = {1.00, 0.45, 0.15, 0.85}, points = {14, 4, 18, 4, 19, 0, 13, 0} },
            { type = "circle", mode = "fill", color = {1.00, 0.55, 0.35, 0.8}, x = 16, y = 20, r = 2.5 },
        }
    },
    spread = { minDeg = 0.08, maxDeg = 0.3, decay = 900 },
    projectile = "breach_round",
    tracer = { color = {1.00, 0.55, 0.35, 0.9}, width = 1.6, coreRadius = 2 },
    impact = {
        shield = { spanDeg = 80, color1 = {1.0, 0.60, 0.30, 0.6}, color2 = {0.95, 0.45, 0.20, 0.4} },
        hull = { spark = {1.0, 0.55, 0.20, 0.6}, ring = {1.0, 0.40, 0.10, 0.45} },
    },
    optimal = 1500,
    falloff = 900,
    damage_range = { min = 5, max = 6.5 },
    cycle = 2.6,
    capCost = 4.5,
    projectileSpeed = 5600,
    maxRange = 2400,
    subsystemDamage = 1.5,
    maxHeat = 105,
    heatPerShot = 14,
    cooldownRate = 20,
    overheatCooldown = 5.0,
    heatCycleMult = 0.65,
    heatEnergyMult = 1.3,
    fireMode = "manual"
}
