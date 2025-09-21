-- Data definition for the Basic Drone enemy.
return {
    id = "basic_drone",
    name = "Basic Drone",
    class = "Drone",
    description = "A simple, automated combat drone.",
    
    -- AI Configuration
    ai = {
        intelligenceLevel = "BASIC",
        aggressiveType = "aggressive"
    },

    visuals = {
        size = 0.7, -- slightly smaller base size
        shapes = {
            { type = "circle", mode = "fill", color = {0.42, 0.45, 0.50, 1.0}, x = 0, y = 0, r = 10 },
            { type = "circle", mode = "line", color = {0.20, 0.22, 0.26, 0.9}, x = 0, y = 0, r = 10 },
            { type = "circle", mode = "fill", color = {1.0, 0.35, 0.25, 0.9}, x = 3, y = 0, r = 3.2 },
            { type = "rect", mode = "fill", color = {0.32, 0.35, 0.39, 1.0}, x = -6, y = -12, w = 18, h = 4, rx = 1 },
            { type = "rect", mode = "fill", color = {0.32, 0.35, 0.39, 1.0}, x = -6, y = 8,  w = 18, h = 4, rx = 1 },
            { type = "rect", mode = "fill", color = {0.28, 0.30, 0.34, 1.0}, x = 8, y = -1, w = 8, h = 2, rx = 1 },
            { type = "circle", mode = "fill", color = {1.0, 0.25, 0.2, 0.8}, x = -6, y = -10, r = 1.5 },
            { type = "circle", mode = "fill", color = {1.0, 0.25, 0.2, 0.8}, x = -6, y = 10,  r = 1.5 },
        }
    },

    engine = {
        mass = 150,
        accel = 400,
        maxSpeed = 280,
    },

    hull = {
        hp = 5,
        shield = 0,
        cap = 150,  -- Increased capacitor for more aggressive firing
    },

    hardpoints = {
        { turret = "laser_mk1" }
    },

    bounty = 8,
    xpReward = 10,

    loot = {
        drops = {
            { id = "ore_tritanium", min = 1, max = 3, chance = 0.7 },
            { id = "ore_palladium", min = 1, max = 2, chance = 0.35 },
            { id = "basic_gun", chance = 0.5 },
            { id = "node_wallet", min = 1, max = 1, chance = 1.0 },  -- 100% drop rate for testing
        }
    },

    -- Mark as enemy for red engine trails
    isEnemy = true,
    
    -- Create different variants with different intelligence levels
    variants = {
        basic = {
            name = "Basic Patrol Drone",
            ai = { intelligenceLevel = "BASIC", aggressiveType = "neutral" },
            bounty = 6,
            xpReward = 8
        },
        guard = {
            name = "Guard Drone", 
            ai = { intelligenceLevel = "STANDARD", aggressiveType = "aggressive" },
            bounty = 12,
            xpReward = 15,
            hull = { hp = 8, shield = 5, cap = 200 }
        },
        elite = {
            name = "Elite Hunter Drone",
            ai = { intelligenceLevel = "ELITE", aggressiveType = "hostile" },
            bounty = 20,
            xpReward = 25,
            hull = { hp = 12, shield = 8, cap = 250 },
            engine = { maxSpeed = 320, accel = 500 }
        },
        ace = {
            name = "Ace Combat Drone",
            ai = { intelligenceLevel = "ACE", aggressiveType = "hostile" },
            bounty = 35,
            xpReward = 40,
            hull = { hp = 18, shield = 12, cap = 350 },
            engine = { maxSpeed = 380, accel = 600 },
            hardpoints = {
                { turret = "laser_mk2" }  -- Assuming a better weapon exists
            }
        }
    }
}
