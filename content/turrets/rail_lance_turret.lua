return {
    id = "rail_lance_turret",
    type = "gun",
    name = "Rail Lance",
    description = "Ultra-high velocity spear that excels at punching through capital ships.",
    price = 3200,
    module = { type = "turret" },
    icon = {
        size = 32,
        shapes = {
            { type = "rectangle", mode = "fill", color = {0.05, 0.08, 0.14, 1}, x = 9, y = 10, w = 16, h = 16, rx = 2 },
            { type = "rectangle", mode = "fill", color = {0.18, 0.26, 0.32, 1}, x = 13, y = 6, w = 8, h = 20, rx = 1 },
            { type = "polygon", mode = "fill", color = {0.80, 0.95, 1.00, 0.9}, points = {14, 2, 18, 2, 19, 0, 13, 0} },
            { type = "polygon", mode = "line", color = {0.35, 0.80, 1.00, 0.8}, points = {12, 8, 20, 8, 16, 20}, lineWidth = 1.2 },
        }
    },
    spread = { minDeg = 0.02, maxDeg = 0.1, decay = 1200 },
    projectile = "rail_lance_spike",
    tracer = { color = {0.80, 0.95, 1.00, 1.0}, width = 1.2, coreRadius = 1.5 },
    impact = {
        shield = { spanDeg = 110, color1 = {0.55, 0.95, 1.0, 0.7}, color2 = {0.30, 0.70, 1.0, 0.45} },
        hull = { spark = {0.90, 0.95, 1.0, 0.6}, ring = {0.45, 0.65, 1.0, 0.5} },
    },
    optimal = 2000,
    falloff = 1000,
    damage_range = { min = 6, max = 9 },
    cycle = 4.5,
    capCost = 8,
    projectileSpeed = 7200,
    maxRange = 3200,
    maxHeat = 140,
    heatPerShot = 26,
    cooldownRate = 16,
    overheatCooldown = 6.5,
    heatCycleMult = 0.75,
    heatEnergyMult = 1.5,
    fireMode = "manual"
}
