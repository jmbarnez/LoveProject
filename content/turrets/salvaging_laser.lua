return {
    id = "salvaging_laser",
    type = "salvaging_laser",
    name = "Salvaging Laser",
    description = "Precision laser for extracting materials from wreckage.",
    price = 1500,
    volume = 8,
    module = { type = "turret" },
    icon = {
        size = 32,
        shapes = {
            -- Main chassis
            { type = "polygon", mode = "fill", color = {0.08, 0.15, 0.10, 1}, points = {6, 24, 10, 10, 22, 10, 26, 24, 16, 30} },
            { type = "polygon", mode = "fill", color = {0.15, 0.25, 0.18, 1}, points = {8, 20, 12, 13, 20, 13, 24, 20, 16, 26} },
            -- Salvaging focuser
            { type = "rectangle", mode = "fill", color = {0.2, 1.0, 0.3, 1}, x = 11, y = 14, w = 10, h = 3, rx = 1 },
            { type = "rectangle", mode = "fill", color = {0.3, 1.0, 0.4, 0.9}, x = 12, y = 18, w = 8, h = 2, rx = 1 },
            -- Laser emitter
            { type = "circle", mode = "fill", color = {0.1, 0.6, 0.2, 1}, x = 16, y = 8, r = 5 },
            { type = "circle", mode = "fill", color = {0.2, 1.0, 0.3, 0.95}, x = 16, y = 8, r = 3.2 },
            { type = "circle", mode = "fill", color = {0.4, 1.0, 0.6, 0.8}, x = 16, y = 8, r = 1.6 },
        }
    },
    
    -- Embedded projectile definition
    projectile = {
        id = "salvaging_laser_beam",
        name = "Salvaging Laser Beam",
        class = "Projectile",
        physics = {
            speed = 0, -- Hitscan
            drag = 0,
        },
        renderable = {
            type = "bullet",
            props = {
                kind = "salvaging_laser",
                length = 1000,
                tracerWidth = 6,
                color = {0.2, 1.0, 0.3, 0.8},
            }
        },
        collidable = {
            shape = "polygon",
            vertices = {
                -4, -2,  -- Top-left
                -2, -4,  -- Left
                2, -4,   -- Left
                4, -2,   -- Top-right
                4, 2,    -- Right
                2, 4,    -- Bottom-right
                -2, 4,   -- Bottom-left
                -4, 2,   -- Bottom-left
            }
        },
        damage = {
            value = 1.5,
        },
        timed_life = {
            duration = 0.08,
        },
        charged_pulse = {
            buildup_time = 0.05,
            flash_time = 0.06,
        }
    },
    
    -- Visual effects
    tracer = { color = {0.2, 1.0, 0.3, 0.8}, width = 5, coreRadius = 4 },
    impact = {
        shield = { spanDeg = 90, color1 = {0.2, 1.0, 0.3, 0.6}, color2 = {0.1, 0.8, 0.2, 0.4} },
        hull = { spark = {0.3, 1.0, 0.5, 0.8}, ring = {0.1, 0.8, 0.2, 0.6} },
    },
    
    -- Weapon stats
    optimal = 800, falloff = 400,
    damage_range = { min = 1, max = 2 },
    cycle = 2.0, capCost = 0, -- No per-shot energy cost
    energyPerSecond = 50, -- Energy consumed per second while beam is active
    maxRange = 1200,
    spread = { minDeg = 0.0, maxDeg = 0.0, decay = 900 },
    
    -- Volley firing (single shot by default)
    volleyCount = 1,
    volleySpreadDeg = 0,
    
    -- Salvaging parameters
    salvagePower = 3.0,
    beamDuration = 0.08,
    
    -- Firing mode
    fireMode = "manual",
    
    -- Level properties
    level = 1,
    maxLevel = 5
}