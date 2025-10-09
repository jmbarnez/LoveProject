-- Data definition for a small palladium asteroid with visible mineral chunks.
return {
    id = "asteroid_small_palladium",
    name = "Small Palladium Asteroid",
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
                    {0.8, 0.8, 0.9, 1.0},        -- Palladium colors
                    {0.9, 0.9, 1.0, 1.0},
                },
                chunkOutline = {0.6, 0.6, 0.7, 1.0},
            },
        }
    },

    collidable = {
        shape = "polygon",
        vertices = {
            -20, -8,   -- Top-left
            -24, 0,    -- Left
            -20, 8,    -- Bottom-left
            -8, 20,    -- Bottom-left
            0, 24,     -- Bottom
            8, 20,     -- Bottom-right
            20, 8,     -- Right
            24, 0,     -- Right
            20, -8,    -- Top-right
            8, -20,    -- Top-right
            0, -24,    -- Top
            -8, -20,   -- Top-left
        }
    },

    mineable = {
        resourceType = "ore_palladium",
        resources = 8,  -- Small amount of palladium
        durability = 10.0,  -- Increased significantly for longer mining sessions
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
            },
            chunkOutline = {0.6, 0.6, 0.7, 1.0},
        }
    }
}
