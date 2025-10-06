return {
    id = "disruptor_beam",
    type = "laser",
    name = "Disruptor Beam",
    description = "High-frequency beam tuned to strip shields rapidly.",
    price = 4200,
    volume = 12,
    module = { type = "turret" },
    icon = {
        size = 32,
        shapes = {
            -- Main chassis - disruptor generator
            { type = "polygon", mode = "fill", color = {0.12, 0.08, 0.10, 1}, points = {5, 28, 9, 6, 23, 6, 27, 28, 16, 32} },
            { type = "polygon", mode = "fill", color = {0.28, 0.20, 0.24, 1}, points = {7, 24, 11, 10, 21, 10, 25, 24, 16, 28} },
            
            -- Disruptor core
            { type = "rectangle", mode = "fill", color = {0.20, 0.15, 0.18, 1}, x = 13, y = 6, w = 6, h = 18, rx = 1 },
            { type = "rectangle", mode = "fill", color = {0.40, 0.30, 0.36, 0.8}, x = 14, y = 7, w = 4, h = 16, rx = 0.5 },
            
            -- Disruption field generator
            { type = "circle", mode = "fill", color = {0.60, 0.20, 0.40, 1}, x = 16, y = 16, r = 6 },
            { type = "circle", mode = "fill", color = {0.80, 0.40, 0.60, 0.8}, x = 16, y = 16, r = 4 },
            { type = "circle", mode = "fill", color = {1.00, 0.60, 0.80, 0.6}, x = 16, y = 16, r = 2 },
            
            -- Field stabilizers
            { type = "circle", mode = "line", color = {0.80, 0.40, 0.60, 0.9}, x = 16, y = 10, r = 4, lineWidth = 2 },
            { type = "circle", mode = "line", color = {0.80, 0.40, 0.60, 0.9}, x = 16, y = 22, r = 4, lineWidth = 2 },
            
            -- Power conduits
            { type = "rectangle", mode = "fill", color = {0.30, 0.22, 0.26, 1}, x = 8, y = 12, w = 4, h = 8, rx = 1 },
            { type = "rectangle", mode = "fill", color = {0.30, 0.22, 0.26, 1}, x = 20, y = 12, w = 4, h = 8, rx = 1 },
            
            -- Disruption indicators
            { type = "circle", mode = "fill", color = {0.80, 0.40, 0.60, 0.9}, x = 10, y = 16, r = 1.5 },
            { type = "circle", mode = "fill", color = {0.80, 0.40, 0.60, 0.9}, x = 22, y = 16, r = 1.5 },
        }
    },

    projectile = {
        id = "disruptor_beam_projectile",
        class = "Projectile",
        physics = { speed = 0 },
        renderable = { renderer = "disruptor_beam", props = { length = 900 } },
        damage = { value = 40 },
        collidable = { radius = 3 },
        timed_life = { duration = 0.22 },
        effects = {
            { type = "dynamic_light", radius = 36, color = {0.95, 0.4, 1.0, 0.7} }
        }
    },

    tracer = { color = {0.95, 0.4, 1.0, 0.9}, width = 3.6, coreRadius = 2 },
    impact = {
        shield = { spanDeg = 100, color1 = {0.95, 0.4, 1.0, 0.7}, color2 = {0.7, 0.2, 0.9, 0.5} },
        hull = { spark = {0.9, 0.4, 1.0, 0.6}, ring = {0.7, 0.2, 0.9, 0.4} }
    },

    optimal = 900, falloff = 500,
    damage_range = { min = 36, max = 36 },
    damagePerSecond = 36,
    cycle = 2.4, capCost = 10,
    energyPerSecond = 70,
    maxRange = 1400,

    modifiers = {
        { type = "capacitor_bank" },
        { type = "precision_barrel" }
    },

    upgrades = {
        thresholds = { 230, 480, 960 },
        bonuses = {
            [1] = { damageMultiplier = 1.08 },
            [2] = { cycleMultiplier = 0.9 },
            [3] = { damageMultiplier = 1.06, cycleMultiplier = 0.9 },
        }
    },
}
