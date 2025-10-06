return {
    id = "torpedo_launcher",
    type = "missile",
    name = "Torpedo Launcher",
    description = "Slow, heavy torpedo with massive hull damage.",
    price = 3600,
    volume = 18,
    module = { type = "turret" },
    icon = {
        size = 32,
        shapes = {
            -- Main chassis - torpedo launcher
            { type = "polygon", mode = "fill", color = {0.10, 0.08, 0.06, 1}, points = {4, 28, 8, 6, 24, 6, 28, 28, 16, 32} },
            { type = "polygon", mode = "fill", color = {0.24, 0.20, 0.16, 1}, points = {6, 24, 10, 10, 22, 10, 26, 24, 16, 28} },
            
            -- Torpedo tube
            { type = "rectangle", mode = "fill", color = {0.15, 0.12, 0.10, 1}, x = 13, y = 6, w = 6, h = 18, rx = 1 },
            { type = "rectangle", mode = "fill", color = {0.35, 0.28, 0.22, 0.8}, x = 14, y = 7, w = 4, h = 16, rx = 0.5 },
            
            -- Torpedo body
            { type = "rectangle", mode = "fill", color = {0.50, 0.40, 0.30, 1}, x = 14, y = 8, w = 4, h = 14, rx = 1 },
            { type = "rectangle", mode = "fill", color = {0.70, 0.60, 0.50, 0.9}, x = 15, y = 9, w = 2, h = 12, rx = 0.5 },
            
            -- Warhead section
            { type = "polygon", mode = "fill", color = {0.80, 0.60, 0.40, 1}, points = {14, 8, 18, 8, 16, 4} },
            { type = "polygon", mode = "fill", color = {1.00, 0.80, 0.60, 0.9}, points = {15, 8, 17, 8, 16, 5} },
            
            -- Propulsion fins
            { type = "polygon", mode = "fill", color = {0.40, 0.35, 0.25, 1}, points = {12, 18, 14, 16, 14, 20} },
            { type = "polygon", mode = "fill", color = {0.40, 0.35, 0.25, 1}, points = {18, 16, 20, 18, 18, 20} },
            
            -- Launch indicators
            { type = "circle", mode = "fill", color = {0.80, 0.40, 0.20, 0.9}, x = 10, y = 16, r = 1.5 },
            { type = "circle", mode = "fill", color = {0.80, 0.40, 0.20, 0.9}, x = 22, y = 16, r = 1.5 },
        }
    },

    projectile = {
        id = "torpedo_round",
        class = "Projectile",
        physics = { speed = 900 },
        renderable = { renderer = "torpedo", props = { radius = 6, length = 32 } },
        damage = { value = 48 },
        collidable = { radius = 6 },
        timed_life = { duration = 6.0 },
        behaviors = {
            { type = "homing", turnRate = math.rad(90), range = 2200, speed = 900 }
        },
        effects = {
            { type = "dynamic_light", radius = 34, color = {1.0, 0.6, 0.2, 0.8} },
            { type = "particle_emitter", type = "smoke", interval = 0.05, speed = 90, color = {1.0, 0.5, 0.2, 0.6} }
        }
    },

    tracer = { color = {1.0, 0.6, 0.2, 1.0}, width = 3.4, coreRadius = 5 },
    impact = {
        shield = { spanDeg = 120, color1 = {1.0, 0.6, 0.2, 0.6}, color2 = {1.0, 0.5, 0.2, 0.4} },
        hull = { spark = {1.0, 0.5, 0.1, 0.9}, ring = {1.0, 0.3, 0.0, 0.6} }
    },

    optimal = 1800, falloff = 2800,
    damage_range = { min = 40, max = 56 },
    cycle = 7.0, capCost = 12,
    maxRange = 3600,

    modifiers = {
        { type = "capacitor_bank" }
    },

    upgrades = {
        thresholds = { 260, 560, 1120 },
        bonuses = {
            [1] = { damageMultiplier = 1.12 },
            [2] = { homingBonus = math.rad(35) },
            [3] = { cycleMultiplier = 0.85 },
        }
    },
    -- Firing mode
    fireMode = "manual"
}
