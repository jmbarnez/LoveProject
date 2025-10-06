return {
    id = "disruptor_beam",
    type = "laser",
    name = "Disruptor Beam",
    description = "High-frequency beam tuned to strip shields rapidly.",
    price = 4200,
    volume = 12,
    module = { type = "turret" },
    icon = nil,

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
