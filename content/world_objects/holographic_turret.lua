return {
    id = "holographic_turret",
    name = "Holographic Turret",
    type = "utility_station",
    
    -- Construction requirements
    construction = {
        cost = { energy = 50 },
        buildTime = 3, -- seconds
        size = { width = 32, height = 32 }
    },
    
    -- Visual properties
    visuals = {
        size = 1.0,
        hullColor = {0.2, 0.8, 1.0, 0.8}, -- Cyan with transparency
        panelColor = {0.1, 0.6, 0.9, 0.6},
        accentColor = {0.0, 1.0, 1.0, 1.0},
        shapes = {
            -- Base platform
            { type = "circle", mode = "fill", color = {0.2, 0.8, 1.0, 0.3}, x = 0, y = 0, r = 16 },
            { type = "circle", mode = "line", color = {0.0, 1.0, 1.0, 0.8}, x = 0, y = 0, r = 16, lineWidth = 2 },
            
            -- Turret body
            { type = "rectangle", mode = "fill", color = {0.2, 0.8, 1.0, 0.6}, x = -8, y = -12, w = 16, h = 24 },
            { type = "rectangle", mode = "line", color = {0.0, 1.0, 1.0, 0.9}, x = -8, y = -12, w = 16, h = 24, lineWidth = 1 },
            
            -- Turret barrel
            { type = "rectangle", mode = "fill", color = {0.1, 0.6, 0.9, 0.7}, x = -2, y = -20, w = 4, h = 16 },
            { type = "rectangle", mode = "line", color = {0.0, 1.0, 1.0, 1.0}, x = -2, y = -20, w = 4, h = 16, lineWidth = 1 },
            
            -- Holographic effect lines
            { type = "line", color = {0.0, 1.0, 1.0, 0.4}, x1 = -12, y1 = -8, x2 = 12, y2 = 8, lineWidth = 1 },
            { type = "line", color = {0.0, 1.0, 1.0, 0.4}, x1 = 12, y1 = -8, x2 = -12, y2 = 8, lineWidth = 1 },
        }
    },
    
    -- Functionality
    functionality = {
        autoDefense = true,
        range = 200,
        damage = 25,
        fireRate = 1.0, -- shots per second
        energyCost = 5, -- energy per shot
        targetTypes = {"enemy", "hostile"}
    },
    
    -- Station properties
    station = {
        type = "holographic_turret",
        name = "Holographic Turret",
        description = "An automated holographic defense turret",
        interactionRange = 50
    },
    
    -- Collision
    collidable = {
        radius = 16,
        isStatic = true
    },
    
    -- Position
    position = {
        x = 0,
        y = 0,
        angle = 0
    },
    
    -- Health
    health = {
        hp = 50,
        maxHP = 50,
        shield = 0,
        maxShield = 0
    },
    
    -- AI for targeting
    ai = {
        intelligenceLevel = "BASIC",
        aggressiveType = "defensive",
        targetPlayer = false,
        targetEnemies = true,
        turretBehavior = {
            fireMode = "automatic",
            autoFire = true,
            targetTypes = {"enemy", "hostile"}
        }
    },
    
    -- Mark as enemy for AI targeting purposes
    isEnemy = false, -- This is a friendly turret
    faction = "player", -- Belongs to player faction
    
    -- Energy system for turret operation
    energy = {
        cap = 200,
        current = 200,
        regen = 20
    },
    
    -- Equipment slots for turrets
    equipmentSlots = 1,
    equipmentLayout = {
        { slot = 1, type = "turret" }
    },
    
    -- Hardpoints for turret mounting
    hardpoints = {
        {
            turret = "combat_laser"
        }
    }
}
