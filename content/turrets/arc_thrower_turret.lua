return {
    id = "arc_thrower_turret",
    type = "laser",
    name = "Arc Thrower",
    description = "Voltage projector that hurls chaining arcs of electricity across clustered foes.",
    price = 2600,
    module = { type = "turret" },
    icon = {
        size = 32,
        shapes = {
            { type = "rectangle", mode = "fill", color = {0.05, 0.08, 0.12, 1}, x = 9, y = 12, w = 16, h = 14, rx = 3 },
            { type = "circle", mode = "fill", color = {0.10, 0.20, 0.35, 1}, x = 16, y = 18, r = 4 },
            { type = "polygon", mode = "fill", color = {0.55, 0.95, 1.00, 0.9}, points = {12, 8, 20, 8, 18, 4, 14, 4} },
            { type = "polygon", mode = "line", color = {0.35, 0.85, 1.00, 0.85}, points = {13, 6, 16, 2, 19, 6}, lineWidth = 1.2 },
        }
    },
    spread = { minDeg = 0.0, maxDeg = 0.1, decay = 1000 },
    
    -- Embedded projectile definition with chaining effects
    projectile = {
        id = "arc_dart",
        name = "Arc Dart",
        class = "Projectile",
        physics = {
            speed = 4800,
            drag = 0.03,
        },
        renderable = {
            type = "bullet",
            props = {
                kind = "spark",
                radius = 2.0,
                color = {0.55, 0.95, 1.00, 0.9},
            }
        },
        damage = {
            value = 3.8,
            chainChance = 0.6,
            chainRange = 280,
            maxChains = 4,
            chainDamageFalloff = 0.7,
        },
        timed_life = {
            duration = 2.5,
        }
    },
    
    -- Visual effects
    tracer = { color = {0.55, 0.95, 1.00, 0.9}, width = 1.8, coreRadius = 1.2 },
    impact = {
        shield = { spanDeg = 90, color1 = {0.55, 0.95, 1.0, 0.7}, color2 = {0.35, 0.75, 1.0, 0.45} },
        hull = { spark = {0.75, 0.95, 1.0, 0.6}, ring = {0.40, 0.70, 1.0, 0.45} },
    },
    optimal = 950,
    falloff = 650,
    damage_range = { min = 3, max = 4.5 },
    cycle = 0.9,
    capCost = 4,
    projectileSpeed = 4800,
    maxRange = 1600,
    chainChance = 0.6,
    chainRange = 280,
    maxChains = 4,
    chainDamageFalloff = 0.7,
    maxHeat = 110,
    heatPerShot = 12,
    cooldownRate = 26,
    overheatCooldown = 4.5,
    heatCycleMult = 0.65,
    heatEnergyMult = 1.25,
    fireMode = "automatic"
}
