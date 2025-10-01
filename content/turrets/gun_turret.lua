return {
    id = "gun_turret",
    type = "gun",
    name = "Gun Turret",
    description = "Standard projectile turret with moderate range and damage.",
    price = 500,
    module = { type = "turret" },
    icon = {
        size = 32,
        shapes = {
            -- Main chassis
            { type = "polygon", mode = "fill", color = {0.10, 0.14, 0.20, 1}, points = {4, 12, 8, 6, 24, 6, 28, 12, 24, 20, 8, 20} },
            { type = "polygon", mode = "fill", color = {0.22, 0.30, 0.38, 1}, points = {6, 13, 10, 9, 22, 9, 26, 13, 22, 19, 10, 19} },
            -- Rail system
            { type = "rectangle", mode = "fill", color = {0.00, 0.65, 0.95, 0.85}, x = 9, y = 12, w = 14, h = 3, rx = 1 },
            { type = "rectangle", mode = "fill", color = {0.00, 0.65, 0.95, 0.7}, x = 9, y = 18, w = 14, h = 2, rx = 1 },
            -- Barrel
            { type = "rectangle", mode = "fill", color = {0.55, 0.80, 1.00, 1}, x = 14, y = 6, w = 4, h = 13, rx = 1 },
            { type = "circle", mode = "fill", color = {0.95, 0.98, 1.00, 0.9}, x = 16, y = 6, r = 3 },
            -- Targeting lights
            { type = "circle", mode = "fill", color = {0.00, 0.85, 1.00, 0.85}, x = 11, y = 15, r = 1.2 },
            { type = "circle", mode = "fill", color = {0.00, 0.85, 1.00, 0.85}, x = 21, y = 15, r = 1.2 },
        }
    },
    
    -- Embedded projectile definition
    projectile = {
        id = "gun_bullet",
        name = "Kinetic Slug",
        class = "Projectile",
        physics = {
            speed = 2400,
            drag = 0,
        },
        renderable = {
            type = "bullet",
            props = {
                kind = "bullet",
                radius = 3,
                color = {0.35, 0.70, 1.00, 1.0},
            }
        },
        damage = {
            value = 1.5,
        },
        timed_life = {
            duration = 2.5,
        }
    },
    
    -- Visual effects
    tracer = { color = {0.35, 0.70, 1.00, 1.0}, width = 2, coreRadius = 3 },
    impact = {
        shield = { spanDeg = 70, color1 = {0.26, 0.62, 1.0, 0.55}, color2 = {0.50, 0.80, 1.0, 0.35} },
        hull = { spark = {1.0, 0.6, 0.1, 0.6}, ring = {1.0, 0.3, 0.0, 0.4} },
    },
    
    -- Weapon stats
    optimal = 800, falloff = 600,
    damage_range = { min = 1, max = 2 },
    cycle = 3.0, capCost = 2,
    maxRange = 2000,
    spread = { minDeg = 0.15, maxDeg = 1.2, decay = 600 },
    
    -- Overheating parameters
    maxHeat = 100,
    heatPerShot = 10,
    cooldownRate = 15,
    overheatCooldown = 5.0,
    heatCycleMult = 0.7,
    heatEnergyMult = 1.3,
    
    -- Firing mode
    fireMode = "manual"
}
