return {
    id = "low_power_laser",
    type = "laser",
    name = "Low Power Laser",
    description = "Lightweight energy weapon with low power consumption.",
    price = 600,
    volume = 4,
    module = { type = "turret" },
    icon = {
        size = 32,
        shapes = {
            -- Main chassis
            { type = "polygon", mode = "fill", color = {0.10, 0.12, 0.16, 1}, points = {8, 26, 12, 12, 20, 12, 24, 26, 16, 28} },
            { type = "polygon", mode = "fill", color = {0.18, 0.22, 0.28, 1}, points = {10, 22, 14, 16, 18, 16, 22, 22, 16, 24} },
            -- Energy focuser
            { type = "rectangle", mode = "fill", color = {0.05, 0.35, 0.60, 1}, x = 13, y = 16, w = 6, h = 2, rx = 1 },
            { type = "rectangle", mode = "fill", color = {0.05, 0.45, 0.75, 0.9}, x = 14, y = 18, w = 4, h = 1, rx = 1 },
            -- Laser emitter
            { type = "circle", mode = "fill", color = {0.06, 0.20, 0.40, 1}, x = 16, y = 10, r = 3 },
            { type = "circle", mode = "fill", color = {0.15, 0.60, 0.90, 0.95}, x = 16, y = 10, r = 2 },
            { type = "circle", mode = "fill", color = {0.60, 0.90, 1.00, 0.8}, x = 16, y = 10, r = 1 },
            -- Power cells
            { type = "rectangle", mode = "fill", color = {0.20, 0.30, 0.40, 1}, x = 9, y = 14, w = 3, h = 6, rx = 1 },
            { type = "rectangle", mode = "fill", color = {0.20, 0.30, 0.40, 1}, x = 20, y = 14, w = 3, h = 6, rx = 1 },
        }
    },
    
    -- Embedded projectile definition
    projectile = {
        id = "low_power_laser_beam",
        name = "Low Power Laser Beam",
        class = "Projectile",
        physics = {
            speed = 0, -- Hitscan
            drag = 0,
        },
        renderable = {
            type = "bullet",
            props = {
                kind = "laser",
                length = 600,
                tracerWidth = 1.2,
                color = {0.3, 0.7, 1.0, 0.5},
            }
        },
        collidable = {
            shape = "polygon",
            vertices = {
                -2, -1,  -- Top-left
                -1, -2,  -- Left
                1, -2,   -- Left
                2, -1,   -- Top-right
                2, 1,    -- Right
                1, 2,    -- Bottom-right
                -1, 2,   -- Bottom-left
                -2, 1,   -- Bottom-left
            }
        },
        damage = {
            value = 15.0,
        },
        timed_life = {
            duration = 0.12,
        },
        charged_pulse = {
            buildup_time = 0.05,
            flash_time = 0.06,
        }
    },
    
    -- Visual effects
    tracer = { color = {0.3, 0.7, 1.0, 0.4}, width = 1.2, coreRadius = 0.6 },
    impact = {
        shield = { spanDeg = 50, color1 = {0.3, 0.7, 1.0, 0.5}, color2 = {0.2, 0.5, 0.8, 0.3} },
        hull = { spark = {0.3, 0.7, 1.0, 0.7}, ring = {0.2, 0.5, 0.8, 0.5} },
    },
    
    -- Weapon stats
    optimal = 500, falloff = 200,
    damage_range = { min = 12, max = 18 },
    damagePerSecond = 15,
    cycle = 1.5, capCost = 0,
    energyPerSecond = 15,
    maxRange = 800,
    spread = { minDeg = 0.0, maxDeg = 0.0, decay = 600 },
    
    -- Volley firing (single shot by default)
    volleyCount = 1,
    volleySpreadDeg = 0,
    
    -- Overheating parameters
    maxHeat = 60,
    heatPerShot = 20,
    cooldownRate = 15,
    overheatCooldown = 2.0,
    heatCycleMult = 0.7,
    heatEnergyMult = 1.2,
    
    -- Firing mode
    fireMode = "manual"
}
