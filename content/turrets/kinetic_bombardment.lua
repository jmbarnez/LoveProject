return {
    id = "kinetic_bombardment",
    type = "gun",
    name = "Kinetic Bombardment",
    description = "Orbital strike platform delivering devastating kinetic rods.",
    price = 4200,
    volume = 20,
    module = { type = "turret" },
    icon = {
        size = 32,
        shapes = {
            -- Main chassis - heavy bombardment cannon
            { type = "polygon", mode = "fill", color = {0.12, 0.10, 0.08, 1}, points = {3, 28, 7, 4, 25, 4, 29, 28, 16, 32} },
            { type = "polygon", mode = "fill", color = {0.28, 0.24, 0.20, 1}, points = {5, 24, 9, 8, 23, 8, 27, 24, 16, 28} },
            
            -- Massive barrel assembly
            { type = "rectangle", mode = "fill", color = {0.20, 0.18, 0.15, 1}, x = 12, y = 4, w = 8, h = 20, rx = 1 },
            { type = "rectangle", mode = "fill", color = {0.40, 0.35, 0.30, 0.8}, x = 13, y = 5, w = 6, h = 18, rx = 0.5 },
            
            -- Barrel reinforcement rings
            { type = "circle", mode = "line", color = {0.60, 0.50, 0.40, 0.9}, x = 16, y = 8, r = 5, lineWidth = 2 },
            { type = "circle", mode = "line", color = {0.60, 0.50, 0.40, 0.9}, x = 16, y = 14, r = 5, lineWidth = 2 },
            { type = "circle", mode = "line", color = {0.60, 0.50, 0.40, 0.9}, x = 16, y = 20, r = 5, lineWidth = 2 },
            
            -- Ammunition feed
            { type = "rectangle", mode = "fill", color = {0.25, 0.22, 0.18, 1}, x = 6, y = 12, w = 6, h = 8, rx = 1 },
            { type = "rectangle", mode = "fill", color = {0.25, 0.22, 0.18, 1}, x = 20, y = 12, w = 6, h = 8, rx = 1 },
            
            -- Targeting systems
            { type = "circle", mode = "fill", color = {0.80, 0.60, 0.40, 0.9}, x = 9, y = 16, r = 1.5 },
            { type = "circle", mode = "fill", color = {0.80, 0.60, 0.40, 0.9}, x = 23, y = 16, r = 1.5 },
        }
    },

    projectile = {
        id = "kinetic_rod",
        class = "Projectile",
        physics = { speed = 2000 },
        renderable = { renderer = "kinetic_bombardment", props = { radius = 7 } },
        damage = { value = 60 },
        collidable = { radius = 6 },
        timed_life = { duration = 3.5 },
        behaviors = {
            { type = "area_denial", radius = 160, duration = 3.0, damageMultiplier = 0.3, color = {1.0, 0.7, 0.3, 0.25} }
        },
        effects = {
            { type = "dynamic_light", radius = 38, color = {1.0, 0.8, 0.4, 0.8} },
            { type = "particle_emitter", type = "spark", interval = 0.05, speed = 220, color = {1.0, 0.7, 0.3, 0.8} }
        }
    },

    tracer = { color = {1.0, 0.8, 0.6, 1.0}, width = 3.0, coreRadius = 6 },
    impact = {
        shield = { spanDeg = 160, color1 = {1.0, 0.75, 0.4, 0.6}, color2 = {1.0, 0.6, 0.2, 0.4} },
        hull = { spark = {1.0, 0.7, 0.3, 1.0}, ring = {1.0, 0.6, 0.2, 0.6} }
    },

    optimal = 1500, falloff = 600,
    damage_range = { min = 52, max = 70 },
    cycle = 3.4, capCost = 18,
    maxRange = 2200,

    modifiers = {
        { type = "overcharged_coils" },
        { type = "capacitor_bank" }
    },

    upgrades = {
        thresholds = { 320, 680, 1280 },
        bonuses = {
            [1] = { damageMultiplier = 1.15 },
            [2] = { cycleMultiplier = 0.85 },
            [3] = { damageMultiplier = 1.1, projectileSpeed = 250 },
        }
    },
    -- Firing mode
    fireMode = "manual"
}
