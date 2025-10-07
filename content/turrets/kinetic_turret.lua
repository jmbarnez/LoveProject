return {
    id = "kinetic_turret",
    type = "gun",
    name = "Kinetic Turret",
    description = "Wind arc weapon that blasts ships in a wide cone with powerful kinetic force.",
    price = 1500,
    volume = 8,
    module = { type = "turret" },
    icon = {
        size = 32,
        shapes = {
            -- Main chassis
            { type = "polygon", mode = "fill", color = {0.15, 0.10, 0.20, 1}, points = {6, 24, 10, 8, 22, 8, 26, 24, 16, 28} },
            { type = "polygon", mode = "fill", color = {0.25, 0.20, 0.30, 1}, points = {8, 20, 12, 12, 20, 12, 24, 20, 16, 24} },
            -- Force emitter array
            { type = "rectangle", mode = "fill", color = {0.30, 0.25, 0.40, 1}, x = 10, y = 6, w = 12, h = 8, rx = 2 },
            { type = "rectangle", mode = "fill", color = {0.40, 0.35, 0.50, 1}, x = 12, y = 8, w = 8, h = 4, rx = 1 },
            -- Force field generator
            { type = "circle", mode = "fill", color = {0.20, 0.15, 0.25, 1}, x = 16, y = 4, r = 3 },
            { type = "circle", mode = "fill", color = {0.35, 0.30, 0.45, 1}, x = 16, y = 4, r = 1.5 },
            -- Energy conduits
            { type = "rectangle", mode = "fill", color = {0.35, 0.30, 0.45, 1}, x = 8, y = 14, w = 16, h = 4, rx = 1 },
            { type = "rectangle", mode = "fill", color = {0.45, 0.40, 0.55, 1}, x = 10, y = 15, w = 12, h = 2, rx = 0.5 },
            -- Power vents
            { type = "rectangle", mode = "fill", color = {0.25, 0.20, 0.35, 1}, x = 6, y = 10, w = 2, h = 8, rx = 1 },
            { type = "rectangle", mode = "fill", color = {0.25, 0.20, 0.35, 1}, x = 24, y = 10, w = 2, h = 8, rx = 1 },
        }
    },
    
    -- Embedded projectile definition
    projectile = {
        id = "kinetic_wave",
        name = "Kinetic Wave",
        class = "Projectile",
        physics = {
            speed = 600,
            drag = 0.05,
        },
        renderable = {
            type = "wave",
            props = {
                radius = 8,
                color = {0.5, 0.5, 0.5, 0.8}
            }
        },
        collidable = {
            radius = 8,
        },
        damage = {
            value = 15.0,
        },
        timed_life = {
            duration = 2.0,
        },
        -- Force wave effect component
        components = {
            {
                name = "force_wave",
                value = {
                    knockback_force = 500,
                    radius = 12,
                    duration = 0.5
                }
            }
        }
    },
    
    -- Visual effects
    tracer = { color = {0.6, 0.4, 0.8, 0.6}, width = 4, coreRadius = 6 },
    impact = {
        shield = { spanDeg = 90, color1 = {0.6, 0.4, 0.8, 0.8}, color2 = {0.4, 0.2, 0.6, 0.6} },
        hull = { spark = {0.6, 0.4, 0.8, 1.0}, ring = {0.4, 0.2, 0.6, 0.8} },
    },
    
    -- Weapon stats
    optimal = 400, falloff = 200,
    damage_range = { min = 12, max = 18 },
    damagePerSecond = 15,
    cycle = 2.0, capCost = 3,
    energyPerSecond = 5,
    maxRange = 600,
    spread = { minDeg = 0, maxDeg = 0, decay = 0 },
    
    -- Volley firing (single shot by default)
    volleyCount = 1,
    volleySpreadDeg = 0,
    
    -- Overheating parameters
    maxHeat = 120,
    heatPerShot = 20,
    cooldownRate = 8,
    overheatCooldown = 4.0,
    heatCycleMult = 0.9,
    heatEnergyMult = 1.2,
    
    -- Firing mode
    fireMode = "manual"
}