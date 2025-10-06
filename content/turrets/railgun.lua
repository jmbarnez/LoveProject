return {
    id = "railgun",
    type = "gun",
    name = "Railgun",
    description = "High-velocity electromagnetic weapon that fires hypervelocity projectiles. Devastating damage at extreme range with massive energy consumption.",
    price = 2500,
    volume = 12,
    module = { type = "turret" },
    icon = {
        size = 32,
        shapes = {
            -- Main chassis - heavy military design
            { type = "polygon", mode = "fill", color = {0.08, 0.10, 0.12, 1}, points = {3, 28, 6, 6, 26, 6, 29, 28, 16, 32} },
            { type = "polygon", mode = "fill", color = {0.18, 0.22, 0.26, 1}, points = {5, 24, 8, 10, 24, 10, 27, 24, 16, 28} },
            
            -- Electromagnetic rail system
            { type = "rectangle", mode = "fill", color = {0.15, 0.20, 0.30, 1}, x = 7, y = 10, w = 18, h = 4, rx = 1 },
            { type = "rectangle", mode = "fill", color = {0.25, 0.35, 0.50, 0.9}, x = 8, y = 11, w = 16, h = 2, rx = 0.5 },
            
            -- Railgun barrel - long and sleek
            { type = "rectangle", mode = "fill", color = {0.20, 0.25, 0.35, 1}, x = 14, y = 6, w = 4, h = 16, rx = 1 },
            { type = "rectangle", mode = "fill", color = {0.40, 0.50, 0.70, 0.8}, x = 15, y = 7, w = 2, h = 14, rx = 0.5 },
            
            -- Electromagnetic coils
            { type = "circle", mode = "fill", color = {0.10, 0.15, 0.25, 1}, x = 12, y = 12, r = 3 },
            { type = "circle", mode = "fill", color = {0.10, 0.15, 0.25, 1}, x = 20, y = 12, r = 3 },
            { type = "circle", mode = "fill", color = {0.30, 0.45, 0.70, 0.9}, x = 12, y = 12, r = 2 },
            { type = "circle", mode = "fill", color = {0.30, 0.45, 0.70, 0.9}, x = 20, y = 12, r = 2 },
            
            -- Power capacitors
            { type = "rectangle", mode = "fill", color = {0.12, 0.18, 0.28, 1}, x = 9, y = 16, w = 6, h = 4, rx = 1 },
            { type = "rectangle", mode = "fill", color = {0.12, 0.18, 0.28, 1}, x = 17, y = 16, w = 6, h = 4, rx = 1 },
            { type = "rectangle", mode = "fill", color = {0.25, 0.40, 0.65, 0.8}, x = 10, y = 17, w = 4, h = 2, rx = 0.5 },
            { type = "rectangle", mode = "fill", color = {0.25, 0.40, 0.65, 0.8}, x = 18, y = 17, w = 4, h = 2, rx = 0.5 },
            
            -- Muzzle brake
            { type = "polygon", mode = "fill", color = {0.35, 0.45, 0.60, 1}, points = {16, 4, 18, 6, 16, 8, 14, 6} },
            { type = "polygon", mode = "fill", color = {0.50, 0.65, 0.85, 0.9}, points = {16, 5, 17, 6, 16, 7, 15, 6} },
            
            -- Targeting systems
            { type = "circle", mode = "fill", color = {0.00, 0.80, 1.00, 0.8}, x = 10, y = 14, r = 1 },
            { type = "circle", mode = "fill", color = {0.00, 0.80, 1.00, 0.8}, x = 22, y = 14, r = 1 },
        }
    },
    
    -- Embedded projectile definition
    projectile = {
        id = "railgun_slug",
        name = "Hypervelocity Slug",
        class = "Projectile",
        physics = {
            speed = 4000, -- Extremely high velocity
            drag = 0.005, -- Minimal drag due to high velocity
            acceleration = 100, -- Slight acceleration from magnetic field
        },
        renderable = {
            type = "bullet",
            props = {
                kind = "railgun",
                radius = 2,
                color = {0.6, 0.8, 1.0, 1.0},
                trailLength = 20,
            }
        },
        collidable = {
            radius = 2,
        },
        damage = {
            value = 80.0, -- Very high damage
        },
        timed_life = {
            duration = 4.0, -- Long range
        },
        -- Penetration effect - can pierce through multiple targets
        penetration = {
            max_targets = 3,
            damage_reduction = 0.8, -- 20% damage reduction per target
            pierce_through = true,
        },
        -- Electromagnetic discharge on impact
        electromagnetic_discharge = {
            radius = 30,
            damage = 25,
            emp_effect = true, -- Disables enemy systems briefly
            effect_duration = 1.0,
        },
        -- Sonic boom effect
        sonic_boom = {
            radius = 80,
            damage = 10,
            stun_duration = 0.5,
        }
    },
    
    -- Visual effects
    tracer = { 
        color = {0.6, 0.8, 1.0, 1.0}, 
        width = 2, 
        coreRadius = 2,
        glow = true,
        glowColor = {0.4, 0.6, 1.0, 0.6},
        glowWidth = 6,
        trail = true,
        trailLength = 50,
        trailColor = {0.3, 0.5, 0.9, 0.4},
    },
    impact = {
        shield = { 
            spanDeg = 95, 
            color1 = {0.4, 0.6, 1.0, 0.8}, 
            color2 = {0.2, 0.4, 0.8, 0.6},
            electric = true,
            emp = true,
        },
        hull = { 
            spark = {0.6, 0.8, 1.0, 1.0}, 
            ring = {0.4, 0.6, 1.0, 0.8},
            electric = true,
            penetration = true,
        },
    },
    
    -- Weapon stats
    optimal = 2000, -- Very long range
    falloff = 1500,
    damage_range = { min = 70, max = 90 },
    damagePerSecond = 35, -- High DPS due to high damage
    cycle = 2.3, -- Slow firing rate
    capCost = 8, -- High energy cost per shot
    energyPerSecond = 60, -- High energy consumption
    maxRange = 3000, -- Extreme range
    spread = { minDeg = 0.05, maxDeg = 0.3, decay = 1000 }, -- Very accurate
    
    -- Volley firing (single shot by default)
    volleyCount = 1,
    volleySpreadDeg = 0,
    
    -- Overheating parameters
    maxHeat = 120,
    heatPerShot = 80, -- High heat generation
    cooldownRate = 5, -- Slower cooldown
    overheatCooldown = 6.0,
    heatCycleMult = 0.5, -- Heat significantly affects cycle time
    heatEnergyMult = 1.6, -- Heat increases energy consumption
    
    -- Railgun-specific properties
    electromagnetic_system = {
        charge_time = 0.3, -- Time to charge before firing
        magnetic_field_strength = 0.95, -- Affects projectile velocity
        energy_efficiency = 0.75, -- Energy conversion efficiency
        cooling_required = true, -- Requires active cooling
    },
    
    -- Firing mode
    fireMode = "manual"
}
