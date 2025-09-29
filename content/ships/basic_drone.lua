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
    cap = 0, -- No energy system for basic enemies
  },

    hardpoints = {
        { 
            turret = {
                id = "enemy_red_laser",
                type = "laser",
                name = "Enemy Red Laser",
                description = "A short-range red laser beam weapon.",
                price = 0,
                module = { type = "turret" },
                icon = {
                    size = 32,
                    shapes = {
                        -- Laser emitter base
                        { type = "rectangle", mode = "fill", color = {0.20, 0.20, 0.25, 1}, x = 12, y = 14, w = 8, h = 4, rx = 2 },
                        -- Laser barrel
                        { type = "rectangle", mode = "fill", color = {0.30, 0.30, 0.35, 1}, x = 18, y = 15, w = 6, h = 2, rx = 1 },
                        -- Laser tip
                        { type = "circle", mode = "fill", color = {1.0, 0.1, 0.1, 1}, x = 24, y = 16, r = 1.5 },
                        -- Energy core
                        { type = "circle", mode = "fill", color = {1.0, 0.2, 0.2, 0.8}, x = 16, y = 16, r = 2 },
                    }
                },
                spread = { minDeg = 0.0, maxDeg = 0.0, decay = 1000 },
                
                -- Embedded projectile definition
                projectile = {
                    id = "enemy_red_laser_beam",
                    name = "Enemy Red Laser Beam",
                    class = "Projectile",
                    physics = {
                        speed = 0, -- Beams should not advance position; collision handles ray
                        drag = 0,
                    },
                    renderable = {
                        type = "bullet",
                        props = {
                            kind = "laser",
                            length = 800, -- Shorter range than player lasers
                            tracerWidth = 3,
                            angle = 0, -- Will be set when fired
                            color = {1.0, 0.1, 0.1, 0.9} -- Bright red laser
                        }
                    },
                    collidable = {
                        radius = 2, -- small collision radius so the beam is included in collision queries
                    },
                    damage = 8, -- Moderate damage
                    timed_life = {
                        duration = 0.12, -- Short beam duration
                    },
                    charged_pulse = {
                        buildup_time = 0.05,  -- Quick buildup
                        flash_time = 0.07,   -- Short intense beam flash
                    }
                },
                
                -- Visual effects
                tracer = { color = {1.0, 0.1, 0.1, 0.8}, width = 2, coreRadius = 1.5 },
                impact = {
                    shield = { spanDeg = 80, color1 = {1.0, 0.1, 0.1, 0.65}, color2 = {1.0, 0.3, 0.3, 0.45} },
                    hull = { spark = {1.0, 0.2, 0.2, 0.5}, ring = {1.0, 0.1, 0.1, 0.4} },
                },
                optimal = 600, falloff = 300, -- Shorter range than player lasers
                damage_range = { min = 6, max = 10 },
                cycle = 1.5, capCost = 0, -- No energy cost for basic enemies
                spread = { minDeg = 0.1, maxDeg = 0.3, decay = 600 },
                maxRange = 800, -- Shorter range
                -- Overheating parameters
                maxHeat = 80,
                heatPerShot = 8,
                cooldownRate = 25,
                overheatCooldown = 3.0,
                heatCycleMult = 0.8,
                heatEnergyMult = 1.2,

                -- Firing mode: "manual" or "automatic"
                fireMode = "automatic"
            }
        }
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
            hull = { hp = 8, shield = 5, cap = 0 } -- No energy system
        },
        elite = {
            name = "Elite Hunter Drone",
            ai = { intelligenceLevel = "ELITE", aggressiveType = "hostile" },
            bounty = 20,
            xpReward = 25,
            hull = { hp = 12, shield = 8, cap = 0 }, -- No energy system
            engine = { maxSpeed = 400, accel = 650 }
        },
        ace = {
            name = "Ace Combat Drone",
            ai = { intelligenceLevel = "ACE", aggressiveType = "hostile" },
            bounty = 35,
            xpReward = 40,
            hull = { hp = 18, shield = 12, cap = 0 }, -- No energy system
            engine = { maxSpeed = 420, accel = 700 },
            hardpoints = {
                { turret = "laser_mk2" }  -- Assuming a better weapon exists
            }
        }
    }
}
