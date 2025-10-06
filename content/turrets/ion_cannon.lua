return {
    id = "ion_cannon",
    type = "gun",
    name = "Ion Cannon",
    description = "Precision energy weapon that disables systems and leaves an ionized field.",
    price = 2200,
    volume = 12,
    module = { type = "turret" },
    icon = {
        size = 32,
        shapes = {
            -- Main chassis - ion cannon design
            { type = "polygon", mode = "fill", color = {0.08, 0.12, 0.16, 1}, points = {5, 28, 9, 6, 23, 6, 27, 28, 16, 32} },
            { type = "polygon", mode = "fill", color = {0.20, 0.28, 0.36, 1}, points = {7, 24, 11, 10, 21, 10, 25, 24, 16, 28} },
            
            -- Ion accelerator barrel
            { type = "rectangle", mode = "fill", color = {0.15, 0.25, 0.35, 1}, x = 13, y = 6, w = 6, h = 18, rx = 1 },
            { type = "rectangle", mode = "fill", color = {0.30, 0.50, 0.70, 0.8}, x = 14, y = 7, w = 4, h = 16, rx = 0.5 },
            
            -- Ion focus rings
            { type = "circle", mode = "line", color = {0.40, 0.70, 1.00, 0.9}, x = 16, y = 10, r = 4, lineWidth = 2 },
            { type = "circle", mode = "line", color = {0.40, 0.70, 1.00, 0.9}, x = 16, y = 16, r = 4, lineWidth = 2 },
            { type = "circle", mode = "line", color = {0.40, 0.70, 1.00, 0.9}, x = 16, y = 22, r = 4, lineWidth = 2 },
            
            -- Power cells
            { type = "rectangle", mode = "fill", color = {0.20, 0.35, 0.50, 1}, x = 8, y = 12, w = 4, h = 8, rx = 1 },
            { type = "rectangle", mode = "fill", color = {0.20, 0.35, 0.50, 1}, x = 20, y = 12, w = 4, h = 8, rx = 1 },
            
            -- Energy indicators
            { type = "circle", mode = "fill", color = {0.40, 0.70, 1.00, 0.9}, x = 10, y = 16, r = 1.5 },
            { type = "circle", mode = "fill", color = {0.40, 0.70, 1.00, 0.9}, x = 22, y = 16, r = 1.5 },
        }
    },

    projectile = {
        id = "ion_bolt",
        class = "Projectile",
        physics = { speed = 1800 },
        renderable = {
            renderer = "ion",
            props = { radius = 6 }
        },
        damage = { value = 24 },
        collidable = { radius = 6 },
        timed_life = { duration = 3.5 },
        behaviors = {
            { type = "homing", turnRate = math.rad(180), range = 1000 },
            { type = "area_denial", radius = 140, duration = 2.5, damageMultiplier = 0.25, color = {0.35, 0.9, 1.0, 0.25} }
        },
        effects = {
            { type = "dynamic_light", radius = 32, color = {0.4, 0.9, 1.0, 0.8} },
            { type = "particle_emitter", type = "spark", interval = 0.05, speed = 80, color = {0.5, 0.9, 1.0, 0.7} }
        }
    },

    tracer = { color = {0.5, 0.9, 1.0, 1.0}, width = 3, coreRadius = 4 },
    impact = {
        shield = { spanDeg = 110, color1 = {0.4, 0.9, 1.0, 0.6}, color2 = {0.3, 0.8, 1.0, 0.4} },
        hull = { spark = {0.6, 0.9, 1.0, 0.8}, ring = {0.3, 0.8, 1.0, 0.5} }
    },

    optimal = 900, falloff = 400,
    damage_range = { min = 18, max = 26 },
    cycle = 1.6, capCost = 14,
    maxRange = 1400,

    modifiers = {
        { type = "overcharged_coils" },
        { type = "capacitor_bank" }
    },

    upgrades = {
        thresholds = { 200, 450, 900 },
        bonuses = {
            [1] = { damageMultiplier = 1.1 },
            [2] = { cycleMultiplier = 0.9 },
            [3] = { homingBonus = math.rad(45) },
        }
    },
}
