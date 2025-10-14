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
        shape = "polygon",
        vertices = {
            -40, -25,  -- Top-left
            -25, -40,  -- Top
            25, -40,   -- Top-right
            40, -25,   -- Right
            40, 25,    -- Bottom-right
            25, 40,    -- Bottom
            -25, 40,   -- Bottom-left
            -40, 25,   -- Left
        }
    },

    mineable = {
        resourceType = "ore_palladium",
        resources = 8,
        durability = 20.0,  -- Increased significantly for longer mining sessions
    },

    windfield_physics = {
        colliderType = "polygon",
        mass = 104,
        restitution = 0.3,
        friction = 0.1,
        fixedRotation = false,
        bodyType = "dynamic",
        vertices = {
            -40, -25,  -- Top-left
            -25, -40,  -- Top
            25, -40,   -- Top-right
            40, -25,   -- Right
            40, 25,    -- Bottom-right
            25, 40,    -- Bottom
            -25, 40,   -- Bottom-left
            -40, 25,   -- Left
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
