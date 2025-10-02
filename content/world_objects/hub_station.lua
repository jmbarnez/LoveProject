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
        vertices = {
            -100, -12,
            -70, -12,
            -70, -40,
            -12, -40,
            -12, -100,
            12, -100,
            12, -40,
            70, -40,
            70, -12,
            100, -12,
            100, 12,
            70, 12,
            70, 40,
            12, 40,
            12, 100,
            -12, 100,
            -12, 40,
            -70, 40,
            -70, 12,
            -100, 12,
        }
    },

    -- Simple Clean Station Design
    visuals = {
        size = 10.0,
        shapes = {
            -- Central station core
            { type = "circle", mode = "fill", color = {0.85, 0.88, 0.92, 0.9}, x = 0, y = 0, r = 40 },
            { type = "circle", mode = "line", color = {0.72, 0.75, 0.80, 0.9}, x = 0, y = 0, r = 40, width = 2 },
            
            -- Inner core detail
            { type = "circle", mode = "fill", color = {0.75, 0.78, 0.82, 0.8}, x = 0, y = 0, r = 20 },
            
            -- Main structural beams (connecting arms)
            { type = "rectangle", mode = "fill", color = {0.80, 0.83, 0.87, 0.9}, x = -60, y = -4, w = 120, h = 8, rx = 2 },
            { type = "rectangle", mode = "fill", color = {0.80, 0.83, 0.87, 0.9}, x = -4, y = -60, w = 8, h = 120, rx = 2 },
            
            -- Solar panels (connected to arms)
            { type = "rectangle", mode = "fill", color = {0.95, 0.75, 0.20, 0.8}, x = 70, y = -12, w = 30, h = 24, rx = 2 },
            { type = "rectangle", mode = "fill", color = {0.95, 0.75, 0.20, 0.8}, x = -100, y = -12, w = 30, h = 24, rx = 2 },
            { type = "rectangle", mode = "fill", color = {0.95, 0.75, 0.20, 0.8}, x = -12, y = 70, w = 24, h = 30, rx = 2 },
            { type = "rectangle", mode = "fill", color = {0.95, 0.75, 0.20, 0.8}, x = -12, y = -100, w = 24, h = 30, rx = 2 },
            
            -- Docking ports at ends
            { type = "circle", mode = "fill", color = {0.60, 0.90, 1.0, 0.9}, x = 65, y = 0, r = 6 },
            { type = "circle", mode = "fill", color = {0.60, 0.90, 1.0, 0.9}, x = -65, y = 0, r = 6 },
            { type = "circle", mode = "fill", color = {0.60, 0.90, 1.0, 0.9}, x = 0, y = 65, r = 6 },
            { type = "circle", mode = "fill", color = {0.60, 0.90, 1.0, 0.9}, x = 0, y = -65, r = 6 },

            -- Additional docking arms
            { type = "rectangle", mode = "fill", color = {0.80, 0.83, 0.87, 0.9}, x = -20, y = 40, w = 40, h = 4, rx = 2 },
            { type = "rectangle", mode = "fill", color = {0.80, 0.83, 0.87, 0.9}, x = -20, y = -44, w = 40, h = 4, rx = 2 },
            { type = "rectangle", mode = "fill", color = {0.80, 0.83, 0.87, 0.9}, x = 40, y = -20, w = 4, h = 40, rx = 2 },
            { type = "rectangle", mode = "fill", color = {0.80, 0.83, 0.87, 0.9}, x = -44, y = -20, w = 4, h = 40, rx = 2 },
        }
    },
}
