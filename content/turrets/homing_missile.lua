return {
    id = "homing_missile",
    type = "missile",
    name = "Homing Missile",
    description = "Agile missiles that relentlessly track their target.",
    price = 3000,
    volume = 14,
    module = { type = "turret" },
    icon = {
        size = 32,
        shapes = {
            -- Main chassis - missile launcher
            { type = "polygon", mode = "fill", color = {0.10, 0.12, 0.08, 1}, points = {4, 28, 8, 6, 24, 6, 28, 28, 16, 32} },
            { type = "polygon", mode = "fill", color = {0.24, 0.28, 0.22, 1}, points = {6, 24, 10, 10, 22, 10, 26, 24, 16, 28} },
            
            -- Missile tube
            { type = "rectangle", mode = "fill", color = {0.15, 0.18, 0.12, 1}, x = 14, y = 6, w = 4, h = 16, rx = 1 },
            { type = "rectangle", mode = "fill", color = {0.35, 0.42, 0.28, 0.8}, x = 15, y = 7, w = 2, h = 14, rx = 0.5 },
            
            -- Missile nose cone
            { type = "polygon", mode = "fill", color = {0.60, 0.70, 0.50, 1}, points = {14, 6, 18, 6, 16, 2} },
            { type = "polygon", mode = "fill", color = {0.80, 0.90, 0.70, 0.9}, points = {15, 6, 17, 6, 16, 3} },
            
            -- Guidance fins
            { type = "polygon", mode = "fill", color = {0.40, 0.50, 0.35, 1}, points = {12, 12, 14, 10, 14, 14} },
            { type = "polygon", mode = "fill", color = {0.40, 0.50, 0.35, 1}, points = {18, 10, 20, 12, 18, 14} },
            { type = "polygon", mode = "fill", color = {0.40, 0.50, 0.35, 1}, points = {15, 18, 17, 18, 16, 20} },
            
            -- Targeting array
            { type = "circle", mode = "fill", color = {0.20, 0.80, 0.40, 0.9}, x = 10, y = 16, r = 2 },
            { type = "circle", mode = "fill", color = {0.20, 0.80, 0.40, 0.9}, x = 22, y = 16, r = 2 },
        }
    },

    projectile = {
        id = "homing_missile_round",
        class = "Projectile",
        physics = { speed = 1500 },
        renderable = { renderer = "homing_missile", props = { radius = 5 } },
        damage = { value = 28 },
        collidable = { radius = 5 },
        timed_life = { duration = 4.5 },
        behaviors = {
            { type = "homing", turnRate = math.rad(220), range = 2400, speed = 1500 }
        },
        effects = {
            { type = "dynamic_light", radius = 24, color = {0.6, 0.85, 1.0, 0.8} },
            { type = "particle_emitter", type = "spark", interval = 0.04, speed = 160, color = {0.6, 0.85, 1.0, 0.7} }
        }
    },

    tracer = { color = {0.6, 0.85, 1.0, 1.0}, width = 2.4, coreRadius = 4 },
    impact = {
        shield = { spanDeg = 100, color1 = {0.6, 0.9, 1.0, 0.5}, color2 = {0.5, 0.8, 1.0, 0.35} },
        hull = { spark = {0.5, 0.8, 1.0, 0.8}, ring = {0.3, 0.7, 1.0, 0.45} }
    },

    optimal = 1700, falloff = 2700,
    damage_range = { min = 24, max = 34 },
    cycle = 4.0, capCost = 9,
    maxRange = 3400,

    modifiers = {
        { type = "precision_barrel" },
        { type = "capacitor_bank" }
    },

    upgrades = {
        thresholds = { 200, 460, 920 },
        bonuses = {
            [1] = { homingBonus = math.rad(40) },
            [2] = { damageMultiplier = 1.08 },
            [3] = { cycleMultiplier = 0.88 },
        }
    },
    -- Firing mode
    fireMode = "manual"
}
