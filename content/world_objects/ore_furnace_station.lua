-- Data definition for an industrial ore-processing furnace station.
return {
    id = "ore_furnace_station",
    name = "Helios Forge Complex",
    class = "WorldObject",

    renderable = {
        type = "station",
        props = {
            size = "colossal",
        }
    },

    -- Specialized services exposed through the station template
    station_services = {
        ore_processing = true,
        stone_cracking = true,
    },

    collidable = {
        shape = "polygon",
        friendly = true,
        vertices = {
            -30, -20,  -- Top-left
            -25, -25,  -- Left
            -20, -25,  -- Left-bottom
            -15, -30,  -- Bottom-left
            15, -30,   -- Bottom
            20, -25,   -- Bottom-right
            25, -25,   -- Right
            30, -20,   -- Top-right
            30, 20,    -- Right
            25, 25,    -- Right-bottom
            20, 25,    -- Bottom-right
            15, 30,    -- Bottom
            -15, 30,   -- Bottom-left
            -20, 25,   -- Bottom-left
            -25, 25,   -- Left
            -30, 20,   -- Left-top
        }
    },

    -- Station properties
    docking_radius = 60,  -- Docking allowed within this radius
    weapon_disable_radius = 100,  -- Weapons disabled within this radius
    shield_radius = 150,  -- Shield protection radius
    radius = 40,  -- Station radius for calculations

    description = "A compact refinery that processes ore into refined alloys.",

    visuals = {
        size = 2.5,
        shapes = {
            -- Main hull matching collision shape
            { type = "polygon", mode = "fill", color = {0.44, 0.46, 0.52, 0.95}, points = {
                -30, -20,  -25, -25,  -20, -25,  -15, -30,
                15, -30,  20, -25,  25, -25,  30, -20,
                30, 20,  25, 25,  20, 25,  15, 30,
                -15, 30,  -20, 25,  -25, 25,  -30, 20,
            } },
            { type = "polygon", mode = "line", color = {0.20, 0.22, 0.26, 0.95}, width = 2, points = {
                -30, -20,  -25, -25,  -20, -25,  -15, -30,
                15, -30,  20, -25,  25, -25,  30, -20,
                30, 20,  25, 25,  20, 25,  15, 30,
                -15, 30,  -20, 25,  -25, 25,  -30, 20,
            } },

            -- Central furnace core
            { type = "circle", mode = "fill", color = {0.92, 0.54, 0.12, 0.95}, x = 0, y = 0, r = 12 },
            { type = "circle", mode = "fill", color = {0.32, 0.12, 0.06, 0.9}, x = 0, y = 0, r = 8 },
            { type = "circle", mode = "line", color = {1.0, 0.78, 0.32, 0.9}, width = 2, x = 0, y = 0, r = 8 },

            -- Ore processing equipment
            { type = "rectangle", mode = "fill", color = {0.28, 0.30, 0.36, 0.95}, x = 20, y = -8, w = 15, h = 16, rx = 3 },
            { type = "rectangle", mode = "fill", color = {0.28, 0.30, 0.36, 0.95}, x = -35, y = -8, w = 15, h = 16, rx = 3 },

            -- Heat vents
            { type = "circle", mode = "fill", color = {1.0, 0.3, 0.0, 0.8}, x = 0, y = 18, r = 3 },
            { type = "circle", mode = "fill", color = {1.0, 0.3, 0.0, 0.8}, x = 0, y = -18, r = 3 },

            -- Docking ports
            { type = "circle", mode = "fill", color = {0.62, 0.88, 1.0, 0.92}, x = 25, y = 0, r = 4 },
            { type = "circle", mode = "fill", color = {0.62, 0.88, 1.0, 0.92}, x = -25, y = 0, r = 4 },

        }
    },
}
