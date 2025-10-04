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
            -72, 8,
            -48, 8,
            -48, 28,
            -20, 28,
            -20, 56,
            -8, 56,
            -8, 72,
            8, 72,
            8, 56,
            20, 56,
            20, 28,
            48, 28,
            48, 8,
            72, 8,
            72, -8,
            48, -8,
            48, -28,
            20, -28,
            20, -56,
            8, -56,
            8, -72,
            -8, -72,
            -8, -56,
            -20, -56,
            -20, -28,
            -48, -28,
            -48, -8,
            -72, -8,
        }
    },

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

    -- Beacon Station Design - looks like a communications/defense array
    visuals = {
        size = 6.5,
        shapes = {
            -- Compact emitter lattice matching collider outline
            { type = "polygon", mode = "fill", color = {0.12, 0.62, 0.92, 0.92}, points = {
                -72, 8,  -48, 8,  -48, 26,  -20, 26,
                -20, 56,  -6, 56,  -6, 70,  6, 70,
                6, 56,  20, 56,  20, 26,  48, 26,
                48, 8,  72, 8,  72, -8,  48, -8,
                48, -26,  20, -26,  20, -56,  6, -56,
                6, -70,  -6, -70,  -6, -56,  -20, -56,
                -20, -26,  -48, -26,  -48, -8,  -72, -8,
            } },
            { type = "polygon", mode = "line", color = {0.05, 0.36, 0.58, 0.95}, width = 3, points = {
                -72, 8,  -48, 8,  -48, 28,  -20, 28,
                -20, 56,  -8, 56,  -8, 72,  8, 72,
                8, 56,  20, 56,  20, 28,  48, 28,
                48, 8,  72, 8,  72, -8,  48, -8,
                48, -28,  20, -28,  20, -56,  8, -56,
                8, -72,  -8, -72,  -8, -56,  -20, -56,
                -20, -28,  -48, -28,  -48, -8,  -72, -8,
            } },

            -- Glowing transmitter core
            { type = "circle", mode = "fill", color = {0.10, 0.90, 0.50, 0.95}, x = 0, y = 0, r = 18 },
            { type = "circle", mode = "line", color = {0.12, 0.40, 0.65, 0.9}, width = 3, x = 0, y = 0, r = 24 },
            { type = "circle", mode = "fill", color = {1.0, 1.0, 1.0, 0.82}, x = 0, y = 0, r = 10 },

            -- Rotational emitters and antennae
            { type = "rectangle", mode = "fill", color = {0.16, 0.78, 1.0, 0.88}, x = -46, y = -4, w = 92, h = 8, rx = 3 },
            { type = "rectangle", mode = "fill", color = {0.16, 0.78, 1.0, 0.88}, x = -4, y = -46, w = 8, h = 92, rx = 3 },
            { type = "rectangle", mode = "fill", color = {0.20, 0.86, 1.0, 0.75}, x = -26, y = -26, w = 52, h = 5, rotation = 0.785 },
            { type = "rectangle", mode = "fill", color = {0.20, 0.86, 1.0, 0.75}, x = -26, y = 21, w = 52, h = 5, rotation = -0.785 },

            -- Beacon flashers
            { type = "circle", mode = "fill", color = {0.0, 1.0, 0.3, 0.9}, x = 56, y = 0, r = 6 },
            { type = "circle", mode = "fill", color = {0.0, 1.0, 0.3, 0.9}, x = -56, y = 0, r = 6 },
            { type = "circle", mode = "fill", color = {0.0, 1.0, 0.3, 0.9}, x = 0, y = 56, r = 6 },
            { type = "circle", mode = "fill", color = {0.0, 1.0, 0.3, 0.9}, x = 0, y = -56, r = 6 },

            -- Status indicator bars
            { type = "rectangle", mode = "fill", color = {1.0, 0.38, 0.18, 0.9}, x = -18, y = -10, w = 36, h = 3 },
            { type = "rectangle", mode = "fill", color = {1.0, 0.38, 0.18, 0.9}, x = -18, y = -4, w = 36, h = 3 },
            { type = "rectangle", mode = "fill", color = {1.0, 0.38, 0.18, 0.9}, x = -18, y = 2, w = 36, h = 3 },
            { type = "rectangle", mode = "fill", color = {1.0, 0.38, 0.18, 0.9}, x = -18, y = 8, w = 36, h = 3 },

            -- Structural braces
            { type = "rectangle", mode = "fill", color = {0.30, 0.36, 0.44, 0.85}, x = -2, y = -60, w = 4, h = 24 },
            { type = "rectangle", mode = "fill", color = {0.30, 0.36, 0.44, 0.85}, x = -2, y = 36, w = 4, h = 24 },
            { type = "rectangle", mode = "fill", color = {0.30, 0.36, 0.44, 0.85}, x = -60, y = -2, w = 24, h = 4 },
            { type = "rectangle", mode = "fill", color = {0.30, 0.36, 0.44, 0.85}, x = 36, y = -2, w = 24, h = 4 },
        }
    },
}
