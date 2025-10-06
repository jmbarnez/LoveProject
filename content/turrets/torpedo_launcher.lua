return {
    id = "torpedo_launcher",
    type = "missile",
    name = "Torpedo Launcher",
    description = "Slow, heavy torpedo with massive hull damage.",
    price = 3600,
    volume = 18,
    module = { type = "turret" },
    icon = nil,

    projectile = {
        id = "torpedo_round",
        class = "Projectile",
        physics = { speed = 900 },
        renderable = { renderer = "torpedo", props = { radius = 6, length = 32 } },
        damage = { value = 48 },
        collidable = { radius = 6 },
        timed_life = { duration = 6.0 },
        behaviors = {
            { type = "homing", turnRate = math.rad(90), range = 2200, speed = 900 }
        },
        effects = {
            { type = "dynamic_light", radius = 34, color = {1.0, 0.6, 0.2, 0.8} },
            { type = "particle_emitter", type = "smoke", interval = 0.05, speed = 90, color = {1.0, 0.5, 0.2, 0.6} }
        }
    },

    tracer = { color = {1.0, 0.6, 0.2, 1.0}, width = 3.4, coreRadius = 5 },
    impact = {
        shield = { spanDeg = 120, color1 = {1.0, 0.6, 0.2, 0.6}, color2 = {1.0, 0.5, 0.2, 0.4} },
        hull = { spark = {1.0, 0.5, 0.1, 0.9}, ring = {1.0, 0.3, 0.0, 0.6} }
    },

    optimal = 1800, falloff = 2800,
    damage_range = { min = 40, max = 56 },
    cycle = 7.0, capCost = 12,
    maxRange = 3600,

    modifiers = {
        { type = "capacitor_bank" }
    },

    upgrades = {
        thresholds = { 260, 560, 1120 },
        bonuses = {
            [1] = { damageMultiplier = 1.12 },
            [2] = { homingBonus = math.rad(35) },
            [3] = { cycleMultiplier = 0.85 },
        }
    },
}
