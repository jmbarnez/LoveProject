-- Data definition for a mineral processing and extraction facility
return {
    id = "processing_station",
    name = "Asteroid Mining Corp - Processing Station Alpha",
    class = "WorldObject",

    renderable = {
        type = "station",
        props = {
            size = "large",
        }
    },

    collidable = {
        radius = 75,  -- Industrial facility needs more space
    },

    -- Industrial Mining Station Design
    visuals = {
        size = 9.0,
        shapes = {
            -- Main industrial complex (rectangular base)
            { type = "rectangle", mode = "fill", color = {0.45, 0.47, 0.50, 0.9}, x = -40, y = -25, w = 80, h = 50, rx = 3 },
            { type = "rectangle", mode = "line", color = {0.35, 0.37, 0.40, 0.9}, x = -40, y = -25, w = 80, h = 50, rx = 3, width = 2 },

            -- Processing towers/silos
            { type = "rectangle", mode = "fill", color = {0.50, 0.52, 0.55, 0.9}, x = -35, y = -45, w = 15, h = 40, rx = 2 },
            { type = "rectangle", mode = "fill", color = {0.50, 0.52, 0.55, 0.9}, x = -10, y = -50, w = 20, h = 45, rx = 2 },
            { type = "rectangle", mode = "fill", color = {0.50, 0.52, 0.55, 0.9}, x = 20, y = -42, w = 15, h = 37, rx = 2 },

            -- Refinery smokestacks/vents
            { type = "rectangle", mode = "fill", color = {0.40, 0.42, 0.45, 0.9}, x = -30, y = -55, w = 4, h = 15 },
            { type = "rectangle", mode = "fill", color = {0.40, 0.42, 0.45, 0.9}, x = 0, y = -60, w = 4, h = 15 },
            { type = "rectangle", mode = "fill", color = {0.40, 0.42, 0.45, 0.9}, x = 25, y = -52, w = 4, h = 15 },

            -- Ore processing conveyor/loading bay
            { type = "rectangle", mode = "fill", color = {0.60, 0.45, 0.25, 0.8}, x = -50, y = 10, w = 20, h = 30, rx = 2 },
            { type = "rectangle", mode = "fill", color = {0.60, 0.45, 0.25, 0.8}, x = 30, y = 10, w = 20, h = 30, rx = 2 },

            -- Storage containers/tanks
            { type = "circle", mode = "fill", color = {0.55, 0.57, 0.60, 0.8}, x = -60, y = -10, r = 12 },
            { type = "circle", mode = "fill", color = {0.55, 0.57, 0.60, 0.8}, x = 60, y = -10, r = 12 },
            { type = "circle", mode = "fill", color = {0.55, 0.57, 0.60, 0.8}, x = -60, y = 20, r = 10 },
            { type = "circle", mode = "fill", color = {0.55, 0.57, 0.60, 0.8}, x = 60, y = 20, r = 10 },

            -- Mining equipment arms/extractors
            { type = "rectangle", mode = "fill", color = {0.65, 0.50, 0.30, 0.9}, x = -20, y = 40, w = 40, h = 8, rx = 4 },
            { type = "rectangle", mode = "fill", color = {0.65, 0.50, 0.30, 0.9}, x = -25, y = 35, w = 8, h = 18, rx = 4 },
            { type = "rectangle", mode = "fill", color = {0.65, 0.50, 0.30, 0.9}, x = 17, y = 35, w = 8, h = 18, rx = 4 },

            -- Power generators (smaller than solar panels, more industrial)
            { type = "rectangle", mode = "fill", color = {0.20, 0.60, 0.80, 0.8}, x = -75, y = -30, w = 10, h = 20, rx = 1 },
            { type = "rectangle", mode = "fill", color = {0.20, 0.60, 0.80, 0.8}, x = 65, y = -30, w = 10, h = 20, rx = 1 },

            -- Command/control center (elevated)
            { type = "rectangle", mode = "fill", color = {0.70, 0.72, 0.75, 0.9}, x = -8, y = -15, w = 16, h = 12, rx = 2 },
            { type = "rectangle", mode = "line", color = {0.80, 0.82, 0.85, 0.9}, x = -8, y = -15, w = 16, h = 12, rx = 2, width = 1 },

            -- Warning lights/beacons
            { type = "circle", mode = "fill", color = {1.0, 0.3, 0.1, 0.9}, x = -35, y = -50, r = 2 },
            { type = "circle", mode = "fill", color = {1.0, 0.3, 0.1, 0.9}, x = 0, y = -55, r = 2 },
            { type = "circle", mode = "fill", color = {1.0, 0.3, 0.1, 0.9}, x = 27, y = -47, r = 2 },

            -- Docking clamps/connectors
            { type = "rectangle", mode = "fill", color = {0.30, 0.70, 0.90, 0.9}, x = -8, y = 50, w = 16, h = 6, rx = 3 },
            { type = "rectangle", mode = "fill", color = {0.30, 0.70, 0.90, 0.9}, x = -80, y = -4, w = 6, h = 8, rx = 3 },
            { type = "rectangle", mode = "fill", color = {0.30, 0.70, 0.90, 0.9}, x = 74, y = -4, w = 6, h = 8, rx = 3 },
        }
    },
}