return {
    id = "kinetic_turret",
    type = "gun",
    name = "Kinetic Turret",
    description = "Electromagnetic turret that launches dense sabot penetrators with extreme muzzle velocity.",
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
            speed = 1150,
            drag = 0.01,
        },
        renderable = {
            type = "bullet",
            props = {
                kind = "gauss",
                radius = 4,
                color = {0.92, 0.82, 0.58, 1.0},
                streak = {
                    length = 26,
                    width = 2.4,
                    color = {1.0, 0.86, 0.42, 0.75}
                }
            }
        },
        collidable = {
            radius = 4,
        },
        damage = {
            value = 18.0,
        },
        timed_life = {
            duration = 2.4,
        },
        components = {
            {
                name = "ballistics",
                value = {
                    projectile_mass = 2.8, -- kilograms for the sabot penetrator
                    caliber_mm = 45,
                    muzzle_velocity = 1150, -- meters per second
                    muzzle_energy = 0.5 * 2.8 * 1150 * 1150, -- ≈1.85 MJ per shot
                    impulse_transfer = 0.42, -- scales how much impulse hits targets
                    displacement_scale = 0.00045, -- converts impulse into positional shove when no rigid body exists
                    restitution = 0.15,
                }
            }
        }
    },

    -- Visual effects
    tracer = { color = {0.9, 0.8, 0.6, 0.8}, width = 2.4, coreRadius = 5 },
    impact = {
        shield = { spanDeg = 70, color1 = {0.9, 0.8, 0.6, 0.7}, color2 = {0.7, 0.6, 0.4, 0.5} },
        hull = { spark = {1.0, 0.85, 0.55, 1.0}, ring = {0.8, 0.6, 0.3, 0.8} },
    },

    -- Weapon stats
    optimal = 550, falloff = 250,
    damage_range = { min = 16, max = 22 },
    damagePerSecond = 18,
    cycle = 1.8, capCost = 4,
    energyPerSecond = 8,
    maxRange = 700,
    spread = { minDeg = 0.3, maxDeg = 1.0, decay = 260 },
    
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
