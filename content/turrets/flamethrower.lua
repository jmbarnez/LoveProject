return {
    id = "plasma_torch",
    type = "plasma_torch",
    name = "Plasma Torch",
    description = "Close-range area denial weapon that projects superheated plasma streams. Devastating against groups but requires close proximity and generates massive heat.",
    price = 800,
    volume = 6,
    module = { type = "turret" },
    icon = {
        size = 32,
        shapes = {
            -- Main chassis - industrial design
            { type = "polygon", mode = "fill", color = {0.15, 0.10, 0.08, 1}, points = {5, 26, 8, 8, 24, 8, 27, 26, 16, 30} },
            { type = "polygon", mode = "fill", color = {0.25, 0.18, 0.15, 1}, points = {7, 22, 10, 12, 22, 12, 25, 22, 16, 26} },
            
            -- Fuel tank
            { type = "rectangle", mode = "fill", color = {0.20, 0.15, 0.12, 1}, x = 9, y = 12, w = 14, h = 6, rx = 2 },
            { type = "rectangle", mode = "fill", color = {0.35, 0.25, 0.20, 0.9}, x = 10, y = 13, w = 12, h = 4, rx = 1 },
            
            -- Flame nozzle
            { type = "circle", mode = "fill", color = {0.12, 0.08, 0.06, 1}, x = 16, y = 6, r = 5 },
            { type = "circle", mode = "fill", color = {0.25, 0.15, 0.10, 0.9}, x = 16, y = 6, r = 3.5 },
            { type = "circle", mode = "fill", color = {0.40, 0.20, 0.15, 0.8}, x = 16, y = 6, r = 2.5 },
            
            -- Fuel lines
            { type = "rectangle", mode = "fill", color = {0.30, 0.20, 0.15, 1}, x = 12, y = 18, w = 8, h = 2, rx = 1 },
            { type = "rectangle", mode = "fill", color = {0.50, 0.35, 0.25, 0.8}, x = 13, y = 19, w = 6, h = 1, rx = 0.5 },
            
            -- Ignition system
            { type = "circle", mode = "fill", color = {0.8, 0.4, 0.1, 1}, x = 11, y = 15, r = 2 },
            { type = "circle", mode = "fill", color = {0.8, 0.4, 0.1, 1}, x = 21, y = 15, r = 2 },
            { type = "circle", mode = "fill", color = {1.0, 0.6, 0.2, 0.9}, x = 11, y = 15, r = 1.2 },
            { type = "circle", mode = "fill", color = {1.0, 0.6, 0.2, 0.9}, x = 21, y = 15, r = 1.2 },
            
            -- Heat vents
            { type = "rectangle", mode = "fill", color = {0.40, 0.25, 0.20, 1}, x = 8, y = 20, w = 3, h = 2, rx = 0.5 },
            { type = "rectangle", mode = "fill", color = {0.40, 0.25, 0.20, 1}, x = 21, y = 20, w = 3, h = 2, rx = 0.5 },
            
            -- Flame pattern on nozzle
            { type = "polygon", mode = "fill", color = {1.0, 0.5, 0.1, 0.8}, points = {16, 2, 18, 4, 16, 6, 14, 4} },
            { type = "polygon", mode = "fill", color = {1.0, 0.7, 0.3, 0.6}, points = {16, 3, 17, 4, 16, 5, 15, 4} },
        }
    },
    
    -- Embedded projectile definition
    projectile = {
        id = "plasma_torch_beam",
        name = "Plasma Torch Beam",
        class = "Projectile",
        physics = {
            speed = 0, -- Hitscan beam
            drag = 0,
        },
        renderable = {
            type = "bullet",
            props = {
                kind = "plasma_torch",
                length = 400, -- Short range beam
                tracerWidth = 8,
                color = {1.0, 0.4, 0.1, 0.9},
            }
        },
        collidable = {
            radius = 8, -- Wide beam
        },
        damage = {
            value = 12.0, -- Moderate damage per tick
        },
        timed_life = {
            duration = 0.1, -- Short beam duration
        },
        charged_pulse = {
            buildup_time = 0.05,
            flash_time = 0.08,
        }
    },
    
    -- Visual effects
    tracer = { 
        color = {1.0, 0.4, 0.1, 0.9}, 
        width = 8, 
        coreRadius = 6,
    },
    impact = {
        shield = { 
            spanDeg = 100, 
            color1 = {1.0, 0.6, 0.2, 0.8}, 
            color2 = {1.0, 0.4, 0.1, 0.6},
            flame = true,
            heat = true,
        },
        hull = { 
            spark = {1.0, 0.5, 0.1, 0.9}, 
            ring = {1.0, 0.3, 0.0, 0.7},
            flame = true,
            heat = true,
        },
    },
    
    -- Weapon stats
    optimal = 300, -- Very close range
    falloff = 100,
    damage_range = { min = 10, max = 15 },
    damagePerSecond = 30, -- High DPS due to continuous beam
    cycle = 0.2, -- Very fast firing rate
    capCost = 0, -- No per-shot energy cost
    energyPerSecond = 60, -- High energy consumption while active
    maxRange = 400, -- Short range
    spread = { minDeg = 0.0, maxDeg = 0.0, decay = 300 }, -- Precise beam
    
    -- Volley firing (single shot by default)
    volleyCount = 1,
    volleySpreadDeg = 0,
    
    -- Overheating parameters
    maxHeat = 150, -- Very high heat generation
    heatPerShot = 25, -- Moderate heat per shot
    cooldownRate = 3, -- Slow cooldown
    overheatCooldown = 8.0, -- Long cooldown period
    heatCycleMult = 0.8, -- Heat affects cycle time
    heatEnergyMult = 1.2, -- Heat increases energy consumption
    
    -- Plasma Torch-specific properties
    plasma_system = {
        fuel_consumption = 0.8, -- Plasma fuel efficiency
        heat_generation = 1.5, -- Heat generation multiplier
        plasma_intensity = 0.9, -- Plasma damage multiplier
        area_coverage = 1.2, -- Area of effect multiplier
        thermal_damage_chance = 0.15, -- Chance for thermal damage over time
    },
    
    -- Firing mode
    fireMode = "manual"
}
