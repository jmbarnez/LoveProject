return {
    id = "kinetic_bombardment",
    type = "gun",
    name = "Kinetic Bombardment",
    description = "Orbital strike platform delivering devastating kinetic rods.",
    price = 4200,
    volume = 20,
    module = { type = "turret" },
    icon = nil,

    projectile = {
        id = "kinetic_rod",
        class = "Projectile",
        physics = { speed = 2000 },
        renderable = { renderer = "kinetic_bombardment", props = { radius = 7 } },
        damage = { value = 60 },
        collidable = { radius = 6 },
        timed_life = { duration = 3.5 },
        behaviors = {
            { type = "area_denial", radius = 160, duration = 3.0, damageMultiplier = 0.3, color = {1.0, 0.7, 0.3, 0.25} }
        },
        effects = {
            { type = "dynamic_light", radius = 38, color = {1.0, 0.8, 0.4, 0.8} },
            { type = "particle_emitter", type = "spark", interval = 0.05, speed = 220, color = {1.0, 0.7, 0.3, 0.8} }
        }
    },

    tracer = { color = {1.0, 0.8, 0.6, 1.0}, width = 3.0, coreRadius = 6 },
    impact = {
        shield = { spanDeg = 160, color1 = {1.0, 0.75, 0.4, 0.6}, color2 = {1.0, 0.6, 0.2, 0.4} },
        hull = { spark = {1.0, 0.7, 0.3, 1.0}, ring = {1.0, 0.6, 0.2, 0.6} }
    },

    optimal = 1500, falloff = 600,
    damage_range = { min = 52, max = 70 },
    cycle = 3.4, capCost = 18,
    maxRange = 2200,

    modifiers = {
        { type = "overcharged_coils" },
        { type = "capacitor_bank" }
    },

    upgrades = {
        thresholds = { 320, 680, 1280 },
        bonuses = {
            [1] = { damageMultiplier = 1.15 },
            [2] = { cycleMultiplier = 0.85 },
            [3] = { damageMultiplier = 1.1, projectileSpeed = 250 },
        }
    },
}
