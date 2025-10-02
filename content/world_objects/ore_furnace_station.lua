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
            -156, 48,
            -156, -48,
            -126, -48,
            -126, -96,
            -84, -96,
            -84, -144,
            -36, -144,
            -36, -180,
            36, -180,
            36, -144,
            84, -144,
            84, -96,
            126, -96,
            126, -48,
            156, -48,
            156, 48,
            126, 48,
            126, 96,
            84, 96,
            84, 144,
            36, 144,
            36, 180,
            -36, 180,
            -36, 144,
            -84, 144,
            -84, 96,
            -126, 96,
            -126, 48,
        }
    },

    description = "A sprawling refinery that superheats ore shipments into refined alloys.",

    visuals = {
        size = 6.0,
        shapes = {
            -- Outer furnace superstructure aligned with collider
            { type = "polygon", mode = "fill", color = {0.44, 0.46, 0.52, 0.95}, points = {
                -156, 48,  -156, -48,  -126, -48,  -126, -94,
                -86, -94,  -86, -140,  -40, -140,  -40, -176,
                40, -176,  40, -140,  86, -140,  86, -94,
                126, -94,  126, -48,  156, -48,  156, 48,
                126, 48,  126, 94,  86, 94,  86, 140,
                40, 140,  40, 176,  -40, 176,  -40, 140,
                -86, 140,  -86, 94,  -126, 94,  -126, 48,
            } },
            { type = "polygon", mode = "line", color = {0.20, 0.22, 0.26, 0.95}, width = 4, points = {
                -156, 48,  -156, -48,  -126, -48,  -126, -96,
                -84, -96,  -84, -144,  -36, -144,  -36, -180,
                36, -180,  36, -144,  84, -144,  84, -96,
                126, -96,  126, -48,  156, -48,  156, 48,
                126, 48,  126, 96,  84, 96,  84, 144,
                36, 144,  36, 180,  -36, 180,  -36, 144,
                -84, 144,  -84, 96,  -126, 96,  -126, 48,
            } },

            -- Inner pressure vessel
            { type = "circle", mode = "fill", color = {0.92, 0.54, 0.12, 0.95}, x = 0, y = 0, r = 44 },
            { type = "circle", mode = "fill", color = {0.32, 0.12, 0.06, 0.9}, x = 0, y = 0, r = 26 },
            { type = "circle", mode = "line", color = {1.0, 0.78, 0.32, 0.9}, width = 5, x = 0, y = 0, r = 26 },

            -- Ore feed conveyors
            { type = "rectangle", mode = "fill", color = {0.28, 0.30, 0.36, 0.95}, x = 120, y = -16, w = 52, h = 32, rx = 6 },
            { type = "rectangle", mode = "fill", color = {0.28, 0.30, 0.36, 0.95}, x = -172, y = -16, w = 52, h = 32, rx = 6 },
            { type = "rectangle", mode = "fill", color = {0.28, 0.30, 0.36, 0.95}, x = -16, y = 120, w = 32, h = 52, rx = 6 },
            { type = "rectangle", mode = "fill", color = {0.28, 0.30, 0.36, 0.95}, x = -16, y = -172, w = 32, h = 52, rx = 6 },

            -- Radiator fins on diagonals
            { type = "rectangle", mode = "fill", color = {0.36, 0.40, 0.46, 0.85}, x = -92, y = -92, w = 140, h = 22, rotation = 0.785 },
            { type = "rectangle", mode = "fill", color = {0.36, 0.40, 0.46, 0.85}, x = -92, y = 92, w = 140, h = 22, rotation = -0.785 },

            -- Exhaust stacks with glowing vents
            { type = "rectangle", mode = "fill", color = {0.18, 0.20, 0.26, 0.95}, x = 142, y = -20, w = 32, h = 60, rx = 6 },
            { type = "rectangle", mode = "fill", color = {0.18, 0.20, 0.26, 0.95}, x = -190, y = -20, w = 32, h = 60, rx = 6 },
            { type = "rectangle", mode = "fill", color = {0.18, 0.20, 0.26, 0.95}, x = -20, y = 142, w = 60, h = 32, rx = 6 },
            { type = "rectangle", mode = "fill", color = {0.18, 0.20, 0.26, 0.95}, x = -20, y = -190, w = 60, h = 32, rx = 6 },
            { type = "rectangle", mode = "fill", color = {0.98, 0.42, 0.08, 0.8}, x = 144, y = -8, w = 24, h = 18 },
            { type = "rectangle", mode = "fill", color = {0.98, 0.42, 0.08, 0.8}, x = -184, y = -8, w = 24, h = 18 },
            { type = "rectangle", mode = "fill", color = {0.98, 0.42, 0.08, 0.8}, x = -8, y = 144, w = 18, h = 24 },
            { type = "rectangle", mode = "fill", color = {0.98, 0.42, 0.08, 0.8}, x = -8, y = -184, w = 18, h = 24 },

            -- Docking pylons for freighters
            { type = "circle", mode = "fill", color = {0.62, 0.88, 1.0, 0.92}, x = 134, y = 0, r = 10 },
            { type = "circle", mode = "fill", color = {0.62, 0.88, 1.0, 0.92}, x = -134, y = 0, r = 10 },
            { type = "circle", mode = "fill", color = {0.62, 0.88, 1.0, 0.92}, x = 0, y = 134, r = 10 },
            { type = "circle", mode = "fill", color = {0.62, 0.88, 1.0, 0.92}, x = 0, y = -134, r = 10 },
        }
    },
}
