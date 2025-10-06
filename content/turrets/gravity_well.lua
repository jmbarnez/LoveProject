return {
    id = "gravity_well",
    type = "gun",
    name = "Gravity Well",
    description = "Launches a slow orb that pulls enemies inward and deals sustained damage.",
    price = 3200,
    volume = 16,
    module = { type = "turret" },
    icon = nil,

    projectile = {
        id = "gravity_well_orb",
        class = "Projectile",
        physics = { speed = 900 },
        renderable = { renderer = "gravity_well", props = { radius = 10 } },
        damage = { value = 10 },
        collidable = { radius = 10 },
        timed_life = { duration = 4.5 },
        behaviors = {
            { type = "area_denial", radius = 200, duration = 4.0, damageMultiplier = 0.2, color = {0.45, 0.2, 1.0, 0.3} }
        },
        effects = {
            { type = "dynamic_light", radius = 42, color = {0.5, 0.3, 1.0, 0.7}, pulse = { min = 0.7, max = 1.2, speed = 2.0 } },
            { type = "particle_emitter", type = "smoke", interval = 0.07, speed = 40, color = {0.5, 0.3, 1.0, 0.4} }
        }
    },

    tracer = { color = {0.5, 0.3, 1.0, 0.7}, width = 2.0, coreRadius = 6 },
    impact = {
        shield = { spanDeg = 140, color1 = {0.6, 0.4, 1.0, 0.5}, color2 = {0.4, 0.2, 0.9, 0.35} },
        hull = { spark = {0.6, 0.3, 1.0, 0.7}, ring = {0.3, 0.1, 0.6, 0.4} }
    },

    optimal = 600, falloff = 800,
    damage_range = { min = 8, max = 12 },
    cycle = 2.8, capCost = 16,
    maxRange = 1500,

    modifiers = {
        { type = "vented_housing" }
    },

    upgrades = {
        thresholds = { 220, 520, 1020 },
        bonuses = {
            [1] = { damageMultiplier = 1.2 },
            [2] = { cycleMultiplier = 0.9 },
            [3] = { projectileSpeed = 120 },
        }
    },
}
