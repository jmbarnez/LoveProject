return {
    id = "siege_breaker_turret",
    type = "cannon",
    name = "Siege Breaker",
    description = "Siege mortar that fires high arc shells for area bombardment.",
    price = 2800,
    module = { type = "turret" },
    icon = {
        size = 32,
        shapes = {
            { type = "polygon", mode = "fill", color = {0.09, 0.08, 0.06, 1}, points = {6, 26, 12, 8, 20, 8, 26, 26, 16, 30} },
            { type = "rectangle", mode = "fill", color = {0.24, 0.20, 0.12, 1}, x = 12, y = 10, w = 8, h = 16, rx = 2 },
            { type = "polygon", mode = "fill", color = {0.75, 0.55, 0.25, 0.9}, points = {14, 8, 18, 8, 17, 4, 15, 4} },
        }
    },
    spread = { minDeg = 1.0, maxDeg = 3.5, decay = 350 },
    projectile = "siege_shell",
    tracer = { color = {0.95, 0.75, 0.45, 0.9}, width = 2.4, coreRadius = 3 },
    impact = {
        shield = { spanDeg = 90, color1 = {0.95, 0.80, 0.50, 0.6}, color2 = {0.85, 0.60, 0.25, 0.45} },
        hull = { spark = {1.0, 0.65, 0.30, 0.6}, ring = {1.0, 0.45, 0.20, 0.45} },
    },
    optimal = 900,
    falloff = 1500,
    damage_range = { min = 5, max = 7 },
    cycle = 3.8,
    capCost = 4.5,
    projectileSpeed = 2200,
    maxRange = 2400,
    arcShot = true,
    explosionRadius = 120,
    maxHeat = 100,
    heatPerShot = 16,
    cooldownRate = 16,
    overheatCooldown = 5.0,
    heatCycleMult = 0.6,
    heatEnergyMult = 1.2,
    fireMode = "manual"
}
