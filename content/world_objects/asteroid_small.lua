-- Data definition for a small, jagged asteroid with visible mineral chunks.
return {
    id = "asteroid_small",
    name = "Small Asteroid",
    class = "WorldObject",

    renderable = {
        type = "asteroid",
        props = {
            size = "small",
            chunkOptions = {
                chunkCount = {1, 2},
                chunkSize = {0.16, 0.24},
                chunkOffset = {1.0, 1.25},
                chunkSquash = {0.6, 0.9},
                chunkPalette = {
                    {0.62, 0.55, 0.48, 1.0},
                    {0.53, 0.5, 0.6, 1.0},
                },
                chunkOutline = {0.2, 0.2, 0.23, 1.0},
            },
        }
    },

    collidable = {
        radius = 24,
    },

    mineable = {
        resourceType = "stones",
        resources = 45,
        durability = 3.0,  -- Reduced from 12.0 to 3.0 (75% reduction)
    },

    visuals = {
        colors = {
            small = {0.46, 0.46, 0.5, 1.0},
            medium = {0.42, 0.42, 0.47, 1.0},
            large = {0.36, 0.36, 0.4, 1.0},
            outline = {0.22, 0.22, 0.24, 1.0},
            chunkPalette = {
                {0.68, 0.6, 0.5, 1.0},
                {0.57, 0.53, 0.64, 1.0},
            },
            chunkOutline = {0.2, 0.2, 0.23, 1.0},
        }
    }
}
