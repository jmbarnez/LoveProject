return {
    id = "mining_laser",
    type = "mining_laser",
    name = "Mining Laser",
    description = "Industrial laser designed for extracting resources from asteroids.",
    price = 1200,
    volume = 8,
    module = { type = "turret" },
    icon = {
        size = 32,
        shapes = {
            -- Main chassis
            { type = "polygon", mode = "fill", color = {0.15, 0.12, 0.08, 1}, points = {6, 24, 10, 10, 22, 10, 26, 24, 16, 30} },
            { type = "polygon", mode = "fill", color = {0.25, 0.20, 0.15, 1}, points = {8, 20, 12, 13, 20, 13, 24, 20, 16, 26} },
            -- Mining focuser
            { type = "rectangle", mode = "fill", color = {0.8, 0.6, 0.2, 1}, x = 11, y = 14, w = 10, h = 3, rx = 1 },
            { type = "rectangle", mode = "fill", color = {1.0, 0.7, 0.2, 0.9}, x = 12, y = 18, w = 8, h = 2, rx = 1 },
            -- Laser emitter
            { type = "circle", mode = "fill", color = {0.6, 0.4, 0.1, 1}, x = 16, y = 8, r = 5 },
            { type = "circle", mode = "fill", color = {1.0, 0.7, 0.2, 0.95}, x = 16, y = 8, r = 3.2 },
            { type = "circle", mode = "fill", color = {1.0, 0.9, 0.4, 0.8}, x = 16, y = 8, r = 1.6 },
        }
    },
    
    -- Embedded projectile definition
    projectile = {
        id = "mining_laser_beam",
        name = "Mining Laser Beam",
        class = "Projectile",
        physics = {
            speed = 0, -- Hitscan
            drag = 0,
        },
        renderable = {
            type = "bullet",
            props = {
                kind = "mining_laser",
                length = 1200,
                tracerWidth = 5,
                color = {1.0, 0.7, 0.2, 0.8},
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
    tracer = { color = {1.0, 0.7, 0.2, 0.8}, width = 4, coreRadius = 3 },
    impact = {
        shield = { spanDeg = 80, color1 = {1.0, 0.7, 0.2, 0.6}, color2 = {0.8, 0.5, 0.1, 0.4} },
        hull = { spark = {1.0, 0.8, 0.3, 0.8}, ring = {0.8, 0.6, 0.1, 0.6} },
    },
    
    -- Weapon stats
    optimal = 1000, falloff = 500,
    damage_range = { min = 1, max = 2 },
    cycle = 1.5, capCost = 0, -- No per-shot energy cost
    energyPerSecond = 40, -- Energy consumed per second while beam is active
    maxRange = 1500,
    spread = { minDeg = 0.0, maxDeg = 0.0, decay = 900 },
    
    -- Volley firing (single shot by default)
    volleyCount = 1,
    volleySpreadDeg = 0,
    
    -- Mining parameters
    miningPower = 2.5,
    miningCyclesPerResource = 4,
    beamDuration = 0.08,
    
    -- Overheating parameters
    maxHeat = 120,
    heatPerShot = 40,
    cooldownRate = 10,
    overheatCooldown = 3.0,
    heatCycleMult = 0.8,
    heatEnergyMult = 1.2,
    
    -- Firing mode
    fireMode = "manual"
}