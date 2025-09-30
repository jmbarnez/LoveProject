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

    description = "A sprawling refinery that superheats ore shipments into refined alloys.",

    visuals = {
        size = 6.0,
        shapes = {
            -- Outer thermal shield ring
            { type = "circle", mode = "line", color = {0.95, 0.45, 0.05, 0.75}, x = 0, y = 0, r = 48, width = 6 },
            { type = "circle", mode = "line", color = {0.40, 0.12, 0.02, 0.6}, x = 0, y = 0, r = 60, width = 3 },

            -- Massive heat exchanger arms
            { type = "rectangle", mode = "fill", color = {0.55, 0.58, 0.65, 0.85}, x = -80, y = -6, w = 160, h = 12, rx = 3 },
            { type = "rectangle", mode = "fill", color = {0.55, 0.58, 0.65, 0.85}, x = -6, y = -80, w = 12, h = 160, rx = 3 },
            { type = "rectangle", mode = "fill", color = {0.45, 0.48, 0.55, 0.8}, x = -56, y = -4, w = 112, h = 8, rx = 3, rotation = 0.785 },
            { type = "rectangle", mode = "fill", color = {0.45, 0.48, 0.55, 0.8}, x = -56, y = 0, w = 112, h = 8, rx = 3, rotation = -0.785 },

            -- Core furnace chamber
            { type = "circle", mode = "fill", color = {0.95, 0.65, 0.10, 0.95}, x = 0, y = 0, r = 36 },
            { type = "circle", mode = "fill", color = {0.40, 0.10, 0.02, 0.9}, x = 0, y = 0, r = 22 },
            { type = "circle", mode = "line", color = {1.0, 0.85, 0.35, 0.9}, x = 0, y = 0, r = 22, width = 4 },

            -- Feedstock intake conduits
            { type = "rectangle", mode = "fill", color = {0.30, 0.32, 0.38, 0.9}, x = 82, y = -10, w = 30, h = 20, rx = 4 },
            { type = "rectangle", mode = "fill", color = {0.30, 0.32, 0.38, 0.9}, x = -112, y = -10, w = 30, h = 20, rx = 4 },
            { type = "rectangle", mode = "fill", color = {0.30, 0.32, 0.38, 0.9}, x = -10, y = 82, w = 20, h = 30, rx = 4 },
            { type = "rectangle", mode = "fill", color = {0.30, 0.32, 0.38, 0.9}, x = -10, y = -112, w = 20, h = 30, rx = 4 },

            -- Exhaust radiators with glowing vents
            { type = "rectangle", mode = "fill", color = {0.22, 0.24, 0.30, 0.9}, x = 108, y = -18, w = 24, h = 36, rx = 4 },
            { type = "rectangle", mode = "fill", color = {0.22, 0.24, 0.30, 0.9}, x = -132, y = -18, w = 24, h = 36, rx = 4 },
            { type = "rectangle", mode = "fill", color = {0.22, 0.24, 0.30, 0.9}, x = -18, y = 108, w = 36, h = 24, rx = 4 },
            { type = "rectangle", mode = "fill", color = {0.22, 0.24, 0.30, 0.9}, x = -18, y = -132, w = 36, h = 24, rx = 4 },
            { type = "rectangle", mode = "fill", color = {0.95, 0.45, 0.05, 0.8}, x = 112, y = -6, w = 16, h = 12 },
            { type = "rectangle", mode = "fill", color = {0.95, 0.45, 0.05, 0.8}, x = -128, y = -6, w = 16, h = 12 },
            { type = "rectangle", mode = "fill", color = {0.95, 0.45, 0.05, 0.8}, x = -6, y = 112, w = 12, h = 16 },
            { type = "rectangle", mode = "fill", color = {0.95, 0.45, 0.05, 0.8}, x = -6, y = -128, w = 12, h = 16 },

            -- Docking pylons for freighters
            { type = "circle", mode = "fill", color = {0.60, 0.85, 1.0, 0.9}, x = 96, y = 0, r = 8 },
            { type = "circle", mode = "fill", color = {0.60, 0.85, 1.0, 0.9}, x = -96, y = 0, r = 8 },
            { type = "circle", mode = "fill", color = {0.60, 0.85, 1.0, 0.9}, x = 0, y = 96, r = 8 },
            { type = "circle", mode = "fill", color = {0.60, 0.85, 1.0, 0.9}, x = 0, y = -96, r = 8 },
        }
    },
}
