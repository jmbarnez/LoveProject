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
        shape = "polygon",
        vertices = {
            -30, -20,  -- Top-left
            -20, -30,  -- Top
            20, -30,   -- Top-right
            30, -20,   -- Right
            30, 20,    -- Bottom-right
            20, 30,    -- Bottom
            -20, 30,   -- Bottom-left
            -30, 20,   -- Left
        }
    },

    mineable = {
        resourceType = "ore_palladium",
        resources = 15,  -- Medium amount of palladium
        durability = 18.0,  -- Increased significantly for longer mining sessions
    },

    windfield_physics = {
        colliderType = "polygon",
        mass = 90,
        restitution = 0.3,
        friction = 0.1,
        fixedRotation = false,
        bodyType = "dynamic",
        vertices = {
            -30, -20,  -- Top-left
            -20, -30,  -- Top
            20, -30,   -- Top-right
            30, -20,   -- Right
            30, 20,    -- Bottom-right
            20, 30,    -- Bottom
            -20, 30,   -- Bottom-left
            -30, 20,   -- Left
        },
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
