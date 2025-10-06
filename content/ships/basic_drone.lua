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
    hp = 50,
    shield = 0,
    cap = 0, -- No energy system for basic enemies
  },

    hardpoints = {
        {
            turret = "gun_turret",
            randomTurrets = { "gun_turret", "combat_laser", "missile_launcher" },
        }
    },

    xpReward = 10,
    cargo = { capacity = 20, volumeLimit = 8.0 }, -- 8 m^3 cargo hold for basic drone

    enemy = {
        sizeMultiplier = 1.5,
        collidableRadiusMultiplier = 1.5,
        physicsRadiusMultiplier = 1.5,
        energyRegen = 20,
        turretBehavior = {
            fireMode = "automatic",
            autoFire = true,
        },
    },

    loot = {
        drops = {
            { id = "scraps", min = 1, max = 3, chance = 0.6 },
            { id = "broken_circuitry", min = 1, max = 2, chance = 0.4 },
            { id = "ore_tritanium", min = 1, max = 2, chance = 0.25 },
            { id = "ore_palladium", min = 1, max = 1, chance = 0.1 },
            { id = "gun_turret", chance = 0.05 },
            { id = "combat_laser", chance = 0.03 },
            { id = "missile_launcher", chance = 0.02 },
            { id = "node_wallet", min = 1, max = 1, chance = 0.3 },
        }
    },

    -- Mark as enemy for red engine trails
    isEnemy = true,
    
    -- Create different variants with different intelligence levels
    variants = {
        basic = {
            name = "Basic Patrol Drone",
            ai = { intelligenceLevel = "BASIC", aggressiveType = "neutral" },
            xpReward = 8
        },
        guard = {
            name = "Guard Drone",
            ai = { intelligenceLevel = "STANDARD", aggressiveType = "aggressive" },
            xpReward = 15,
            hull = { hp = 80, shield = 50, cap = 0 } -- No energy system
        },
        elite = {
            name = "Elite Hunter Drone",
            ai = { intelligenceLevel = "ELITE", aggressiveType = "hostile" },
            xpReward = 25,
            hull = { hp = 120, shield = 80, cap = 0 }, -- No energy system
            engine = { maxSpeed = 400, accel = 650 }
        },
        ace = {
            name = "Ace Combat Drone",
            ai = { intelligenceLevel = "ACE", aggressiveType = "hostile" },
            xpReward = 40,
            hull = { hp = 180, shield = 120, cap = 0 }, -- No energy system
            engine = { maxSpeed = 420, accel = 700 },
            hardpoints = {
                { turret = "combat_laser" }  -- Use streamlined combat laser
            }
        }
    }
}
