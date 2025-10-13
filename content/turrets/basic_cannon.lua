return {
    id = "basic_cannon",
    type = "gun",
    name = "Basic Cannon",
    description = "Simple kinetic weapon firing solid projectiles at a steady rate.",
    price = 400,
    volume = 3,
    module = { type = "turret" },
    icon = {
        size = 32,
        shapes = {
            -- Main chassis
            { type = "polygon", mode = "fill", color = {0.15, 0.15, 0.15, 1}, points = {8, 26, 12, 12, 20, 12, 24, 26, 16, 28} },
            { type = "polygon", mode = "fill", color = {0.25, 0.25, 0.25, 1}, points = {10, 22, 14, 16, 18, 16, 22, 22, 16, 24} },
            -- Barrel
            { type = "rectangle", mode = "fill", color = {0.20, 0.20, 0.20, 1}, x = 14, y = 8, w = 4, h = 6, rx = 1 },
            { type = "rectangle", mode = "fill", color = {0.30, 0.30, 0.30, 1}, x = 15, y = 9, w = 2, h = 4, rx = 0.5 },
            -- Barrel tip
            { type = "circle", mode = "fill", color = {0.10, 0.10, 0.10, 1}, x = 16, y = 6, r = 1.5 },
            { type = "circle", mode = "fill", color = {0.20, 0.20, 0.20, 1}, x = 16, y = 6, r = 1 },
            -- Ammo feed
            { type = "rectangle", mode = "fill", color = {0.25, 0.25, 0.25, 1}, x = 12, y = 16, w = 8, h = 3, rx = 1 },
            { type = "rectangle", mode = "fill", color = {0.35, 0.35, 0.35, 1}, x = 13, y = 17, w = 6, h = 1, rx = 0.5 },
            -- Simple mounting
            { type = "rectangle", mode = "fill", color = {0.20, 0.20, 0.20, 1}, x = 6, y = 20, w = 4, h = 6, rx = 1 },
            { type = "rectangle", mode = "fill", color = {0.20, 0.20, 0.20, 1}, x = 22, y = 20, w = 4, h = 6, rx = 1 },
        }
    },
    
    -- Embedded projectile definition
    projectile = {
        id = "basic_cannon_round",
        name = "Basic Cannon Round",
        class = "Projectile",
        physics = {
            speed = 1200,
            drag = 0.02,
        },
        renderable = {
            type = "bullet",
            props = {
                kind = "bullet",
                radius = 4.5,
                length = 9,
                color = {1.0, 1.0, 0.0, 1.0}
            }
        },
        collidable = {
            shape = "polygon",
            vertices = {
                -4.5, -2.4,  -- Top-left
                -2.4, -4.5,  -- Left
                2.4, -4.5,   -- Left
                4.5, -2.4,   -- Top-right
                4.5, 2.4,    -- Right
                2.4, 4.5,    -- Bottom-right
                -2.4, 4.5,   -- Bottom-left
                -4.5, 2.4,   -- Bottom-left
            }
        },
        damage = {
            value = 12.0,
        },
        timed_life = {
            duration = 2.5,
        }
    },
    
    -- Visual effects
    tracer = { color = {1.0, 1.0, 0.0, 1.0}, width = 4.5, coreRadius = 6 },
    impact = {
        shield = { spanDeg = 45, color1 = {1.0, 1.0, 0.0, 0.6}, color2 = {0.8, 0.8, 0.0, 0.4} },
        hull = { spark = {1.0, 1.0, 0.0, 0.8}, ring = {0.8, 0.8, 0.0, 0.6} },
    },
    
    -- Weapon stats
    optimal = 400, falloff = 200,
    damage_range = { min = 10, max = 14 },
    damagePerSecond = 8,
    cycle = 1.5, capCost = 0, -- No energy cost (replaced by heat)
    energyPerSecond = 0,
    maxRange = 600,
    spread = { minDeg = 1.0, maxDeg = 2.0, decay = 300 },
    
    -- Volley firing (single shot by default)
    volleyCount = 1,
    volleySpreadDeg = 0,
    
    -- Heat system parameters
    maxHeat = 100,           -- Overheat threshold
    heatGeneration = 15,     -- Heat per shot (projectile weapons generate heat per shot)
    coolingRate = 5,         -- Heat lost per second when not firing
    overheatPenalty = 5,     -- Seconds of forced cooldown when overheated
    
    -- Firing mode
    fireMode = "manual",
    
    -- Level properties
    level = 1,
    maxLevel = 5
}
