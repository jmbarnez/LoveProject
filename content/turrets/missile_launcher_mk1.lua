return {
    id = "missile_launcher_mk1",
    type = "missile",
    name = "Missile Launcher MK1",
    description = "Basic missile launcher with moderate range and damage.",
    price = 2500,
    volume = 10,
    module = { type = "turret" },
    icon = {
        size = 32,
        shapes = {
            -- Main launcher chassis
            { type = "polygon", mode = "fill", color = {0.08, 0.10, 0.14, 1}, points = {6, 28, 10, 8, 22, 8, 26, 28, 16, 32} },
            { type = "polygon", mode = "fill", color = {0.16, 0.20, 0.26, 1}, points = {8, 24, 12, 12, 20, 12, 24, 24, 16, 28} },
            -- Launch tube
            { type = "rectangle", mode = "fill", color = {0.18, 0.32, 0.48, 1}, x = 12, y = 12, w = 8, h = 10, rx = 1 },
            { type = "rectangle", mode = "fill", color = {0.25, 0.40, 0.55, 1}, x = 13, y = 13, w = 6, h = 8, rx = 0.5 },
            -- Missile nose
            { type = "polygon", mode = "fill", color = {0.80, 0.30, 0.20, 1}, points = {16, 6, 19, 10, 13, 10} },
            { type = "polygon", mode = "fill", color = {0.95, 0.50, 0.25, 0.9}, points = {16, 7, 18, 9, 14, 9} },
            -- Fins
            { type = "polygon", mode = "fill", color = {0.65, 0.70, 0.75, 1}, points = {13, 10, 11, 14, 15, 14} },
            { type = "polygon", mode = "fill", color = {0.65, 0.70, 0.75, 1}, points = {19, 10, 17, 14, 21, 14} },
            -- Exhaust
            { type = "polygon", mode = "fill", color = {1.00, 0.65, 0.20, 0.8}, points = {14, 14, 18, 14, 20, 22, 12, 22} },
            { type = "polygon", mode = "fill", color = {1.00, 0.40, 0.10, 0.7}, points = {14, 16, 18, 16, 18, 22, 14, 22} },
            -- Targeting array
            { type = "rectangle", mode = "fill", color = {0.30, 0.50, 0.70, 1}, x = 10, y = 16, w = 2, h = 4, rx = 1 },
            { type = "rectangle", mode = "fill", color = {0.30, 0.50, 0.70, 1}, x = 20, y = 16, w = 2, h = 4, rx = 1 },
        }
    },
    
    -- Embedded projectile definition
    projectile = {
        id = "missile_mk1",
        name = "Missile MK1",
        class = "Projectile",
        physics = {
            speed = 800,
            drag = 0.03,
            acceleration = 150,
        },
        renderable = {
            type = "bullet",
            props = {
                kind = "rocket",
                radius = 4,
                length = 20,
                color = {1.0, 0.3, 0.1, 1.0}
            }
        },
        collidable = {
            shape = "polygon",
            vertices = {
                -3, -2,  -- Top-left
                -2, -3,  -- Left
                2, -3,   -- Left
                3, -2,   -- Top-right
                3, 2,    -- Right
                2, 3,    -- Bottom-right
                -2, 3,   -- Bottom-left
                -3, 2,   -- Bottom-left
            }
        },
        damage = {
            value = 35.0,
        },
        timed_life = {
            duration = 4.0,
        },
        explosion = {
            radius = 40,
            damage = 25
        }
    },
    
    -- Visual effects
    tracer = { color = {1.0, 0.3, 0.1, 1.0}, width = 2, coreRadius = 3 },
    impact = {
        shield = { spanDeg = 80, color1 = {1.0, 0.5, 0.2, 0.6}, color2 = {1.0, 0.3, 0.1, 0.4} },
        hull = { spark = {1.0, 0.4, 0.1, 0.8}, ring = {1.0, 0.2, 0.0, 0.6} },
    },
    
    -- Weapon stats
    optimal = 1200, falloff = 1800,
    damage_range = { min = 30, max = 40 },
    cycle = 4.0, capCost = 6,
    maxRange = 2500,
    spread = { minDeg = 1.0, maxDeg = 2.5, decay = 400 },
    
    -- Targeting and guidance
    -- Lock settings: how precisely to aim and how long to hold before lock
    lockOnAngleTolerance = 0.26, -- ~15 degrees in radians
    lockOnDuration = 0.9,        -- seconds to acquire lock when aimed at target
    -- Guidance: missile turn rate (radians/second)
    missileTurnRate = 4.19,      -- ~240 deg/sec
    
    -- Volley firing (single shot by default)
    volleyCount = 1,
    volleySpreadDeg = 0,
    
    -- Overheating parameters
    maxHeat = 80,
    heatPerShot = 50,
    cooldownRate = 8,
    overheatCooldown = 4.0,
    heatCycleMult = 0.7,
    heatEnergyMult = 1.3,
    
    -- Firing mode
    fireMode = "manual"
}
