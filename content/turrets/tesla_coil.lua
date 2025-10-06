return {
    id = "tesla_coil",
    type = "gun",
    name = "Tesla Coil",
    description = "Fires arcing bolts that leap between enemies.",
    price = 2800,
    volume = 14,
    module = { type = "turret" },
    icon = {
        size = 32,
        shapes = {
            -- Main chassis - tesla coil design
            { type = "polygon", mode = "fill", color = {0.12, 0.15, 0.18, 1}, points = {6, 28, 10, 8, 22, 8, 26, 28, 16, 32} },
            { type = "polygon", mode = "fill", color = {0.25, 0.30, 0.35, 1}, points = {8, 24, 12, 12, 20, 12, 24, 24, 16, 28} },
            
            -- Tesla coil tower
            { type = "rectangle", mode = "fill", color = {0.20, 0.25, 0.30, 1}, x = 14, y = 8, w = 4, h = 16, rx = 1 },
            { type = "rectangle", mode = "fill", color = {0.40, 0.50, 0.60, 0.8}, x = 15, y = 9, w = 2, h = 14, rx = 0.5 },
            
            -- Coil windings
            { type = "circle", mode = "line", color = {0.60, 0.90, 1.00, 0.9}, x = 16, y = 12, r = 3, lineWidth = 2 },
            { type = "circle", mode = "line", color = {0.60, 0.90, 1.00, 0.9}, x = 16, y = 16, r = 3, lineWidth = 2 },
            { type = "circle", mode = "line", color = {0.60, 0.90, 1.00, 0.9}, x = 16, y = 20, r = 3, lineWidth = 2 },
            
            -- Electrical discharge
            { type = "line", color = {0.80, 1.00, 1.00, 0.8}, x1 = 12, y1 = 6, x2 = 20, y2 = 6, lineWidth = 2 },
            { type = "line", color = {0.80, 1.00, 1.00, 0.8}, x1 = 10, y1 = 8, x2 = 22, y2 = 8, lineWidth = 1 },
            
            -- Power indicators
            { type = "circle", mode = "fill", color = {0.60, 0.90, 1.00, 0.9}, x = 11, y = 18, r = 1.5 },
            { type = "circle", mode = "fill", color = {0.60, 0.90, 1.00, 0.9}, x = 21, y = 18, r = 1.5 },
        }
    },

    projectile = {
        id = "tesla_bolt",
        class = "Projectile",
        physics = { speed = 1400 },
        renderable = { renderer = "tesla", props = { radius = 4 } },
        damage = { value = 14 },
        collidable = { radius = 5 },
        timed_life = { duration = 3.0 },
        behaviors = {
            { type = "bouncing", bounces = 2, speedMultiplier = 0.85 },
            { type = "splitting", count = 3, spread = math.rad(50), damageMultiplier = 0.35 }
        },
        effects = {
            { type = "dynamic_light", radius = 28, color = {0.6, 0.9, 1.0, 0.9} },
            { type = "particle_emitter", type = "spark", interval = 0.04, speed = 160, color = {0.6, 0.9, 1.0, 0.9} }
        }
    },

    tracer = { color = {0.6, 0.95, 1.0, 1.0}, width = 2.5, coreRadius = 4 },
    impact = {
        shield = { spanDeg = 120, color1 = {0.5, 0.9, 1.0, 0.6}, color2 = {0.6, 0.9, 1.0, 0.4} },
        hull = { spark = {0.7, 0.9, 1.0, 0.9}, ring = {0.4, 0.8, 1.0, 0.45} }
    },

    optimal = 750, falloff = 600,
    damage_range = { min = 12, max = 20 },
    cycle = 1.0, capCost = 10,
    maxRange = 1100,

    modifiers = {
        { type = "precision_barrel" }
    },

    upgrades = {
        thresholds = { 180, 420, 780 },
        bonuses = {
            [1] = { damageMultiplier = 1.15 },
            [2] = { cycleMultiplier = 0.85 },
            [3] = { homingBonus = math.rad(35) },
        }
    },
}
