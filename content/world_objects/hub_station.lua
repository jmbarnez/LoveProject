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
            -132, 12,
            -120, 24,
            -84, 24,
            -84, 72,
            -36, 72,
            -36, 108,
            36, 108,
            36, 72,
            84, 72,
            120, 24,
            132, 12,
            132, -12,
            120, -24,
            84, -24,
            84, -72,
            36, -72,
            36, -108,
            -36, -108,
            -36, -72,
            -84, -72,
            -120, -24,
            -132, -12,
        }
    },

    -- Orbital nexus with articulated solar trusses
    visuals = {
        size = 8.5,
        shapes = {
            -- Outer hull silhouette matching the collider
            { type = "polygon", mode = "fill", color = {0.72, 0.78, 0.84, 0.92}, points = {
                -132, 12,  -120, 24,  -84, 24,  -84, 70,
                -38, 70,  -38, 104,  38, 104,  38, 70,
                84, 70,  120, 24,  132, 12,  132, -12,
                120, -24,  84, -24,  84, -70,  38, -70,
                38, -104,  -38, -104,  -38, -70,  -84, -70,
                -120, -24,  -132, -12,
            } },
            { type = "polygon", mode = "line", color = {0.34, 0.38, 0.46, 0.9}, width = 3, points = {
                -132, 12,  -120, 24,  -84, 24,  -84, 72,
                -36, 72,  -36, 108,  36, 108,  36, 72,
                84, 72,  120, 24,  132, 12,  132, -12,
                120, -24,  84, -24,  84, -72,  36, -72,
                36, -108,  -36, -108,  -36, -72,  -84, -72,
                -120, -24,  -132, -12,
            } },

            -- Reinforced inner cruciform core
            { type = "polygon", mode = "fill", color = {0.60, 0.64, 0.70, 0.95}, points = {
                -96, 10,  -60, 10,  -60, 54,  -18, 54,
                -18, 92,  18, 92,  18, 54,  60, 54,
                60, 10,  96, 10,  96, -10,  60, -10,
                60, -54,  18, -54,  18, -92,  -18, -92,
                -18, -54,  -60, -54,  -60, -10,  -96, -10,
            } },

            -- Command dome and docking collar
            { type = "circle", mode = "fill", color = {0.86, 0.89, 0.96, 0.95}, x = 0, y = 0, r = 26 },
            { type = "circle", mode = "line", color = {0.42, 0.48, 0.60, 0.85}, width = 4, x = 0, y = 0, r = 32 },
            { type = "circle", mode = "fill", color = {0.32, 0.58, 0.92, 0.7}, x = 0, y = 0, r = 16 },

            -- Solar arrays at the cardinal directions
            { type = "rectangle", mode = "fill", color = {0.20, 0.55, 0.95, 0.9}, x = 108, y = -18, w = 44, h = 36, rx = 4 },
            { type = "rectangle", mode = "fill", color = {0.20, 0.55, 0.95, 0.9}, x = -152, y = -18, w = 44, h = 36, rx = 4 },
            { type = "rectangle", mode = "fill", color = {0.20, 0.55, 0.95, 0.9}, x = -18, y = 108, w = 36, h = 44, rx = 4 },
            { type = "rectangle", mode = "fill", color = {0.20, 0.55, 0.95, 0.9}, x = -18, y = -152, w = 36, h = 44, rx = 4 },

            -- Docking spines extending toward the panels
            { type = "rectangle", mode = "fill", color = {0.55, 0.60, 0.68, 0.95}, x = 82, y = -8, w = 64, h = 16 },
            { type = "rectangle", mode = "fill", color = {0.55, 0.60, 0.68, 0.95}, x = -146, y = -8, w = 64, h = 16 },
            { type = "rectangle", mode = "fill", color = {0.55, 0.60, 0.68, 0.95}, x = -8, y = 82, w = 16, h = 64 },
            { type = "rectangle", mode = "fill", color = {0.55, 0.60, 0.68, 0.95}, x = -8, y = -146, w = 16, h = 64 },

            -- Docking ports at the extremities
            { type = "circle", mode = "fill", color = {0.55, 0.85, 1.0, 0.92}, x = 130, y = 0, r = 10 },
            { type = "circle", mode = "fill", color = {0.55, 0.85, 1.0, 0.92}, x = -130, y = 0, r = 10 },
            { type = "circle", mode = "fill", color = {0.55, 0.85, 1.0, 0.92}, x = 0, y = 130, r = 10 },
            { type = "circle", mode = "fill", color = {0.55, 0.85, 1.0, 0.92}, x = 0, y = -130, r = 10 },

            -- Guidance beacons around the central collar
            { type = "circle", mode = "fill", color = {1.0, 0.75, 0.25, 0.85}, x = 40, y = 0, r = 6 },
            { type = "circle", mode = "fill", color = {1.0, 0.75, 0.25, 0.85}, x = -40, y = 0, r = 6 },
            { type = "circle", mode = "fill", color = {1.0, 0.75, 0.25, 0.85}, x = 0, y = 40, r = 6 },
            { type = "circle", mode = "fill", color = {1.0, 0.75, 0.25, 0.85}, x = 0, y = -40, r = 6 },
        }
    },
}
