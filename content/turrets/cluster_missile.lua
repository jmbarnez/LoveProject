return {
    id = "cluster_missile",
    type = "missile",
    name = "Cluster Missile",
    description = "Missiles that split into multiple warheads near the target.",
    price = 3400,
    volume = 16,
    module = { type = "turret" },
    icon = nil,

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
}
