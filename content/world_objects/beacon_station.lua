-- Data definition for a defense beacon station that creates a large no-spawn zone when repaired
return {
    id = "beacon_station",
    name = "Defensive Beacon Array (DAMAGED)",
    class = "WorldObject",

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
            -25, -15,  -- Top-left
            -20, -20,  -- Left
            -15, -20,  -- Left-bottom
            -10, -25,  -- Bottom-left
            10, -25,   -- Bottom
            15, -20,   -- Bottom-right
            20, -20,   -- Right
            25, -15,   -- Top-right
            25, 15,    -- Right
            20, 20,    -- Right-bottom
            15, 20,    -- Bottom-right
            10, 25,    -- Bottom
            -10, 25,   -- Bottom-left
            -15, 20,   -- Bottom-left
            -20, 20,   -- Left
            -25, 15,   -- Left-top
        }
    },

    -- Station properties
    docking_radius = 50,  -- Docking allowed within this radius
    weapon_disable_radius = 80,  -- Weapons disabled within this radius
    shield_radius = 120,  -- Shield protection radius
    radius = 30,  -- Station radius for calculations

    -- Repair system properties
    repairable = true,
    broken = true,  -- Starts broken
    repair_cost = {
        { item = "ore_tritanium", amount = 25 },
        { item = "ore_palladium", amount = 15 },
        { item = "scraps", amount = 50 }
    },

    -- Special property: large no-spawn radius (only when repaired)
    no_spawn_radius = 2500,  -- Large radius around beacon when repaired

    -- Basic Beacon Station Design
    visuals = {
        size = 2.0,
        shapes = {
            -- Main hull matching collision shape
            { type = "polygon", mode = "fill", color = {0.12, 0.62, 0.92, 0.92}, points = {
                -25, -15,  -20, -20,  -15, -20,  -10, -25,
                10, -25,  15, -20,  20, -20,  25, -15,
                25, 15,  20, 20,  15, 20,  10, 25,
                -10, 25,  -15, 20,  -20, 20,  -25, 15,
            } },
            { type = "polygon", mode = "line", color = {0.05, 0.36, 0.58, 0.95}, width = 2, points = {
                -25, -15,  -20, -20,  -15, -20,  -10, -25,
                10, -25,  15, -20,  20, -20,  25, -15,
                25, 15,  20, 20,  15, 20,  10, 25,
                -10, 25,  -15, 20,  -20, 20,  -25, 15,
            } },

            -- Central transmitter core
            { type = "circle", mode = "fill", color = {0.10, 0.90, 0.50, 0.95}, x = 0, y = 0, r = 8 },
            { type = "circle", mode = "line", color = {0.12, 0.40, 0.65, 0.9}, width = 2, x = 0, y = 0, r = 12 },
            { type = "circle", mode = "fill", color = {1.0, 1.0, 1.0, 0.82}, x = 0, y = 0, r = 4 },

            -- Communication arrays
            { type = "rectangle", mode = "fill", color = {0.16, 0.78, 1.0, 0.88}, x = -15, y = -3, w = 30, h = 6, rx = 2 },
            { type = "rectangle", mode = "fill", color = {0.16, 0.78, 1.0, 0.88}, x = -3, y = -15, w = 6, h = 30, rx = 2 },

            -- Status indicators
            { type = "circle", mode = "fill", color = {1.0, 0.0, 0.0, 0.8}, x = 0, y = 18, r = 2 },
            { type = "circle", mode = "fill", color = {1.0, 0.0, 0.0, 0.8}, x = 0, y = -18, r = 2 },

        }
    },
}
