return {
    id = "particle_beam",
    type = "laser",
    name = "Particle Beam",
    description = "Continuous beam that pierces multiple targets.",
    price = 3800,
    volume = 12,
    module = { type = "turret" },
    icon = {
        size = 32,
        shapes = {
            -- Main chassis - particle accelerator
            { type = "polygon", mode = "fill", color = {0.08, 0.10, 0.12, 1}, points = {5, 28, 9, 6, 23, 6, 27, 28, 16, 32} },
            { type = "polygon", mode = "fill", color = {0.20, 0.24, 0.28, 1}, points = {7, 24, 11, 10, 21, 10, 25, 24, 16, 28} },
            
            -- Particle accelerator core
            { type = "rectangle", mode = "fill", color = {0.15, 0.20, 0.25, 1}, x = 13, y = 6, w = 6, h = 18, rx = 1 },
            { type = "rectangle", mode = "fill", color = {0.30, 0.40, 0.50, 0.8}, x = 14, y = 7, w = 4, h = 16, rx = 0.5 },
            
            -- Particle focus rings
            { type = "circle", mode = "line", color = {0.50, 0.70, 1.00, 0.9}, x = 16, y = 10, r = 5, lineWidth = 2 },
            { type = "circle", mode = "line", color = {0.50, 0.70, 1.00, 0.9}, x = 16, y = 16, r = 5, lineWidth = 2 },
            { type = "circle", mode = "line", color = {0.50, 0.70, 1.00, 0.9}, x = 16, y = 22, r = 5, lineWidth = 2 },
            
            -- Energy conduits
            { type = "rectangle", mode = "fill", color = {0.25, 0.35, 0.45, 1}, x = 8, y = 12, w = 4, h = 8, rx = 1 },
            { type = "rectangle", mode = "fill", color = {0.25, 0.35, 0.45, 1}, x = 20, y = 12, w = 4, h = 8, rx = 1 },
            
            -- Particle indicators
            { type = "circle", mode = "fill", color = {0.50, 0.70, 1.00, 0.9}, x = 10, y = 16, r = 1.5 },
            { type = "circle", mode = "fill", color = {0.50, 0.70, 1.00, 0.9}, x = 22, y = 16, r = 1.5 },
        }
    },

    projectile = {
        id = "particle_beam_projectile",
        class = "Projectile",
        physics = { speed = 0 },
        renderable = { renderer = "particle_beam", props = { length = 1000 } },
        damage = { value = 55 },
        collidable = { radius = 3 },
        timed_life = { duration = 0.25 },
        effects = {
            { type = "dynamic_light", radius = 40, color = {0.6, 0.9, 1.0, 0.7} }
        }
    },

    tracer = { color = {0.6, 0.9, 1.0, 0.85}, width = 3, coreRadius = 3 },
    impact = {
        shield = { spanDeg = 80, color1 = {0.6, 0.9, 1.0, 0.6}, color2 = {0.4, 0.7, 1.0, 0.4} },
        hull = { spark = {0.6, 0.9, 1.0, 0.8}, ring = {0.4, 0.7, 1.0, 0.5} }
    },

    optimal = 1000, falloff = 600,
    damage_range = { min = 50, max = 50 },
    damagePerSecond = 50,
    cycle = 2.6, capCost = 12,
    energyPerSecond = 60,
    maxRange = 1500,

    modifiers = {
        { type = "capacitor_bank" }
    },

    upgrades = {
        thresholds = { 240, 520, 980 },
        bonuses = {
            [1] = { damageMultiplier = 1.1 },
            [2] = { cycleMultiplier = 0.9 },
            [3] = { damageMultiplier = 1.05, cycleMultiplier = 0.9 },
        }
    },
}
