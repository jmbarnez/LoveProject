return {
    id = "shard_spitter_turret",
    type = "gun",
    name = "Shard Spitter",
    description = "Organic-inspired launcher that spits crystalline shards at blistering speed.",
    price = 1500,
    module = { type = "turret" },
    icon = {
        size = 32,
        shapes = {
            { type = "rectangle", mode = "fill", color = {0.08, 0.06, 0.10, 1}, x = 9, y = 12, w = 16, h = 14, rx = 3 },
            { type = "circle", mode = "fill", color = {0.25, 0.10, 0.30, 1}, x = 16, y = 18, r = 4 },
            { type = "polygon", mode = "fill", color = {0.90, 0.40, 0.95, 0.9}, points = {12, 8, 20, 8, 16, 2} },
            { type = "circle", mode = "fill", color = {1.00, 0.75, 0.95, 0.8}, x = 16, y = 8, r = 2 },
        }
    },
    spread = { minDeg = 0.6, maxDeg = 2.4, decay = 520 },
    projectile = "shard_spike",
    tracer = { color = {0.90, 0.40, 0.95, 0.9}, width = 1.4, coreRadius = 1.5 },
    impact = {
        shield = { spanDeg = 70, color1 = {0.90, 0.50, 1.0, 0.6}, color2 = {0.65, 0.30, 0.95, 0.4} },
        hull = { spark = {0.95, 0.45, 1.0, 0.6}, ring = {0.70, 0.35, 0.95, 0.4} },
    },
    optimal = 800,
    falloff = 700,
    damage_range = { min = 2.5, max = 4.0 },
    cycle = 0.45,
    capCost = 2.0,
    projectileSpeed = 5000,
    maxRange = 1500,
    bleedingChance = 0.3,
    maxHeat = 90,
    heatPerShot = 7,
    cooldownRate = 24,
    overheatCooldown = 4.2,
    heatCycleMult = 0.55,
    heatEnergyMult = 1.2,
    fireMode = "automatic"
}
