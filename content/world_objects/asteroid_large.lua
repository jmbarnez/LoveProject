-- Data definition for a large asteroid with prominent mineral protrusions.
return {
    id = "asteroid_large",
    name = "Large Asteroid",
    class = "WorldObject",

    renderable = {
        type = "asteroid",
        props = {
            size = "large",
            chunkOptions = {
                chunkCount = {3, 5},
                chunkSize = {0.24, 0.36},
                chunkOffset = {1.1, 1.4},
                chunkSquash = {0.7, 1.0},
                chunkPalette = {
                    {0.55, 0.47, 0.52, 1.0},
                    {0.61, 0.5, 0.44, 1.0},
                    {0.5, 0.52, 0.63, 1.0},
                },
                chunkOutline = {0.17, 0.17, 0.19, 1.0},
            },
        }
    },

    collidable = {
        radius = 52,
    },

    mineable = {
        resourceType = "ore_palladium",
        resources = 8,
        durability = 20.0,  -- Increased significantly for longer mining sessions
    },

    visuals = {
        colors = {
            small = {0.8, 0.8, 0.9, 1.0},    -- Palladium silvery-white
            medium = {0.75, 0.75, 0.85, 1.0},
            large = {0.7, 0.7, 0.8, 1.0},
            outline = {0.6, 0.6, 0.7, 1.0},
            chunkPalette = {
                {0.8, 0.8, 0.9, 1.0},        -- Palladium colors
                {0.9, 0.9, 1.0, 1.0},
                {0.7, 0.7, 0.8, 1.0},
            },
            chunkOutline = {0.6, 0.6, 0.7, 1.0},
        }
    }
}
