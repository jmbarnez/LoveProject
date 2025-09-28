return {
    id = "fusion_pulse_turret",
    type = "laser",
    name = "Fusion Pulse",
    description = "Radiant beam emitter that channels pulsed fusion energy into targets.",
    price = 2800,
    module = { type = "turret" },
    icon = {
        size = 32,
        shapes = {
            { type = "polygon", mode = "fill", color = {0.06, 0.09, 0.16, 1}, points = {8, 24, 12, 10, 20, 10, 24, 24, 16, 28} },
            { type = "circle", mode = "fill", color = {0.18, 0.26, 0.40, 1}, x = 16, y = 18, r = 5 },
            { type = "circle", mode = "fill", color = {1.00, 0.60, 0.10, 0.9}, x = 16, y = 10, r = 4 },
            { type = "polygon", mode = "fill", color = {1.00, 0.80, 0.35, 0.8}, points = {14, 6, 18, 6, 20, 2, 12, 2} },
        }
    },
    spread = { minDeg = 0.1, maxDeg = 0.2, decay = 900 },
    projectile = "fusion_pulse_beam",
    tracer = { color = {1.00, 0.60, 0.20, 0.9}, width = 1.8, coreRadius = 1.0 },
    impact = {
        shield = { spanDeg = 95, color1 = {1.0, 0.70, 0.30, 0.6}, color2 = {1.0, 0.45, 0.20, 0.45} },
        hull = { spark = {1.0, 0.55, 0.20, 0.6}, ring = {1.0, 0.40, 0.10, 0.4} },
    },
    optimal = 1300,
    falloff = 800,
    damage_range = { min = 3, max = 6 },
    cycle = 1.6,
    capCost = 4.5,
    projectileSpeed = 5000,
    maxRange = 2000,
    maxHeat = 120,
    heatPerShot = 14,
    cooldownRate = 32,
    overheatCooldown = 4.5,
    heatCycleMult = 0.75,
    heatEnergyMult = 1.25,
    fireMode = "automatic"
}
