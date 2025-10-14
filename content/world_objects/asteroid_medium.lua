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

    -- Collision shape will be derived from visual shapes automatically
    collidable = {
        shape = "polygon",
        -- vertices will be auto-generated from visuals.shapes
    },

    mineable = {
        resourceType = "ore_tritanium",
        resources = 30,
        durability = 15.0,  -- Increased significantly for longer mining sessions
    },

    -- This component is the single source of truth for all physics properties.
    -- The WindfieldManager reads this directly to create the physics body.
    windfield_physics = {
        bodyType = "dynamic", -- Dynamic means it can be moved and pushed.
        mass = 72, -- A standard mass for a medium asteroid.
        fixedRotation = false, -- Allows the asteroid to spin when hit.
        colliderType = "polygon",
        vertices = {
            -25, -15, -15, -25, 15, -25, 25, -15,
            25, 15, -25, 15,
        }
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
        },
        -- Single source of truth for both visual and collision shapes
        -- Using 6 vertices (hexagon) to stay well within Box2D's 8-vertex limit
        shapes = {
            {
                type = "polygon",
                mode = "fill",
                color = {0.45, 0.5, 0.55, 1.0},
                points = {
                    {-25, -15},  -- Top-left
                    {-15, -25},  -- Top
                    {15, -25},   -- Top-right
                    {25, -15},   -- Right
                    {25, 15},    -- Bottom-right
                    {-25, 15},   -- Bottom-left
                }
            },
            {
                type = "polygon",
                mode = "line",
                color = {0.3, 0.35, 0.4, 1.0},
                points = {
                    {-25, -15},  -- Top-left
                    {-15, -25},  -- Top
                    {15, -25},   -- Top-right
                    {25, -15},   -- Right
                    {25, 15},    -- Bottom-right
                    {-25, 15},   -- Bottom-left
                }
            }
        }
    }
}
