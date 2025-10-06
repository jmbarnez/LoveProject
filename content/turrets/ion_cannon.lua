return {
    id = "ion_cannon",
    type = "gun",
    name = "Ion Cannon",
    description = "Precision energy weapon that disables systems and leaves an ionized field.",
    price = 2200,
    volume = 12,
    module = { type = "turret" },
    icon = nil,

    projectile = {
        id = "ion_bolt",
        class = "Projectile",
        physics = { speed = 1800 },
        renderable = {
            renderer = "ion",
            props = { radius = 6 }
        },
        damage = { value = 24 },
        collidable = { radius = 6 },
        timed_life = { duration = 3.5 },
        behaviors = {
            { type = "homing", turnRate = math.rad(180), range = 1000 },
            { type = "area_denial", radius = 140, duration = 2.5, damageMultiplier = 0.25, color = {0.35, 0.9, 1.0, 0.25} }
        },
        effects = {
            { type = "dynamic_light", radius = 32, color = {0.4, 0.9, 1.0, 0.8} },
            { type = "particle_emitter", type = "spark", interval = 0.05, speed = 80, color = {0.5, 0.9, 1.0, 0.7} }
        }
    },

    tracer = { color = {0.5, 0.9, 1.0, 1.0}, width = 3, coreRadius = 4 },
    impact = {
        shield = { spanDeg = 110, color1 = {0.4, 0.9, 1.0, 0.6}, color2 = {0.3, 0.8, 1.0, 0.4} },
        hull = { spark = {0.6, 0.9, 1.0, 0.8}, ring = {0.3, 0.8, 1.0, 0.5} }
    },

    optimal = 900, falloff = 400,
    damage_range = { min = 18, max = 26 },
    cycle = 1.6, capCost = 14,
    maxRange = 1400,

    modifiers = {
        { type = "overcharged_coils" },
        { type = "capacitor_bank" }
    },

    upgrades = {
        thresholds = { 200, 450, 900 },
        bonuses = {
            [1] = { damageMultiplier = 1.1 },
            [2] = { cycleMultiplier = 0.9 },
            [3] = { homingBonus = math.rad(45) },
        }
    },
}
