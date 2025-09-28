return {
    id = "cryo_beam_turret",
    type = "laser",
    name = "Cryo Beam",
    description = "Stasis beam that chills targets, reducing their movement and fire rate.",
    price = 2400,
    module = { type = "turret" },
    icon = {
        size = 32,
        shapes = {
            { type = "polygon", mode = "fill", color = {0.05, 0.08, 0.12, 1}, points = {6, 24, 10, 12, 22, 12, 26, 24, 16, 28} },
            { type = "circle", mode = "fill", color = {0.20, 0.35, 0.55, 1}, x = 16, y = 16, r = 6 },
            { type = "circle", mode = "fill", color = {0.55, 0.90, 1.00, 0.9}, x = 16, y = 10, r = 4 },
            { type = "polygon", mode = "fill", color = {0.75, 1.00, 1.00, 0.8}, points = {14, 6, 18, 6, 19, 2, 13, 2} },
        }
    },
    spread = { minDeg = 0.0, maxDeg = 0.05, decay = 1200 },
    
    -- Embedded projectile definition with slowing effects
    projectile = {
        id = "cryo_beam",
        name = "Cryo Beam",
        class = "Projectile",
        physics = {
            speed = 5000,
            drag = 0,
        },
        renderable = {
            type = "bullet",
            props = {
                kind = "beam",
                radius = 1.5,
                color = {0.55, 0.90, 1.00, 0.9},
            }
        },
        damage = {
            value = 2.5,
            slowEffect = { multiplier = 0.6, duration = 2.5 },
        },
        timed_life = {
            duration = 0.8,
        }
    },
    
    -- Visual effects
    tracer = { color = {0.55, 0.90, 1.00, 0.9}, width = 1.5, coreRadius = 1.0 },
    impact = {
        shield = { spanDeg = 85, color1 = {0.55, 0.90, 1.0, 0.65}, color2 = {0.35, 0.70, 1.0, 0.45} },
        hull = { spark = {0.65, 0.95, 1.0, 0.6}, ring = {0.35, 0.75, 1.0, 0.45} },
    },
    optimal = 1000,
    falloff = 600,
    damage_range = { min = 2, max = 3 },
    cycle = 0.6,
    capCost = 3,
    projectileSpeed = 5000,
    maxRange = 1500,
    slowEffect = { multiplier = 0.6, duration = 2.5 },
    maxHeat = 90,
    heatPerShot = 7,
    cooldownRate = 24,
    overheatCooldown = 4.0,
    heatCycleMult = 0.6,
    heatEnergyMult = 1.1,
    fireMode = "automatic"
}
