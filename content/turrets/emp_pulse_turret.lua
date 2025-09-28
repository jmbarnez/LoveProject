return {
    id = "emp_pulse_turret",
    type = "support",
    name = "EMP Pulse Projector",
    description = "Delivers wide electromagnetic pulses that disable shields and systems.",
    price = 2750,
    module = { type = "turret" },
    icon = {
        size = 32,
        shapes = {
            { type = "rectangle", mode = "fill", color = {0.05, 0.08, 0.12, 1}, x = 9, y = 11, w = 16, h = 15, rx = 3 },
            { type = "circle", mode = "fill", color = {0.15, 0.25, 0.38, 1}, x = 16, y = 18, r = 5 },
            { type = "circle", mode = "line", color = {0.00, 0.75, 1.00, 0.85}, x = 16, y = 8, r = 4, lineWidth = 2 },
            { type = "circle", mode = "line", color = {0.35, 0.90, 1.00, 0.75}, x = 16, y = 8, r = 6, lineWidth = 1.4 },
        }
    },
    spread = { minDeg = 0.3, maxDeg = 1.5, decay = 600 },
    
    -- Embedded projectile definition with EMP effects
    projectile = {
        id = "emp_pulse",
        name = "EMP Pulse",
        class = "Projectile",
        physics = {
            speed = 3200,
            drag = 0.02,
        },
        renderable = {
            type = "bullet",
            props = {
                kind = "pulse",
                radius = 3.0,
                color = {0.35, 0.90, 1.00, 0.85},
            }
        },
        damage = {
            value = 1.8,
            empStrength = { shield = 2.2, systems = 1.6, duration = 3.5 },
        },
        timed_life = {
            duration = 3.2,
        }
    },
    
    -- Visual effects
    tracer = { color = {0.35, 0.90, 1.00, 0.85}, width = 2.4, coreRadius = 3 },
    impact = {
        shield = { spanDeg = 120, color1 = {0.35, 0.90, 1.0, 0.7}, color2 = {0.15, 0.70, 1.0, 0.45} },
        hull = { spark = {0.40, 0.90, 1.0, 0.55}, ring = {0.20, 0.70, 1.0, 0.4} },
    },
    optimal = 1000,
    falloff = 1200,
    damage_range = { min = 1, max = 2 },
    cycle = 3.2,
    capCost = 6,
    projectileSpeed = 3200,
    maxRange = 2000,
    empStrength = { shield = 2.2, systems = 1.6, duration = 3.5 },
    maxHeat = 90,
    heatPerShot = 15,
    cooldownRate = 18,
    overheatCooldown = 5.0,
    heatCycleMult = 0.6,
    heatEnergyMult = 1.3,
    fireMode = "manual"
}
