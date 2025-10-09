-- Data definition for the main hub station redesigned to resemble the ISS silhouette.
return {
    id = "hub_station",
    name = "Advanced Orbital Nexus",
    class = "WorldObject",

    renderable = {
        type = "station",
        props = {
            size = "large",
        }
    },

    collidable = {
        shape = "polygon",
        friendly = true,
        friction = 0.3, -- Smooth metal surface
        vertices = {
            -40, -20,  -- Top-left
            -30, -30,  -- Left
            -20, -30,  -- Left-bottom
            -10, -40,  -- Bottom-left
            10, -40,   -- Bottom
            20, -30,   -- Bottom-right
            30, -30,   -- Right
            40, -20,   -- Top-right
            40, 20,    -- Right
            30, 30,    -- Right-bottom
            20, 30,    -- Bottom-right
            10, 40,    -- Bottom
            -10, 40,   -- Bottom-left
            -20, 30,   -- Bottom-left
            -30, 30,   -- Left
            -40, 20,   -- Left-top
        }
    },

    -- Station properties
    weapon_disable_radius = 120,  -- Weapons disabled within this radius
    shield_radius = 200,  -- Shield protection radius
    radius = 50,  -- Station radius for calculations

    -- Basic orbital station
    visuals = {
        size = 3.0,
        shapes = {
            -- Main hull matching collision shape
            { type = "polygon", mode = "fill", color = {0.72, 0.78, 0.84, 0.92}, points = {
                -40, -20,  -30, -30,  -20, -30,  -10, -40,
                10, -40,  20, -30,  30, -30,  40, -20,
                40, 20,  30, 30,  20, 30,  10, 40,
                -10, 40,  -20, 30,  -30, 30,  -40, 20,
            } },
            { type = "polygon", mode = "line", color = {0.34, 0.38, 0.46, 0.9}, width = 2, points = {
                -40, -20,  -30, -30,  -20, -30,  -10, -40,
                10, -40,  20, -30,  30, -30,  40, -20,
                40, 20,  30, 30,  20, 30,  10, 40,
                -10, 40,  -20, 30,  -30, 30,  -40, 20,
            } },

            -- Central command core
            { type = "circle", mode = "fill", color = {0.86, 0.89, 0.96, 0.95}, x = 0, y = 0, r = 12 },
            { type = "circle", mode = "line", color = {0.42, 0.48, 0.60, 0.85}, width = 2, x = 0, y = 0, r = 16 },
            { type = "circle", mode = "fill", color = {0.32, 0.58, 0.92, 0.7}, x = 0, y = 0, r = 8 },

            -- Small solar panels
            { type = "rectangle", mode = "fill", color = {0.20, 0.55, 0.95, 0.9}, x = 25, y = -8, w = 20, h = 16, rx = 2 },
            { type = "rectangle", mode = "fill", color = {0.20, 0.55, 0.95, 0.9}, x = -45, y = -8, w = 20, h = 16, rx = 2 },

            -- Docking ports
            { type = "circle", mode = "fill", color = {0.55, 0.85, 1.0, 0.92}, x = 35, y = 0, r = 6 },
            { type = "circle", mode = "fill", color = {0.55, 0.85, 1.0, 0.92}, x = -35, y = 0, r = 6 },

            -- Status lights
            { type = "circle", mode = "fill", color = {0.0, 1.0, 0.0, 0.8}, x = 0, y = 25, r = 3 },
            { type = "circle", mode = "fill", color = {0.0, 1.0, 0.0, 0.8}, x = 0, y = -25, r = 3 },

            -- Weapon disabled ring
            { type = "circle", mode = "line", color = {1.0, 0.0, 0.0, 0.6}, x = 0, y = 0, r = 120, lineWidth = 2 },
        }
    },
}
