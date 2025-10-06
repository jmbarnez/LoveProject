return {
    id = "tesla_coil",
    type = "gun",
    name = "Tesla Coil",
    description = "Fires arcing bolts that leap between enemies.",
    price = 2800,
    volume = 14,
    module = { type = "turret" },
    icon = nil,

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
