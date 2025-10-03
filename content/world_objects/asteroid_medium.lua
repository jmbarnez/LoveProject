-- Data definition for a medium-sized, standard asteroid.
return {
    id = "asteroid_medium",
    name = "Asteroid",
    class = "WorldObject",

    renderable = {
        type = "asteroid",
        props = {
            size = "medium",
            chunkOptions = {
                chunkCount = {2, 4},
                chunkSize = {0.2, 0.32},
                chunkOffset = {1.05, 1.35},
                chunkSquash = {0.6, 0.95},
                chunkPalette = {
                    {0.58, 0.51, 0.46, 1.0},
                    {0.52, 0.47, 0.55, 1.0},
                    {0.63, 0.56, 0.48, 1.0},
                },
                chunkOutline = {0.18, 0.18, 0.2, 1.0},
            },
        }
    },

    collidable = {
        radius = 36,
    },

    mineable = {
        resourceType = "ore_tritanium",
        resources = 30,
        durability = 2.5,  -- Reduced from 5.0 to 2.5 (50% reduction)
    },

    visuals = {
        colors = {
            small = {0.5, 0.55, 0.6, 1.0},    -- Tritanium blue-gray
            medium = {0.45, 0.5, 0.55, 1.0},
            large = {0.4, 0.45, 0.5, 1.0},
            outline = {0.3, 0.35, 0.4, 1.0},
            chunkPalette = {
                {0.5, 0.55, 0.6, 1.0},        -- Tritanium colors
                {0.4, 0.45, 0.5, 1.0},
                {0.6, 0.65, 0.7, 1.0},
            },
            chunkOutline = {0.3, 0.35, 0.4, 1.0},
        }
    }
}
