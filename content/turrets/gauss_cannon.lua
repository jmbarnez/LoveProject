return {
    id = "gauss_cannon",
    type = "gun",
    name = "Gauss Cannon",
    description = "Magnetically accelerated rounds with high penetration.",
    price = 2400,
    volume = 14,
    module = { type = "turret" },
    icon = nil,

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
