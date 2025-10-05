return {
    id = "missile_launcher",
    type = "missile",
    name = "Missile Launcher",
    description = "Heavy rocket launcher with high damage and long range.",
    price = 3000,
    volume = 8,
    module = { type = "turret" },
    icon = {
        size = 32,
        shapes = {
            -- Main launcher chassis
            { type = "polygon", mode = "fill", color = {0.10, 0.12, 0.18, 1}, points = {5, 26, 8, 10, 24, 10, 27, 26, 16, 30} },
            { type = "polygon", mode = "fill", color = {0.18, 0.22, 0.30, 1}, points = {8, 22, 10, 14, 22, 14, 24, 22, 16, 26} },
            -- Launch tubes
            { type = "rectangle", mode = "fill", color = {0.20, 0.36, 0.52, 1}, x = 9, y = 14, w = 6, h = 8, rx = 1 },
            { type = "rectangle", mode = "fill", color = {0.20, 0.36, 0.52, 1}, x = 17, y = 14, w = 6, h = 8, rx = 1 },
            -- Rocket nose
            { type = "polygon", mode = "fill", color = {0.85, 0.32, 0.25, 1}, points = {16, 4, 20, 12, 12, 12} },
            { type = "polygon", mode = "fill", color = {1.00, 0.52, 0.30, 0.9}, points = {16, 5, 19, 11, 13, 11} },
            -- Fins
            { type = "polygon", mode = "fill", color = {0.70, 0.76, 0.82, 1}, points = {12, 12, 10, 16, 14, 16} },
            { type = "polygon", mode = "fill", color = {0.70, 0.76, 0.82, 1}, points = {20, 12, 18, 16, 22, 16} },
            -- Exhaust
            { type = "polygon", mode = "fill", color = {1.00, 0.70, 0.25, 0.85}, points = {14, 16, 18, 16, 21, 24, 11, 24} },
            { type = "polygon", mode = "fill", color = {1.00, 0.45, 0.15, 0.8}, points = {14, 18, 18, 18, 19, 24, 13, 24} },
        }
    },
    
    -- Embedded projectile definition
    projectile = {
        id = "missile_rocket",
        name = "Heavy Rocket",
        class = "Projectile",
        physics = {
            speed = 1200,
            drag = 0.02,
            acceleration = 200,
        },
        renderable = {
            type = "bullet",
            props = {
                kind = "rocket",
                radius = 5,
                length = 25,
                color = {1.0, 0.4, 0.1, 1.0}
            }
        },
        damage = {
            value = 15.0,
        },
        timed_life = {
            duration = 5.0,
        },
        explosion = {
            radius = 60,
            damage = 20
        }
    },
    
    -- Visual effects
    tracer = { color = {1.0, 0.4, 0.1, 1.0}, width = 3, coreRadius = 4 },
    impact = {
        shield = { spanDeg = 90, color1 = {1.0, 0.6, 0.2, 0.7}, color2 = {1.0, 0.4, 0.1, 0.5} },
        hull = { spark = {1.0, 0.5, 0.1, 0.8}, ring = {1.0, 0.3, 0.0, 0.6} },
    },
    
    -- Weapon stats
    optimal = 1500, falloff = 2500,
    damage_range = { min = 10, max = 20 },
    cycle = 6.0, capCost = 8,
    maxRange = 3000,
    spread = { minDeg = 1.2, maxDeg = 3.5, decay = 300 },
    
    -- Volley firing (single shot by default)
    volleyCount = 1,
    volleySpreadDeg = 0,
    
    -- Overheating parameters
    maxHeat = 60,
    heatPerShot = 75,
    cooldownRate = 6,
    overheatCooldown = 5.0,
    heatCycleMult = 0.6,
    heatEnergyMult = 1.4,
    
    -- Firing mode
    fireMode = "manual"
}
