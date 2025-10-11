return {
    id = "railgun_turret",
    type = "gun",
    name = "Railgun Turret",
    description = "Electromagnetic railgun firing high-velocity solid projectiles.",
    price = 1200,
    volume = 6,
    module = { type = "turret" },
    icon = {
        size = 32,
        shapes = {
            -- Main chassis
            { type = "polygon", mode = "fill", color = {0.12, 0.14, 0.18, 1}, points = {6, 24, 10, 8, 22, 8, 26, 24, 16, 28} },
            { type = "polygon", mode = "fill", color = {0.20, 0.24, 0.30, 1}, points = {8, 20, 12, 12, 20, 12, 24, 20, 16, 24} },
            -- Barrel assembly
            { type = "rectangle", mode = "fill", color = {0.25, 0.30, 0.35, 1}, x = 12, y = 6, w = 8, h = 6, rx = 1 },
            { type = "rectangle", mode = "fill", color = {0.35, 0.40, 0.45, 1}, x = 13, y = 7, w = 6, h = 4, rx = 0.5 },
            -- Barrel tip
            { type = "circle", mode = "fill", color = {0.15, 0.18, 0.22, 1}, x = 16, y = 4, r = 2 },
            { type = "circle", mode = "fill", color = {0.25, 0.28, 0.32, 1}, x = 16, y = 4, r = 1.2 },
            -- Ammo feed
            { type = "rectangle", mode = "fill", color = {0.30, 0.35, 0.40, 1}, x = 8, y = 14, w = 16, h = 4, rx = 1 },
            { type = "rectangle", mode = "fill", color = {0.40, 0.45, 0.50, 1}, x = 10, y = 15, w = 12, h = 2, rx = 0.5 },
            -- Heat vents
            { type = "rectangle", mode = "fill", color = {0.20, 0.25, 0.30, 1}, x = 6, y = 10, w = 2, h = 8, rx = 1 },
            { type = "rectangle", mode = "fill", color = {0.20, 0.25, 0.30, 1}, x = 24, y = 10, w = 2, h = 8, rx = 1 },
        }
    },
    
    -- Embedded projectile definition
    projectile = {
        id = "railgun_slug",
        name = "Railgun Slug",
        class = "Projectile",
        physics = {
            speed = 2000,
            drag = 0.01,
        },
        renderable = {
            type = "bullet",
            props = {
                kind = "bullet",
                radius = 2,
                length = 8,
                color = {0.8, 0.8, 0.9, 1.0}
            }
        },
            collidable = {
                shape = "polygon",
                vertices = {
                    -2, -1,  -- Top-left
                    -1, -2,  -- Left
                    1, -2,   -- Left
                    2, -1,   -- Top-right
                    2, 1,    -- Right
                    1, 2,    -- Bottom-right
                    -1, 2,   -- Bottom-left
                    -2, 1,   -- Bottom-left
                }
            },
        damage = {
            value = 25.0,
        },
        timed_life = {
            duration = 3.0,
        }
    },
    
    -- Visual effects
    tracer = { color = {0.8, 0.8, 0.9, 1.0}, width = 2, coreRadius = 3 },
    impact = {
        shield = { spanDeg = 60, color1 = {0.8, 0.8, 0.9, 0.6}, color2 = {0.6, 0.6, 0.7, 0.4} },
        hull = { spark = {0.8, 0.8, 0.9, 0.8}, ring = {0.6, 0.6, 0.7, 0.6} },
    },
    
    -- Weapon stats
    optimal = 600, falloff = 300,
    damage_range = { min = 20, max = 30 },
    damagePerSecond = 25,
    cycle = 1.2, capCost = 2,
    energyPerSecond = 0,
    maxRange = 1000,
    spread = { minDeg = 0.5, maxDeg = 1.5, decay = 400 },
    
    -- Volley firing (single shot by default)
    volleyCount = 1,
    volleySpreadDeg = 0,
    
    -- Overheating parameters
    maxHeat = 100,
    cooldownRate = 12,
    overheatCooldown = 3.0,
    heatCycleMult = 0.8,
    heatEnergyMult = 1.0,
    
    -- Firing mode
    fireMode = "manual",
    
    -- Level properties
    level = 1,
    maxLevel = 5
}
