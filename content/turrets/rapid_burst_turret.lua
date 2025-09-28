return {
    id = "rapid_burst_turret",
    type = "gun",
    name = "Rapid Burst Turret",
    description = "Compact rotary cannon that saturates targets with kinetic bursts.",
    price = 650,
    module = { type = "turret" },
    icon = {
        size = 32,
        shapes = {
            { type = "rectangle", mode = "fill", color = {0.08, 0.12, 0.20, 1}, x = 6, y = 12, w = 20, h = 12, rx = 3 },
            { type = "rectangle", mode = "fill", color = {0.16, 0.24, 0.34, 1}, x = 10, y = 10, w = 12, h = 16, rx = 2 },
            { type = "polygon", mode = "fill", color = {0.80, 0.90, 1.00, 0.9}, points = {14, 6, 18, 6, 20, 4, 12, 4} },
            { type = "circle", mode = "fill", color = {0.25, 0.70, 1.00, 0.9}, x = 16, y = 18, r = 3 },
        }
    },
    spread = { minDeg = 0.4, maxDeg = 2.4, decay = 500 },
    projectile = "rapid_burst_round",
    tracer = { color = {0.35, 0.80, 1.00, 0.9}, width = 1.2, coreRadius = 2 },
    impact = {
        shield = { spanDeg = 60, color1 = {0.45, 0.85, 1.0, 0.55}, color2 = {0.25, 0.65, 1.0, 0.35} },
        hull = { spark = {1.0, 0.75, 0.25, 0.7}, ring = {1.0, 0.45, 0.15, 0.4} },
    },
    optimal = 500,
    falloff = 450,
    damage_range = { min = 0.8, max = 1.4 },
    cycle = 0.25,
    capCost = 1.5,
    projectileSpeed = 4200,
    maxRange = 1400,
    maxHeat = 80,
    heatPerShot = 6,
    cooldownRate = 20,
    overheatCooldown = 4.0,
    heatCycleMult = 0.6,
    heatEnergyMult = 1.2,
    fireMode = "automatic"
}
