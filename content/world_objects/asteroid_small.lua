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
        shape = "polygon",
        vertices = {
            -20, -8,   -- Top-left
            -24, 0,    -- Left
            -8, 20,    -- Bottom-left
            0, 24,     -- Bottom
            8, 20,     -- Bottom-right
            20, 8,     -- Right
            24, 0,     -- Right
            0, -24,    -- Top
        }
    },

    mineable = {
        resourceType = "ore_tritanium",
        resources = 15,
        durability = 8.0,  -- Increased significantly for longer mining sessions
    },

    windfield_physics = {
        colliderType = "polygon",
        mass = 48,
        restitution = 0.3,
        friction = 0.1,
        fixedRotation = false,
        bodyType = "dynamic",
        vertices = {
            -20, -8,   -- Top-left
            -24, 0,    -- Left
            -8, 20,    -- Bottom-left
            0, 24,     -- Bottom
            8, 20,     -- Bottom-right
            20, 8,     -- Right
            24, 0,     -- Right
            0, -24,    -- Top
        },
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
