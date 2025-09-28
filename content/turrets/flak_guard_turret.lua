return {
    id = "flak_guard_turret",
    type = "gun",
    name = "Flak Guard",
    description = "Explosive flak launcher tuned for intercepting fighters and missiles.",
    price = 1200,
    module = { type = "turret" },
    icon = {
        size = 32,
        shapes = {
            { type = "rectangle", mode = "fill", color = {0.08, 0.11, 0.16, 1}, x = 8, y = 12, w = 18, h = 14, rx = 3 },
            { type = "rectangle", mode = "fill", color = {0.20, 0.28, 0.36, 1}, x = 12, y = 8, w = 10, h = 18, rx = 2 },
            { type = "polygon", mode = "fill", color = {1.00, 0.55, 0.25, 0.9}, points = {14, 6, 18, 6, 20, 4, 12, 4} },
            { type = "circle", mode = "fill", color = {1.00, 0.80, 0.35, 0.8}, x = 16, y = 20, r = 3 },
        }
    },
    spread = { minDeg = 1.5, maxDeg = 5.0, decay = 300 },
    projectile = "flak_shard",
    tracer = { color = {1.00, 0.75, 0.35, 0.9}, width = 1.6, coreRadius = 2.5 },
    impact = {
        shield = { spanDeg = 70, color1 = {1.0, 0.75, 0.45, 0.6}, color2 = {1.0, 0.55, 0.30, 0.4} },
        hull = { spark = {1.0, 0.75, 0.25, 0.7}, ring = {1.0, 0.55, 0.15, 0.5} },
    },
    optimal = 600,
    falloff = 500,
    damage_range = { min = 2, max = 4 },
    cycle = 1.2,
    capCost = 3,
    projectileSpeed = 3200,
    maxRange = 1600,
    explosionRadius = 80,
    maxHeat = 90,
    heatPerShot = 12,
    cooldownRate = 18,
    overheatCooldown = 5.0,
    heatCycleMult = 0.65,
    heatEnergyMult = 1.25,
    fireMode = "automatic"
}
