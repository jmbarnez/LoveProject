return {
    id = "particle_beam",
    type = "laser",
    name = "Particle Beam",
    description = "Continuous beam that pierces multiple targets.",
    price = 3800,
    volume = 12,
    module = { type = "turret" },
    icon = nil,

    projectile = {
        id = "particle_beam_projectile",
        class = "Projectile",
        physics = { speed = 0 },
        renderable = { renderer = "particle_beam", props = { length = 1000 } },
        damage = { value = 55 },
        collidable = { radius = 3 },
        timed_life = { duration = 0.25 },
        effects = {
            { type = "dynamic_light", radius = 40, color = {0.6, 0.9, 1.0, 0.7} }
        }
    },

    tracer = { color = {0.6, 0.9, 1.0, 0.85}, width = 3, coreRadius = 3 },
    impact = {
        shield = { spanDeg = 80, color1 = {0.6, 0.9, 1.0, 0.6}, color2 = {0.4, 0.7, 1.0, 0.4} },
        hull = { spark = {0.6, 0.9, 1.0, 0.8}, ring = {0.4, 0.7, 1.0, 0.5} }
    },

    optimal = 1000, falloff = 600,
    damage_range = { min = 50, max = 50 },
    damagePerSecond = 50,
    cycle = 2.6, capCost = 12,
    energyPerSecond = 60,
    maxRange = 1500,

    modifiers = {
        { type = "capacitor_bank" }
    },

    upgrades = {
        thresholds = { 240, 520, 980 },
        bonuses = {
            [1] = { damageMultiplier = 1.1 },
            [2] = { cycleMultiplier = 0.9 },
            [3] = { damageMultiplier = 1.05, cycleMultiplier = 0.9 },
        }
    },
}
