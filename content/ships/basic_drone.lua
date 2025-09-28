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
        size = 0.8, -- adjusted for hexagonal design
        hullColor = {0.42, 0.45, 0.50, 1.0},
        panelColor = {0.32, 0.35, 0.39, 1.0},
        accentColor = {1.0, 0.35, 0.25, 0.9},
        engineColor = {1.0, 0.25, 0.2},
        shapes = {
            -- Central hexagonal core (drone-like)
            { type = "polygon", mode = "fill", color = {0.42, 0.45, 0.50, 1.0}, points = { 0,-10,  -8,-5,  -8,5,  0,10,  8,5,  8,-5 } },

            -- Symmetrical engine mounts (4 points around center)
            { type = "rectangle", mode = "fill", color = {0.32, 0.35, 0.39, 1.0}, x = -10, y = -3, w = 3, h = 6 },
            { type = "rectangle", mode = "fill", color = {0.32, 0.35, 0.39, 1.0}, x = 7, y = -3, w = 3, h = 6 },
            { type = "rectangle", mode = "fill", color = {0.32, 0.35, 0.39, 1.0}, x = -3, y = -10, w = 6, h = 3 },
            { type = "rectangle", mode = "fill", color = {0.32, 0.35, 0.39, 1.0}, x = -3, y = 7, w = 6, h = 3 },

            -- Engine glow effects (positioned at engine mounts)
            { type = "circle", mode = "fill", color = {1.0, 0.35, 0.25, 0.9}, x = -8, y = 0, r = 1.5 },
            { type = "circle", mode = "fill", color = {1.0, 0.25, 0.2, 0.8}, x = 8, y = 0, r = 1.5 },
            { type = "circle", mode = "fill", color = {1.0, 0.35, 0.25, 0.9}, x = 0, y = -8, r = 1.5 },
            { type = "circle", mode = "fill", color = {1.0, 0.25, 0.2, 0.8}, x = 0, y = 8, r = 1.5 },

            -- Central sensor array
            { type = "circle", mode = "fill", color = {0.25, 0.75, 0.95, 0.4}, x = 0, y = 0, r = 4 },

            -- Symmetrical sensor nodes
            { type = "circle", mode = "fill", color = {0.35, 0.65, 0.85, 0.5}, x = 0, y = -6, r = 1.5 },
            { type = "circle", mode = "fill", color = {0.35, 0.65, 0.85, 0.5}, x = 0, y = 6, r = 1.5 },
            { type = "circle", mode = "fill", color = {0.35, 0.65, 0.85, 0.5}, x = -6, y = 0, r = 1.5 },
            { type = "circle", mode = "fill", color = {0.35, 0.65, 0.85, 0.5}, x = 6, y = 0, r = 1.5 },

            -- Outer hull outline
            { type = "polygon", mode = "line", color = {0.20, 0.22, 0.26, 0.9}, points = { 0,-10,  -8,-5,  -8,5,  0,10,  8,5,  8,-5 } },
        }
    },

    engine = {
        mass = 150,
        accel = 600,
        maxSpeed = 350,
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
            engine = { maxSpeed = 400, accel = 650 }
        },
        ace = {
            name = "Ace Combat Drone",
            ai = { intelligenceLevel = "ACE", aggressiveType = "hostile" },
            bounty = 35,
            xpReward = 40,
            hull = { hp = 18, shield = 12, cap = 350 },
            engine = { maxSpeed = 420, accel = 700 },
            hardpoints = {
                { turret = "laser_mk2" }  -- Assuming a better weapon exists
            }
        }
    }
}
