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
        resourceType = "ore_tritanium",
        resources = 15,
        durability = 1.5,  -- Reduced from 3.0 to 1.5 (50% reduction)
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
            },
            chunkOutline = {0.3, 0.35, 0.4, 1.0},
        }
    }
}
