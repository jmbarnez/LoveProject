return {
    id = "graviton_well_turret",
    type = "cannon",
    name = "Graviton Well",
    description = "Launches compressive gravity orbs that slow and pull nearby enemies.",
    price = 3100,
    module = { type = "turret" },
    icon = {
        size = 32,
        shapes = {
            { type = "rectangle", mode = "fill", color = {0.07, 0.08, 0.12, 1}, x = 8, y = 11, w = 18, h = 15, rx = 3 },
            { type = "circle", mode = "fill", color = {0.12, 0.20, 0.32, 1}, x = 16, y = 18, r = 5 },
            { type = "circle", mode = "fill", color = {0.45, 0.30, 0.95, 0.9}, x = 16, y = 9, r = 4 },
            { type = "polygon", mode = "line", color = {0.65, 0.55, 1.00, 0.8}, points = {13, 6, 16, 2, 19, 6}, lineWidth = 1.2 },
        }
    },
    spread = { minDeg = 0.5, maxDeg = 1.8, decay = 600 },
    
    -- Embedded projectile definition with gravity effects
    projectile = {
        id = "graviton_orb",
        name = "Graviton Orb",
        class = "Projectile",
        physics = {
            speed = 2600,
            drag = 0.04,
        },
        renderable = {
            type = "bullet",
            props = {
                kind = "orb",
                radius = 3.0,
                color = {0.65, 0.55, 1.00, 0.9},
            }
        },
        damage = {
            value = 3.8,
            gravityWell = { radius = 180, force = 140, duration = 2.5 },
        },
        timed_life = {
            duration = 3.2,
        }
    },
    
    -- Visual effects
    tracer = { color = {0.65, 0.55, 1.00, 0.9}, width = 2.2, coreRadius = 2.8 },
    impact = {
        shield = { spanDeg = 85, color1 = {0.65, 0.55, 1.0, 0.65}, color2 = {0.45, 0.40, 1.0, 0.45} },
        hull = { spark = {0.75, 0.65, 1.0, 0.55}, ring = {0.45, 0.40, 1.0, 0.4} },
    },
    optimal = 800,
    falloff = 900,
    damage_range = { min = 3, max = 4 },
    cycle = 2.2,
    capCost = 4.2,
    projectileSpeed = 2600,
    maxRange = 1700,
    gravityWell = { radius = 180, force = 140, duration = 2.5 },
    maxHeat = 95,
    heatPerShot = 14,
    cooldownRate = 18,
    overheatCooldown = 4.8,
    heatCycleMult = 0.6,
    heatEnergyMult = 1.3,
    fireMode = "manual"
}
