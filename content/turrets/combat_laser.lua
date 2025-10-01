return {
    id = "combat_laser",
    type = "laser",
    name = "Combat Laser",
    description = "Military-grade energy beam for close to mid-range combat.",
    price = 900,
    module = { type = "turret" },
    icon = {
        size = 32,
        shapes = {
            -- Main chassis
            { type = "polygon", mode = "fill", color = {0.09, 0.12, 0.18, 1}, points = {6, 24, 10, 10, 22, 10, 26, 24, 16, 30} },
            { type = "polygon", mode = "fill", color = {0.18, 0.26, 0.36, 1}, points = {8, 20, 12, 13, 20, 13, 24, 20, 16, 26} },
            -- Energy focuser
            { type = "rectangle", mode = "fill", color = {0.05, 0.45, 0.70, 1}, x = 11, y = 14, w = 10, h = 3, rx = 1 },
            { type = "rectangle", mode = "fill", color = {0.05, 0.55, 0.85, 0.9}, x = 12, y = 18, w = 8, h = 2, rx = 1 },
            -- Laser emitter
            { type = "circle", mode = "fill", color = {0.08, 0.25, 0.45, 1}, x = 16, y = 8, r = 5 },
            { type = "circle", mode = "fill", color = {0.20, 0.75, 1.00, 0.95}, x = 16, y = 8, r = 3.2 },
            { type = "circle", mode = "fill", color = {0.70, 1.00, 1.00, 0.8}, x = 16, y = 8, r = 1.6 },
        }
    },
    
    -- Embedded projectile definition
    projectile = {
        id = "combat_laser_beam",
        name = "Combat Laser Beam",
        class = "Projectile",
        physics = {
            speed = 0, -- Hitscan
            drag = 0,
        },
        renderable = {
            type = "bullet",
            props = {
                kind = "laser",
                length = 900,
                tracerWidth = 4,
                color = {0.4, 0.85, 1.0, 0.95},
            }
        },
        collidable = {
            radius = 3,
        },
        damage = {
            value = 2.5,
        },
        timed_life = {
            duration = 0.16,
        },
        charged_pulse = {
            buildup_time = 0.1,
            flash_time = 0.08,
        }
    },
    
    -- Visual effects
    tracer = { color = {0.4, 0.85, 1.0, 0.9}, width = 3, coreRadius = 2 },
    impact = {
        shield = { spanDeg = 70, color1 = {0.4, 0.85, 1.0, 0.6}, color2 = {0.2, 0.6, 1.0, 0.4} },
        hull = { spark = {0.4, 0.85, 1.0, 0.8}, ring = {0.2, 0.6, 1.0, 0.6} },
    },
    
    -- Weapon stats
    optimal = 800, falloff = 400,
    damage_range = { min = 2, max = 3 },
    cycle = 2.0, capCost = 3,
    maxRange = 1200,
    spread = { minDeg = 0.0, maxDeg = 0.0, decay = 900 },
    
    -- Volley firing (single shot by default)
    volleyCount = 1,
    volleySpreadDeg = 0,
    
    -- Overheating parameters
    maxHeat = 80,
    heatPerShot = 60,
    cooldownRate = 9,
    overheatCooldown = 4.0,
    heatCycleMult = 0.6,
    heatEnergyMult = 1.4,
    
    -- Firing mode
    fireMode = "manual"
}