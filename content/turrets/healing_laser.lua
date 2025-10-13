return {
    id = "healing_laser",
    type = "healing_laser",
    name = "Healing Laser",
    description = "Medical laser that heals allied ships and repairs damage.",
    price = 2000,
    volume = 10,
    module = { type = "turret" },
    icon = {
        size = 32,
        shapes = {
            -- Main chassis
            { type = "polygon", mode = "fill", color = {0.1, 0.3, 0.15, 1}, points = {6, 24, 10, 10, 22, 10, 26, 24, 16, 30} },
            { type = "polygon", mode = "fill", color = {0.15, 0.4, 0.2, 1}, points = {8, 20, 12, 13, 20, 13, 24, 20, 16, 26} },
            -- Medical focuser
            { type = "rectangle", mode = "fill", color = {0.0, 1.0, 0.5, 1}, x = 11, y = 14, w = 10, h = 3, rx = 1 },
            { type = "rectangle", mode = "fill", color = {0.2, 1.0, 0.6, 0.9}, x = 12, y = 18, w = 8, h = 2, rx = 1 },
            -- Laser emitter
            { type = "circle", mode = "fill", color = {0.0, 0.6, 0.3, 1}, x = 16, y = 8, r = 5 },
            { type = "circle", mode = "fill", color = {0.0, 1.0, 0.5, 0.95}, x = 16, y = 8, r = 3.2 },
            { type = "circle", mode = "fill", color = {0.2, 1.0, 0.7, 0.8}, x = 16, y = 8, r = 1.6 },
            -- Medical cross symbol
            { type = "rectangle", mode = "fill", color = {0.9, 0.9, 0.9, 0.8}, x = 15, y = 6, w = 2, h = 4 },
            { type = "rectangle", mode = "fill", color = {0.9, 0.9, 0.9, 0.8}, x = 14, y = 7, w = 4, h = 2 },
        }
    },
    
    -- Embedded projectile definition
    projectile = {
        id = "healing_laser_beam",
        name = "Healing Laser Beam",
        class = "Projectile",
        physics = {
            speed = 0, -- Hitscan
            drag = 0,
        },
        renderable = {
            type = "bullet",
            props = {
                kind = "healing_laser",
                length = 1000,
                tracerWidth = 6,
                color = {0.0, 1.0, 0.5, 0.8}, -- Lime green
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
            value = -2.0, -- Negative damage = healing
        },
        timed_life = {
            duration = 0.1,
        },
        charged_pulse = {
            buildup_time = 0.05,
            flash_time = 0.08,
        }
    },
    
    -- Visual effects
    tracer = { color = {0.0, 1.0, 0.5, 0.8}, width = 5, coreRadius = 4 },
    impact = {
        shield = { spanDeg = 90, color1 = {0.0, 1.0, 0.5, 0.6}, color2 = {0.0, 0.8, 0.4, 0.4} },
        hull = { spark = {0.2, 1.0, 0.6, 0.8}, ring = {0.0, 0.8, 0.4, 0.6} },
    },
    
    -- Weapon stats
    optimal = 800, falloff = 400,
    damage_range = { min = -3, max = -1 }, -- Healing range
    cycle = 1.0, capCost = 0, -- No per-shot energy cost
    energyPerSecond = 0, -- No energy consumption (replaced by heat)
    maxRange = 1000,
    spread = { minDeg = 0.0, maxDeg = 0.0, decay = 900 },
    
    -- Heat system parameters
    maxHeat = 100,           -- Overheat threshold
    heatGeneration = 8,      -- Heat per second while firing (moderate for healing)
    coolingRate = 4,         -- Heat lost per second when not firing
    overheatPenalty = 8,     -- Seconds of forced cooldown when overheated
    
    -- Volley firing (single shot by default)
    volleyCount = 1,
    volleySpreadDeg = 0,
    
    -- Healing parameters
    healingPower = 2.0,
    beamDuration = 0.1,
    
    -- Firing mode
    fireMode = "manual",
    
    -- Level properties
    level = 1,
    maxLevel = 5
}
