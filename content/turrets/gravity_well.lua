return {
    id = "gravity_well",
    type = "gun",
    name = "Gravity Well",
    description = "Launches a slow orb that pulls enemies inward and deals sustained damage.",
    price = 3200,
    volume = 16,
    module = { type = "turret" },
    icon = {
        size = 32,
        shapes = {
            -- Main chassis - gravity well generator
            { type = "polygon", mode = "fill", color = {0.10, 0.08, 0.12, 1}, points = {4, 28, 8, 6, 24, 6, 28, 28, 16, 32} },
            { type = "polygon", mode = "fill", color = {0.22, 0.18, 0.25, 1}, points = {6, 24, 10, 10, 22, 10, 26, 24, 16, 28} },
            
            -- Gravity core
            { type = "circle", mode = "fill", color = {0.30, 0.20, 0.50, 1}, x = 16, y = 16, r = 8 },
            { type = "circle", mode = "fill", color = {0.50, 0.30, 1.00, 0.8}, x = 16, y = 16, r = 6 },
            { type = "circle", mode = "fill", color = {0.70, 0.50, 1.00, 0.6}, x = 16, y = 16, r = 4 },
            
            -- Gravity field rings
            { type = "circle", mode = "line", color = {0.50, 0.30, 1.00, 0.6}, x = 16, y = 16, r = 10, lineWidth = 1 },
            { type = "circle", mode = "line", color = {0.50, 0.30, 1.00, 0.4}, x = 16, y = 16, r = 12, lineWidth = 1 },
            
            -- Generator coils
            { type = "rectangle", mode = "fill", color = {0.25, 0.20, 0.30, 1}, x = 12, y = 8, w = 8, h = 4, rx = 1 },
            { type = "rectangle", mode = "fill", color = {0.45, 0.35, 0.55, 0.8}, x = 13, y = 9, w = 6, h = 2, rx = 0.5 },
            
            -- Power conduits
            { type = "line", color = {0.50, 0.30, 1.00, 0.7}, x1 = 8, y1 = 20, x2 = 24, y2 = 20, lineWidth = 2 },
            { type = "line", color = {0.50, 0.30, 1.00, 0.7}, x1 = 8, y1 = 22, x2 = 24, y2 = 22, lineWidth = 1 },
        }
    },

    projectile = {
        id = "gravity_well_orb",
        class = "Projectile",
        physics = { speed = 900 },
        renderable = { renderer = "gravity_well", props = { radius = 10 } },
        damage = { value = 10 },
        collidable = { radius = 10 },
        timed_life = { duration = 4.5 },
        behaviors = {
            { type = "area_denial", radius = 200, duration = 4.0, damageMultiplier = 0.2, color = {0.45, 0.2, 1.0, 0.3} }
        },
        effects = {
            { type = "dynamic_light", radius = 42, color = {0.5, 0.3, 1.0, 0.7}, pulse = { min = 0.7, max = 1.2, speed = 2.0 } },
            { type = "particle_emitter", type = "smoke", interval = 0.07, speed = 40, color = {0.5, 0.3, 1.0, 0.4} }
        }
    },

    tracer = { color = {0.5, 0.3, 1.0, 0.7}, width = 2.0, coreRadius = 6 },
    impact = {
        shield = { spanDeg = 140, color1 = {0.6, 0.4, 1.0, 0.5}, color2 = {0.4, 0.2, 0.9, 0.35} },
        hull = { spark = {0.6, 0.3, 1.0, 0.7}, ring = {0.3, 0.1, 0.6, 0.4} }
    },

    optimal = 600, falloff = 800,
    damage_range = { min = 8, max = 12 },
    cycle = 2.8, capCost = 16,
    maxRange = 1500,

    modifiers = {
        { type = "vented_housing" }
    },

    upgrades = {
        thresholds = { 220, 520, 1020 },
        bonuses = {
            [1] = { damageMultiplier = 1.2 },
            [2] = { cycleMultiplier = 0.9 },
            [3] = { projectileSpeed = 120 },
        }
    },
    -- Firing mode
    fireMode = "manual"
}
