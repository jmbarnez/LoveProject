-- Small mining outpost - automated mining station
return {
    id = "mining_outpost",
    name = "Mining Outpost",
    class = "WorldObject",
    description = "Automated mining station that extracts resources from nearby asteroids.",

    renderable = {
        type = "station",
        props = {
            size = "small",
        }
    },

    collidable = {
        shape = "polygon",
        friendly = true,
        vertices = {
            -50, 25,
            -25, 25,
            -25, 50,
            25, 50,
            25, 25,
            50, 25,
            50, -25,
            25, -25,
            25, -50,
            -25, -50,
            -25, -25,
            -50, -25,
        }
    },

    -- Mining station services
    station_services = {
        mining = true,
        storage = 100,  -- 100 item slots
        crafting = true,
    },

    -- Construction requirements
    construction = {
        buildTime = 60,  -- 1 minute to build
        materials = {
            { item = "scraps", amount = 30 },
            { item = "ore_tritanium", amount = 10 },
            { item = "ore_palladium", amount = 5 },
        }
    },

    -- Mining properties
    mining = {
        range = 300,  -- Mines asteroids within 300 units
        speed = 1.0,  -- 1 ore per second
        autoCollect = true,
    },

    visuals = {
        size = 2.5,
        shapes = {
            -- Main platform
            { type = "polygon", mode = "fill", color = {0.25, 0.3, 0.35, 0.9}, points = {
                -50, 25, -25, 25, -25, 50, 25, 50, 25, 25, 50, 25,
                50, -25, 25, -25, 25, -50, -25, -50, -25, -25, -50, -25
            } },
            { type = "polygon", mode = "line", color = {0.15, 0.2, 0.25, 0.9}, width = 2, points = {
                -50, 25, -25, 25, -25, 50, 25, 50, 25, 25, 50, 25,
                50, -25, 25, -25, 25, -50, -25, -50, -25, -25, -50, -25
            } },
            
            -- Central mining core
            { type = "circle", mode = "fill", color = {0.4, 0.5, 0.6, 0.9}, x = 0, y = 0, r = 15 },
            { type = "circle", mode = "line", color = {0.6, 0.7, 0.8, 0.9}, width = 2, x = 0, y = 0, r = 15 },
            
            -- Mining laser emitters
            { type = "rectangle", mode = "fill", color = {0.8, 0.4, 0.2, 0.9}, x = -35, y = -3, w = 20, h = 6 },
            { type = "rectangle", mode = "fill", color = {0.8, 0.4, 0.2, 0.9}, x = 15, y = -3, w = 20, h = 6 },
            { type = "rectangle", mode = "fill", color = {0.8, 0.4, 0.2, 0.9}, x = -3, y = -35, w = 6, h = 20 },
            { type = "rectangle", mode = "fill", color = {0.8, 0.4, 0.2, 0.9}, x = -3, y = 15, w = 6, h = 20 },
            
            -- Storage containers
            { type = "rectangle", mode = "fill", color = {0.3, 0.4, 0.5, 0.8}, x = -40, y = -8, w = 12, h = 16 },
            { type = "rectangle", mode = "fill", color = {0.3, 0.4, 0.5, 0.8}, x = 28, y = -8, w = 12, h = 16 },
            
            -- Status indicators
            { type = "circle", mode = "fill", color = {0.2, 0.8, 0.2, 0.9}, x = -35, y = 0, r = 2 },
            { type = "circle", mode = "fill", color = {0.2, 0.8, 0.2, 0.9}, x = 35, y = 0, r = 2 },
            { type = "circle", mode = "fill", color = {0.2, 0.8, 0.2, 0.9}, x = 0, y = -35, r = 2 },
            { type = "circle", mode = "fill", color = {0.2, 0.8, 0.2, 0.9}, x = 0, y = 35, r = 2 },
        }
    },
}
