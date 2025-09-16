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

    -- No collidable component for stations (no physics collisions)

    -- Repair system properties
    repairable = true,
    broken = true,  -- Starts broken
    repair_cost = {
        { item = "ore_tritanium", amount = 25 },
        { item = "ore_palladium", amount = 15 },
        { item = "scraps", amount = 50 }
    },

    -- Special property: large no-spawn radius (only when repaired)
    no_spawn_radius = 5000,  -- Large radius around beacon when repaired

    -- Beacon Station Design - looks like a communications/defense array
    visuals = {
        size = 6.0,
        shapes = {
            -- Central beacon core
            { type = "circle", mode = "fill", color = {0.20, 0.80, 1.0, 0.9}, x = 0, y = 0, r = 20 },
            { type = "circle", mode = "line", color = {0.10, 0.60, 0.90, 1.0}, x = 0, y = 0, r = 20, width = 3 },

            -- Inner energy core
            { type = "circle", mode = "fill", color = {1.0, 1.0, 1.0, 0.8}, x = 0, y = 0, r = 10 },

            -- Rotating beacon arrays (cross pattern)
            { type = "rectangle", mode = "fill", color = {0.15, 0.75, 0.95, 0.9}, x = -35, y = -2, w = 70, h = 4, rx = 2 },
            { type = "rectangle", mode = "fill", color = {0.15, 0.75, 0.95, 0.9}, x = -2, y = -35, w = 4, h = 70, rx = 2 },

            -- Beacon emitters at the ends
            { type = "circle", mode = "fill", color = {0.0, 1.0, 0.2, 0.9}, x = 35, y = 0, r = 6 },
            { type = "circle", mode = "fill", color = {0.0, 1.0, 0.2, 0.9}, x = -35, y = 0, r = 6 },
            { type = "circle", mode = "fill", color = {0.0, 1.0, 0.2, 0.9}, x = 0, y = 35, r = 6 },
            { type = "circle", mode = "fill", color = {0.0, 1.0, 0.2, 0.9}, x = 0, y = -35, r = 6 },

            -- Secondary beacon arrays (diagonal)
            { type = "rectangle", mode = "fill", color = {0.25, 0.85, 1.0, 0.8}, x = -20, y = -20, w = 40, h = 3, rx = 1, rotation = 0.785 },
            { type = "rectangle", mode = "fill", color = {0.25, 0.85, 1.0, 0.8}, x = -20, y = 17, w = 40, h = 3, rx = 1, rotation = -0.785 },

            -- Smaller emitters on diagonals
            { type = "circle", mode = "fill", color = {1.0, 0.8, 0.0, 0.8}, x = 25, y = 25, r = 3 },
            { type = "circle", mode = "fill", color = {1.0, 0.8, 0.0, 0.8}, x = -25, y = 25, r = 3 },
            { type = "circle", mode = "fill", color = {1.0, 0.8, 0.0, 0.8}, x = 25, y = -25, r = 3 },
            { type = "circle", mode = "fill", color = {1.0, 0.8, 0.0, 0.8}, x = -25, y = -25, r = 3 },

            -- Warning/status indicators
            { type = "rectangle", mode = "fill", color = {1.0, 0.3, 0.1, 0.9}, x = -15, y = -8, w = 30, h = 2 },
            { type = "rectangle", mode = "fill", color = {1.0, 0.3, 0.1, 0.9}, x = -15, y = -4, w = 30, h = 2 },
            { type = "rectangle", mode = "fill", color = {1.0, 0.3, 0.1, 0.9}, x = -15, y = 2, w = 30, h = 2 },
            { type = "rectangle", mode = "fill", color = {1.0, 0.3, 0.1, 0.9}, x = -15, y = 6, w = 30, h = 2 },

            -- Support struts
            { type = "rectangle", mode = "fill", color = {0.40, 0.45, 0.50, 0.8}, x = -1, y = -45, w = 2, h = 20 },
            { type = "rectangle", mode = "fill", color = {0.40, 0.45, 0.50, 0.8}, x = -1, y = 25, w = 2, h = 20 },
            { type = "rectangle", mode = "fill", color = {0.40, 0.45, 0.50, 0.8}, x = -45, y = -1, w = 20, h = 2 },
            { type = "rectangle", mode = "fill", color = {0.40, 0.45, 0.50, 0.8}, x = 25, y = -1, w = 20, h = 2 },
        }
    },
}