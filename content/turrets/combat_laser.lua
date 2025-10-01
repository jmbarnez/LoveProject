return {
    id = "combat_laser",
    type = "laser",
    name = "Combat Laser",
    description = "Military-grade energy beam tuned for close to mid-range dogfights.",
    price = 900,
    module = { type = "turret" },
    icon = {
        size = 32,
        shapes = {
            { type = "polygon", mode = "fill", color = {0.09, 0.12, 0.18, 1}, points = {6, 24, 10, 10, 22, 10, 26, 24, 16, 30} },
            { type = "polygon", mode = "fill", color = {0.18, 0.26, 0.36, 1}, points = {8, 20, 12, 13, 20, 13, 24, 20, 16, 26} },
            { type = "rectangle", mode = "fill", color = {0.05, 0.45, 0.70, 1}, x = 11, y = 14, w = 10, h = 3, rx = 1 },
            { type = "rectangle", mode = "fill", color = {0.05, 0.55, 0.85, 0.9}, x = 12, y = 18, w = 8, h = 2, rx = 1 },
            { type = "circle", mode = "fill", color = {0.08, 0.25, 0.45, 1}, x = 16, y = 8, r = 5 },
            { type = "circle", mode = "fill", color = {0.20, 0.75, 1.00, 0.95}, x = 16, y = 8, r = 3.2 },
            { type = "circle", mode = "fill", color = {0.70, 1.00, 1.00, 0.8}, x = 16, y = 8, r = 1.6 },
        }
    },
    spread = { minDeg = 0.0, maxDeg = 0.0, decay = 900 },
    projectile = {
        id = "combat_laser_beam",
        name = "Combat Laser Beam",
        class = "Projectile",
        physics = {
            speed = 0,
            drag = 0,
        },
        renderable = {
            type = "bullet",
            props = {
                kind = "laser",
                length = 900,
                tracerWidth = 4,
                color = {0.4, 0.85, 1.0, 0.95},
            }
        },
        collidable = {
            radius = 3,
        },
        damage = {
            min = 2,
            max = 3,
        },
        timed_life = {
            duration = 0.16,
        },
        charged_pulse = {
            buildup_time = 0.1,
            flash_time = 0.08,
        }
    },
    tracer = { color = {0.4, 0.85, 1.0, 0.9}, width = 3, coreRadius = 2 },
    impact = {
        shield = { spanDeg = 85, color1 = {0.3, 0.7, 1.0, 0.6}, color2 = {0.2, 0.5, 1.0, 0.45} },
        hull = { spark = {0.4, 0.8, 1.0, 0.6}, ring = {0.2, 0.6, 0.9, 0.45} },
    },
    optimal = 750,
    falloff = 400,
    damage_range = { min = 2, max = 3 },
    cycle = 1.4,
    capCost = 4,
    maxRange = 1100,
    maxHeat = 85,
    heatPerShot = 12,
    cooldownRate = 24,
    overheatCooldown = 3.2,
    heatCycleMult = 0.85,
    heatEnergyMult = 1.05,
    fireMode = "automatic",
}
