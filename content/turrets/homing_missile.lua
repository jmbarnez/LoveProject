return {
    id = "homing_missile",
    type = "missile",
    name = "Homing Missile",
    description = "Agile missiles that relentlessly track their target.",
    price = 3000,
    volume = 14,
    module = { type = "turret" },
    icon = nil,

    projectile = {
        id = "homing_missile_round",
        class = "Projectile",
        physics = { speed = 1500 },
        renderable = { renderer = "homing_missile", props = { radius = 5 } },
        damage = { value = 28 },
        collidable = { radius = 5 },
        timed_life = { duration = 4.5 },
        behaviors = {
            { type = "homing", turnRate = math.rad(220), range = 2400, speed = 1500 }
        },
        effects = {
            { type = "dynamic_light", radius = 24, color = {0.6, 0.85, 1.0, 0.8} },
            { type = "particle_emitter", type = "spark", interval = 0.04, speed = 160, color = {0.6, 0.85, 1.0, 0.7} }
        }
    },

    tracer = { color = {0.6, 0.85, 1.0, 1.0}, width = 2.4, coreRadius = 4 },
    impact = {
        shield = { spanDeg = 100, color1 = {0.6, 0.9, 1.0, 0.5}, color2 = {0.5, 0.8, 1.0, 0.35} },
        hull = { spark = {0.5, 0.8, 1.0, 0.8}, ring = {0.3, 0.7, 1.0, 0.45} }
    },

    optimal = 1700, falloff = 2700,
    damage_range = { min = 24, max = 34 },
    cycle = 4.0, capCost = 9,
    maxRange = 3400,

    modifiers = {
        { type = "precision_barrel" },
        { type = "capacitor_bank" }
    },

    upgrades = {
        thresholds = { 200, 460, 920 },
        bonuses = {
            [1] = { homingBonus = math.rad(40) },
            [2] = { damageMultiplier = 1.08 },
            [3] = { cycleMultiplier = 0.88 },
        }
    },
}
