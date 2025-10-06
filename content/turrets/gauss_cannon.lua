return {
    id = "gauss_cannon",
    type = "gun",
    name = "Gauss Cannon",
    description = "Magnetically accelerated rounds with high penetration.",
    price = 2400,
    volume = 14,
    module = { type = "turret" },
    icon = {
        size = 32,
        shapes = {
            -- Main chassis - gauss cannon
            { type = "polygon", mode = "fill", color = {0.10, 0.12, 0.14, 1}, points = {5, 28, 9, 6, 23, 6, 27, 28, 16, 32} },
            { type = "polygon", mode = "fill", color = {0.24, 0.28, 0.32, 1}, points = {7, 24, 11, 10, 21, 10, 25, 24, 16, 28} },
            
            -- Gauss accelerator barrel
            { type = "rectangle", mode = "fill", color = {0.20, 0.25, 0.30, 1}, x = 13, y = 6, w = 6, h = 18, rx = 1 },
            { type = "rectangle", mode = "fill", color = {0.40, 0.50, 0.60, 0.8}, x = 14, y = 7, w = 4, h = 16, rx = 0.5 },
            
            -- Electromagnetic coils
            { type = "circle", mode = "line", color = {0.60, 0.75, 0.90, 0.9}, x = 16, y = 10, r = 4, lineWidth = 2 },
            { type = "circle", mode = "line", color = {0.60, 0.75, 0.90, 0.9}, x = 16, y = 14, r = 4, lineWidth = 2 },
            { type = "circle", mode = "line", color = {0.60, 0.75, 0.90, 0.9}, x = 16, y = 18, r = 4, lineWidth = 2 },
            { type = "circle", mode = "line", color = {0.60, 0.75, 0.90, 0.9}, x = 16, y = 22, r = 4, lineWidth = 2 },
            
            -- Projectile chamber
            { type = "rectangle", mode = "fill", color = {0.50, 0.60, 0.70, 1}, x = 15, y = 8, w = 2, h = 14, rx = 1 },
            { type = "rectangle", mode = "fill", color = {0.70, 0.80, 0.90, 0.9}, x = 15.5, y = 9, w = 1, h = 12, rx = 0.5 },
            
            -- Power capacitors
            { type = "rectangle", mode = "fill", color = {0.25, 0.35, 0.45, 1}, x = 8, y = 12, w = 4, h = 8, rx = 1 },
            { type = "rectangle", mode = "fill", color = {0.25, 0.35, 0.45, 1}, x = 20, y = 12, w = 4, h = 8, rx = 1 },
            
            -- Energy indicators
            { type = "circle", mode = "fill", color = {0.60, 0.75, 0.90, 0.9}, x = 10, y = 16, r = 1.5 },
            { type = "circle", mode = "fill", color = {0.60, 0.75, 0.90, 0.9}, x = 22, y = 16, r = 1.5 },
        }
    },

    projectile = {
        id = "gauss_slug",
        class = "Projectile",
        physics = { speed = 2600 },
        renderable = { renderer = "gauss", props = { radius = 4 } },
        damage = { value = 32 },
        collidable = { radius = 4 },
        timed_life = { duration = 3.0 },
        effects = {
            { type = "dynamic_light", radius = 26, color = {1.0, 0.8, 0.3, 0.6} }
        }
    },

    tracer = { color = {1.0, 0.85, 0.35, 1.0}, width = 2.4, coreRadius = 4 },
    impact = {
        shield = { spanDeg = 90, color1 = {1.0, 0.8, 0.4, 0.6}, color2 = {1.0, 0.65, 0.2, 0.4} },
        hull = { spark = {1.0, 0.6, 0.2, 0.9}, ring = {1.0, 0.4, 0.1, 0.5} }
    },

    optimal = 1200, falloff = 500,
    damage_range = { min = 28, max = 36 },
    cycle = 2.0, capCost = 8,
    maxRange = 2000,

    modifiers = {
        { type = "overcharged_coils" }
    },

    upgrades = {
        thresholds = { 250, 520, 980 },
        bonuses = {
            [1] = { damageMultiplier = 1.1 },
            [2] = { cycleMultiplier = 0.9 },
            [3] = { damageMultiplier = 1.05, projectileSpeed = 200 },
        }
    },
}
