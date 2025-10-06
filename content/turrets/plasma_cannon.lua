return {
    id = "plasma_cannon",
    type = "gun",
    name = "Plasma Cannon",
    description = "Advanced energy weapon that fires superheated plasma bolts. Effective against shields and creates devastating electric discharge effects.",
    price = 1200,
    volume = 8,
    module = { type = "turret" },
    icon = {
        size = 32,
        shapes = {
            -- Main chassis - sleek futuristic design
            { type = "polygon", mode = "fill", color = {0.12, 0.08, 0.15, 1}, points = {4, 26, 8, 8, 24, 8, 28, 26, 16, 30} },
            { type = "polygon", mode = "fill", color = {0.22, 0.18, 0.25, 1}, points = {6, 22, 10, 12, 22, 12, 26, 22, 16, 26} },
            
            -- Plasma containment chamber
            { type = "rectangle", mode = "fill", color = {0.3, 0.1, 0.4, 1}, x = 9, y = 12, w = 14, h = 6, rx = 2 },
            { type = "rectangle", mode = "fill", color = {0.5, 0.2, 0.6, 0.9}, x = 10, y = 13, w = 12, h = 4, rx = 1 },
            
            -- Plasma emitter array
            { type = "circle", mode = "fill", color = {0.2, 0.05, 0.3, 1}, x = 16, y = 6, r = 6 },
            { type = "circle", mode = "fill", color = {0.6, 0.1, 0.8, 0.95}, x = 16, y = 6, r = 4 },
            { type = "circle", mode = "fill", color = {0.9, 0.3, 1.0, 0.8}, x = 16, y = 6, r = 2.5 },
            { type = "circle", mode = "fill", color = {1.0, 0.8, 1.0, 0.6}, x = 16, y = 6, r = 1.2 },
            
            -- Energy conduits
            { type = "rectangle", mode = "fill", color = {0.4, 0.2, 0.5, 1}, x = 12, y = 18, w = 8, h = 2, rx = 1 },
            { type = "rectangle", mode = "fill", color = {0.6, 0.3, 0.7, 0.8}, x = 13, y = 19, w = 6, h = 1, rx = 0.5 },
            
            -- Electric discharge nodes
            { type = "circle", mode = "fill", color = {0.7, 0.4, 0.9, 0.9}, x = 11, y = 15, r = 1.5 },
            { type = "circle", mode = "fill", color = {0.7, 0.4, 0.9, 0.9}, x = 21, y = 15, r = 1.5 },
            { type = "circle", mode = "fill", color = {0.9, 0.6, 1.0, 0.7}, x = 11, y = 15, r = 0.8 },
            { type = "circle", mode = "fill", color = {0.9, 0.6, 1.0, 0.7}, x = 21, y = 15, r = 0.8 },
        }
    },
    
    -- Embedded projectile definition
    projectile = {
        id = "plasma_bolt",
        name = "Plasma Bolt",
        class = "Projectile",
        physics = {
            speed = 1800,
            drag = 0.015,
            acceleration = 50,
        },
        renderable = {
            type = "bullet",
            props = {
                kind = "plasma",
                radius = 4,
                color = {0.8, 0.3, 1.0, 1.0},
                glowRadius = 8,
            }
        },
        collidable = {
            radius = 4,
        },
        damage = {
            value = 35.0,
        },
        timed_life = {
            duration = 3.0,
        },
        -- Electric discharge effect on impact
        electric_discharge = {
            radius = 40,
            damage = 15,
            chain_targets = 2,
            chain_range = 60,
            effect_duration = 0.3,
        },
        -- Plasma trail effect
        plasma_trail = {
            length = 30,
            width = 3,
            color = {0.7, 0.2, 0.9, 0.8},
            fade_time = 0.5,
        }
    },
    
    -- Visual effects
    tracer = { 
        color = {0.8, 0.3, 1.0, 1.0}, 
        width = 4, 
        coreRadius = 3,
        glow = true,
        glowColor = {0.9, 0.4, 1.0, 0.4},
        glowWidth = 8,
    },
    impact = {
        shield = { 
            spanDeg = 85, 
            color1 = {0.8, 0.3, 1.0, 0.7}, 
            color2 = {0.6, 0.1, 0.8, 0.5},
            electric = true,
        },
        hull = { 
            spark = {0.9, 0.4, 1.0, 0.9}, 
            ring = {0.7, 0.2, 0.9, 0.7},
            electric = true,
        },
    },
    
    -- Weapon stats
    optimal = 1000, 
    falloff = 800,
    damage_range = { min = 30, max = 40 },
    damagePerSecond = 25,
    cycle = 1.4, 
    capCost = 3,
    energyPerSecond = 35,
    maxRange = 1800,
    spread = { minDeg = 0.2, maxDeg = 1.0, decay = 500 },
    
    -- Volley firing (single shot by default)
    volleyCount = 1,
    volleySpreadDeg = 0,
    
    -- Overheating parameters
    maxHeat = 100,
    heatPerShot = 45,
    cooldownRate = 8,
    overheatCooldown = 4.5,
    heatCycleMult = 0.7,
    heatEnergyMult = 1.3,
    
    -- Plasma-specific properties
    plasma_containment = {
        stability = 0.85, -- Chance to maintain plasma integrity
        discharge_chance = 0.15, -- Chance for electric discharge
        energy_efficiency = 0.9, -- Energy conversion efficiency
    },
    
    -- Firing mode
    fireMode = "manual"
}
