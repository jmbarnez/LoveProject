return {
    id = "fragmentation_launcher",
    type = "gun",
    name = "Fragmentation Launcher",
    description = "Shells that split into a burst of shrapnel on impact.",
    price = 2100,
    volume = 15,
    module = { type = "turret" },
    icon = {
        size = 32,
        shapes = {
            -- Main chassis - fragmentation launcher
            { type = "polygon", mode = "fill", color = {0.10, 0.12, 0.08, 1}, points = {4, 28, 8, 6, 24, 6, 28, 28, 16, 32} },
            { type = "polygon", mode = "fill", color = {0.24, 0.28, 0.22, 1}, points = {6, 24, 10, 10, 22, 10, 26, 24, 16, 28} },
            
            -- Multi-barrel assembly
            { type = "rectangle", mode = "fill", color = {0.15, 0.18, 0.12, 1}, x = 12, y = 6, w = 8, h = 16, rx = 1 },
            { type = "rectangle", mode = "fill", color = {0.35, 0.42, 0.28, 0.8}, x = 13, y = 7, w = 6, h = 14, rx = 0.5 },
            
            -- Individual barrels
            { type = "rectangle", mode = "fill", color = {0.50, 0.60, 0.40, 1}, x = 13, y = 8, w = 2, h = 12, rx = 1 },
            { type = "rectangle", mode = "fill", color = {0.50, 0.60, 0.40, 1}, x = 16, y = 8, w = 2, h = 12, rx = 1 },
            { type = "rectangle", mode = "fill", color = {0.50, 0.60, 0.40, 1}, x = 19, y = 8, w = 2, h = 12, rx = 1 },
            
            -- Fragmentation chambers
            { type = "circle", mode = "fill", color = {0.70, 0.80, 0.60, 1}, x = 14, y = 6, r = 1.5 },
            { type = "circle", mode = "fill", color = {0.70, 0.80, 0.60, 1}, x = 17, y = 6, r = 1.5 },
            { type = "circle", mode = "fill", color = {0.70, 0.80, 0.60, 1}, x = 20, y = 6, r = 1.5 },
            
            -- Shrapnel indicators
            { type = "line", color = {0.80, 0.90, 0.70, 0.8}, x1 = 12, y1 = 12, x2 = 22, y2 = 12, lineWidth = 1 },
            { type = "line", color = {0.80, 0.90, 0.70, 0.8}, x1 = 12, y1 = 16, x2 = 22, y2 = 16, lineWidth = 1 },
            
            -- Targeting systems
            { type = "circle", mode = "fill", color = {0.60, 0.80, 0.40, 0.9}, x = 10, y = 16, r = 1.5 },
            { type = "circle", mode = "fill", color = {0.60, 0.80, 0.40, 0.9}, x = 22, y = 16, r = 1.5 },
        }
    },

    projectile = {
        id = "fragmentation_shell",
        class = "Projectile",
        physics = { speed = 1800 },
        renderable = { renderer = "fragmentation", props = { radius = 5 } },
        damage = { value = 22 },
        collidable = { radius = 6 },
        timed_life = { duration = 2.5 },
        behaviors = {
            { type = "splitting", count = 5, spread = math.rad(90), damageMultiplier = 0.45 }
        },
        effects = {
            { type = "dynamic_light", radius = 24, color = {1.0, 0.6, 0.2, 0.7} },
            { type = "particle_emitter", type = "spark", interval = 0.06, speed = 200, color = {1.0, 0.6, 0.2, 0.7} }
        }
    },

    tracer = { color = {1.0, 0.65, 0.3, 1.0}, width = 2.6, coreRadius = 5 },
    impact = {
        shield = { spanDeg = 70, color1 = {1.0, 0.65, 0.3, 0.5}, color2 = {1.0, 0.5, 0.2, 0.35} },
        hull = { spark = {1.0, 0.6, 0.2, 0.9}, ring = {1.0, 0.45, 0.1, 0.5} }
    },

    optimal = 700, falloff = 900,
    damage_range = { min = 18, max = 28 },
    cycle = 1.8, capCost = 6,
    maxRange = 1600,

    modifiers = {
        { type = "vented_housing" },
        { type = "precision_barrel" }
    },

    upgrades = {
        thresholds = { 190, 420, 860 },
        bonuses = {
            [1] = { damageMultiplier = 1.1 },
            [2] = { cycleMultiplier = 0.9 },
            [3] = { damageMultiplier = 1.05, spreadMultiplier = 0.85 },
        }
    },
    -- Firing mode
    fireMode = "manual"
}
