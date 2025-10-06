return {
    id = "fragmentation_launcher",
    type = "gun",
    name = "Fragmentation Launcher",
    description = "Shells that split into a burst of shrapnel on impact.",
    price = 2100,
    volume = 15,
    module = { type = "turret" },
    icon = nil,

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
}
