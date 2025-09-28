return {
    id = "plasma_lance_turret",
    type = "plasma",
    name = "Plasma Lance",
    description = "Superheated plasma injector that delivers searing bolts of energy.",
    price = 2500,
    module = { type = "turret" },
    icon = {
        size = 32,
        shapes = {
            { type = "polygon", mode = "fill", color = {0.07, 0.10, 0.18, 1}, points = {6, 24, 10, 12, 22, 12, 26, 24, 16, 28} },
            { type = "circle", mode = "fill", color = {0.20, 0.30, 0.45, 1}, x = 16, y = 16, r = 6 },
            { type = "circle", mode = "fill", color = {0.85, 0.40, 1.00, 0.9}, x = 16, y = 10, r = 4 },
            { type = "circle", mode = "fill", color = {1.00, 0.65, 0.25, 0.8}, x = 16, y = 6, r = 2 },
        }
    },
    spread = { minDeg = 0.2, maxDeg = 0.8, decay = 700 },
    
    -- Embedded projectile definition
    projectile = {
        id = "plasma_lance_bolt",
        name = "Plasma Lance Bolt",
        class = "Projectile",
        physics = {
            speed = 5200,
            drag = 0,
        },
        renderable = {
            type = "bullet",
            props = {
                kind = "bolt",
                radius = 2.5,
                color = {0.90, 0.45, 1.00, 1.0},
            }
        },
        damage = {
            value = 5.0,
        },
        timed_life = {
            duration = 2.8,
        }
    },
    
    -- Visual effects
    tracer = { color = {0.90, 0.45, 1.00, 1.0}, width = 1.6, coreRadius = 1.8 },
    impact = {
        shield = { spanDeg = 85, color1 = {0.90, 0.45, 1.0, 0.65}, color2 = {0.65, 0.30, 1.0, 0.4} },
        hull = { spark = {1.0, 0.55, 0.35, 0.6}, ring = {1.0, 0.35, 0.25, 0.45} },
    },
    optimal = 1100,
    falloff = 700,
    damage_range = { min = 4, max = 6 },
    cycle = 1.8,
    capCost = 5,
    projectileSpeed = 5200,
    maxRange = 1800,
    maxHeat = 110,
    heatPerShot = 16,
    cooldownRate = 28,
    overheatCooldown = 4.5,
    heatCycleMult = 0.7,
    heatEnergyMult = 1.3,
    fireMode = "automatic"
}
