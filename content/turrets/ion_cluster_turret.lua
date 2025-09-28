return {
    id = "ion_cluster_turret",
    type = "gun",
    name = "Ion Cluster",
    description = "Charged ion blaster that releases clusters of electrified shards.",
    price = 1800,
    module = { type = "turret" },
    icon = {
        size = 32,
        shapes = {
            { type = "rectangle", mode = "fill", color = {0.07, 0.09, 0.15, 1}, x = 9, y = 12, w = 16, h = 14, rx = 3 },
            { type = "circle", mode = "fill", color = {0.20, 0.30, 0.45, 1}, x = 16, y = 18, r = 4 },
            { type = "circle", mode = "fill", color = {0.55, 0.95, 1.00, 0.9}, x = 13, y = 12, r = 2.5 },
            { type = "circle", mode = "fill", color = {0.35, 0.85, 1.00, 0.85}, x = 19, y = 12, r = 2.5 },
        }
    },
    spread = { minDeg = 0.8, maxDeg = 3.0, decay = 500 },
    projectile = "ion_cluster_burst",
    tracer = { color = {0.55, 0.95, 1.00, 0.9}, width = 1.4, coreRadius = 1.6 },
    impact = {
        shield = { spanDeg = 75, color1 = {0.55, 0.95, 1.0, 0.65}, color2 = {0.35, 0.75, 1.0, 0.45} },
        hull = { spark = {0.80, 0.95, 1.0, 0.5}, ring = {0.45, 0.75, 1.0, 0.4} },
    },
    optimal = 700,
    falloff = 600,
    damage_range = { min = 2, max = 3.5 },
    cycle = 0.5,
    capCost = 2.2,
    projectileSpeed = 4400,
    maxRange = 1400,
    ionChance = 0.35,
    maxHeat = 85,
    heatPerShot = 7,
    cooldownRate = 22,
    overheatCooldown = 3.8,
    heatCycleMult = 0.55,
    heatEnergyMult = 1.15,
    fireMode = "automatic"
}
