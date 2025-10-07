return {
    id = "kinetic_turret",
    type = "gun",
    name = "Shrapnel Bomb Launcher",
    description = "Launches explosive bombs that detonate at target location, releasing a deadly cone of shrapnel.",
    price = 1500,
    volume = 8,
    module = { type = "turret" },
    icon = {
        size = 32,
        shapes = {
            -- Main chassis
            { type = "polygon", mode = "fill", color = {0.15, 0.10, 0.20, 1}, points = {6, 24, 10, 8, 22, 8, 26, 24, 16, 28} },
            { type = "polygon", mode = "fill", color = {0.25, 0.20, 0.30, 1}, points = {8, 20, 12, 12, 20, 12, 24, 20, 16, 24} },
            -- Force emitter array
            { type = "rectangle", mode = "fill", color = {0.30, 0.25, 0.40, 1}, x = 10, y = 6, w = 12, h = 8, rx = 2 },
            { type = "rectangle", mode = "fill", color = {0.40, 0.35, 0.50, 1}, x = 12, y = 8, w = 8, h = 4, rx = 1 },
            -- Force field generator
            { type = "circle", mode = "fill", color = {0.20, 0.15, 0.25, 1}, x = 16, y = 4, r = 3 },
            { type = "circle", mode = "fill", color = {0.35, 0.30, 0.45, 1}, x = 16, y = 4, r = 1.5 },
            -- Energy conduits
            { type = "rectangle", mode = "fill", color = {0.35, 0.30, 0.45, 1}, x = 8, y = 14, w = 16, h = 4, rx = 1 },
            { type = "rectangle", mode = "fill", color = {0.45, 0.40, 0.55, 1}, x = 10, y = 15, w = 12, h = 2, rx = 0.5 },
            -- Power vents
            { type = "rectangle", mode = "fill", color = {0.25, 0.20, 0.35, 1}, x = 6, y = 10, w = 2, h = 8, rx = 1 },
            { type = "rectangle", mode = "fill", color = {0.25, 0.20, 0.35, 1}, x = 24, y = 10, w = 2, h = 8, rx = 1 },
        }
    },
    
    -- Embedded projectile definition
    projectile = {
        id = "shrapnel_bomb",
        name = "Shrapnel Bomb",
        class = "Projectile",
        physics = {
            speed = 800,
            drag = 0.02,
        },
        renderable = {
            type = "bullet",
            props = {
                kind = "fragmentation",
                radius = 6,
                color = {0.8, 0.2, 0.2, 1.0},
                streak = {
                    length = 20,
                    width = 3,
                    color = {1.0, 0.3, 0.3, 0.8}
                }
            }
        },
        collidable = {
            radius = 6,
        },
        damage = {
            value = 0.0, -- Bomb itself doesn't damage, only explosion does
        },
        timed_life = {
            duration = 3.0,
        },
        -- Bomb explosion component
        components = {
            {
                name = "bomb_explosion",
                value = {
                    explosion_radius = 80,
                    shrapnel_count = 12,
                    shrapnel_spread = math.pi * 0.6, -- 108 degree cone
                    shrapnel_speed = 600,
                    shrapnel_damage = 8,
                    explosion_damage = 25,
                    explosion_delay = 999.0, -- Large delay - will explode when reaching target
                }
            }
        }
    },

    -- Visual effects
    tracer = { color = {0.8, 0.2, 0.2, 0.8}, width = 3, coreRadius = 6 },
    impact = {
        shield = { spanDeg = 90, color1 = {1.0, 0.3, 0.3, 0.8}, color2 = {0.8, 0.1, 0.1, 0.6} },
        hull = { spark = {1.0, 0.4, 0.2, 1.0}, ring = {0.9, 0.2, 0.1, 0.8} },
    },

    -- Weapon stats
    optimal = 400, falloff = 200,
    damage_range = { min = 20, max = 30 }, -- Total damage from explosion + shrapnel
    damagePerSecond = 15,
    cycle = 2.5, capCost = 5,
    energyPerSecond = 6,
    maxRange = 600,
    spread = { minDeg = 0.5, maxDeg = 1.5, decay = 200 },
    
    -- Volley firing (single shot by default)
    volleyCount = 1,
    volleySpreadDeg = 0,
    
    -- Overheating parameters
    maxHeat = 120,
    heatPerShot = 20,
    cooldownRate = 8,
    overheatCooldown = 4.0,
    heatCycleMult = 0.9,
    heatEnergyMult = 1.2,
    
    -- Firing mode
    fireMode = "manual"
}
