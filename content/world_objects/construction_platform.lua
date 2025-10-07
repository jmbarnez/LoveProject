-- Small construction platform - the first thing players can build
return {
    id = "construction_platform",
    name = "Construction Platform",
    class = "WorldObject",
    description = "A basic construction platform for crafting and storage.",

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
            -40, 20,
            -20, 20,
            -20, 40,
            20, 40,
            20, 20,
            40, 20,
            40, -20,
            20, -20,
            20, -40,
            -20, -40,
            -20, -20,
            -40, -20,
        }
    },

    -- Basic station services
    station_services = {
        crafting = true,
        storage = 50,  -- 50 item slots
    },

    -- Construction requirements
    construction = {
        buildTime = 30,  -- 30 seconds to build
        materials = {
            { item = "scraps", amount = 20 },
            { item = "ore_tritanium", amount = 5 },
        }
    },

    visuals = {
        size = 2.0,
        shapes = {
            -- Main platform
            { type = "polygon", mode = "fill", color = {0.3, 0.3, 0.35, 0.9}, points = {
                -40, 20, -20, 20, -20, 40, 20, 40, 20, 20, 40, 20,
                40, -20, 20, -20, 20, -40, -20, -40, -20, -20, -40, -20
            } },
            { type = "polygon", mode = "line", color = {0.2, 0.2, 0.25, 0.9}, width = 2, points = {
                -40, 20, -20, 20, -20, 40, 20, 40, 20, 20, 40, 20,
                40, -20, 20, -20, 20, -40, -20, -40, -20, -20, -40, -20
            } },
            
            -- Central core
            { type = "circle", mode = "fill", color = {0.4, 0.4, 0.5, 0.9}, x = 0, y = 0, r = 12 },
            { type = "circle", mode = "line", color = {0.6, 0.6, 0.7, 0.9}, width = 2, x = 0, y = 0, r = 12 },
            
            -- Corner supports
            { type = "circle", mode = "fill", color = {0.5, 0.5, 0.6, 0.8}, x = -30, y = -30, r = 4 },
            { type = "circle", mode = "fill", color = {0.5, 0.5, 0.6, 0.8}, x = 30, y = -30, r = 4 },
            { type = "circle", mode = "fill", color = {0.5, 0.5, 0.6, 0.8}, x = -30, y = 30, r = 4 },
            { type = "circle", mode = "fill", color = {0.5, 0.5, 0.6, 0.8}, x = 30, y = 30, r = 4 },
            
            -- Status light
            { type = "circle", mode = "fill", color = {0.2, 0.8, 0.2, 0.9}, x = 0, y = 0, r = 3 },
        }
    },
}
