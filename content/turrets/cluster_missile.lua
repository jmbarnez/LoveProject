return {
    id = "cluster_missile",
    type = "missile",
    name = "Cluster Missile",
    description = "Missiles that split into multiple warheads near the target.",
    price = 3400,
    volume = 16,
    module = { type = "turret" },
    icon = {
        size = 32,
        shapes = {
            -- Main chassis - cluster missile launcher
            { type = "polygon", mode = "fill", color = {0.08, 0.10, 0.12, 1}, points = {4, 28, 8, 6, 24, 6, 28, 28, 16, 32} },
            { type = "polygon", mode = "fill", color = {0.20, 0.24, 0.28, 1}, points = {6, 24, 10, 10, 22, 10, 26, 24, 16, 28} },
            
            -- Missile cluster tube
            { type = "rectangle", mode = "fill", color = {0.15, 0.20, 0.25, 1}, x = 13, y = 6, w = 6, h = 16, rx = 1 },
            { type = "rectangle", mode = "fill", color = {0.35, 0.45, 0.55, 0.8}, x = 14, y = 7, w = 4, h = 14, rx = 0.5 },
            
            -- Cluster missile assembly
            { type = "rectangle", mode = "fill", color = {0.50, 0.60, 0.70, 1}, x = 14, y = 8, w = 4, h = 12, rx = 1 },
            { type = "rectangle", mode = "fill", color = {0.70, 0.80, 0.90, 0.9}, x = 15, y = 9, w = 2, h = 10, rx = 0.5 },
            
            -- Sub-missile clusters
            { type = "circle", mode = "fill", color = {0.80, 0.90, 1.00, 1}, x = 13, y = 10, r = 1 },
            { type = "circle", mode = "fill", color = {0.80, 0.90, 1.00, 1}, x = 17, y = 10, r = 1 },
            { type = "circle", mode = "fill", color = {0.80, 0.90, 1.00, 1}, x = 13, y = 14, r = 1 },
            { type = "circle", mode = "fill", color = {0.80, 0.90, 1.00, 1}, x = 17, y = 14, r = 1 },
            { type = "circle", mode = "fill", color = {0.80, 0.90, 1.00, 1}, x = 13, y = 18, r = 1 },
            { type = "circle", mode = "fill", color = {0.80, 0.90, 1.00, 1}, x = 17, y = 18, r = 1 },
            
            -- Cluster separation lines
            { type = "line", color = {0.60, 0.70, 0.80, 0.6}, x1 = 12, y1 = 12, x2 = 20, y2 = 12, lineWidth = 1 },
            { type = "line", color = {0.60, 0.70, 0.80, 0.6}, x1 = 12, y1 = 16, x2 = 20, y2 = 16, lineWidth = 1 },
            
            -- Guidance systems
            { type = "circle", mode = "fill", color = {0.40, 0.70, 1.00, 0.9}, x = 10, y = 16, r = 1.5 },
            { type = "circle", mode = "fill", color = {0.40, 0.70, 1.00, 0.9}, x = 22, y = 16, r = 1.5 },
        }
    },

    projectile = {
        id = "cluster_missile_round",
        class = "Projectile",
        physics = { speed = 1300 },
        renderable = { renderer = "cluster_missile", props = { radius = 5 } },
        damage = { value = 26 },
        collidable = { radius = 5 },
        timed_life = { duration = 5.0 },
        behaviors = {
            { type = "homing", turnRate = math.rad(120), range = 2000, speed = 1300 },
            { type = "splitting", trigger = "hit", count = 4, spread = math.rad(70), damageMultiplier = 0.45 }
        },
        effects = {
            { type = "dynamic_light", radius = 28, color = {0.9, 0.8, 0.4, 0.8} },
            { type = "particle_emitter", type = "spark", interval = 0.05, speed = 140, color = {1.0, 0.8, 0.4, 0.7} }
        }
    },

    tracer = { color = {1.0, 0.8, 0.4, 1.0}, width = 2.8, coreRadius = 5 },
    impact = {
        shield = { spanDeg = 110, color1 = {1.0, 0.75, 0.4, 0.6}, color2 = {1.0, 0.65, 0.3, 0.4} },
        hull = { spark = {1.0, 0.6, 0.2, 0.8}, ring = {1.0, 0.4, 0.1, 0.5} }
    },

    optimal = 1600, falloff = 2500,
    damage_range = { min = 22, max = 36 },
    cycle = 5.5, capCost = 10,
    maxRange = 3200,

    modifiers = {
        { type = "precision_barrel" }
    },

    upgrades = {
        thresholds = { 220, 520, 980 },
        bonuses = {
            [1] = { damageMultiplier = 1.1 },
            [2] = { homingBonus = math.rad(25) },
            [3] = { cycleMultiplier = 0.9 },
        }
    },
    -- Firing mode
    fireMode = "manual"
}
