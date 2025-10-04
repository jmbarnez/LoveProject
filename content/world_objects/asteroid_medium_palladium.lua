-- Data definition for a medium-sized palladium asteroid.
return {
    id = "asteroid_medium_palladium",
    name = "Palladium Asteroid",
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
                    {0.8, 0.8, 0.9, 1.0},        -- Palladium colors
                    {0.9, 0.9, 1.0, 1.0},
                    {0.7, 0.7, 0.8, 1.0},
                },
                chunkOutline = {0.6, 0.6, 0.7, 1.0},
            },
        }
    },

    collidable = {
        radius = 36,
    },

    mineable = {
        resourceType = "ore_palladium",
        resources = 15,  -- Medium amount of palladium
        durability = 2.5,
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
