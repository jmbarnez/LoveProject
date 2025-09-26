-- Data definition for a medium-sized, standard asteroid.
return {
    id = "asteroid_medium",
    name = "Asteroid",
    class = "WorldObject",

    renderable = {
        type = "asteroid",
        props = {
            size = "medium",
            -- The actual vertices will be generated procedurally
        }
    },

    collidable = {
        radius = 35, -- Average radius
    },

    mineable = {
        resourceType = "stones", -- drop stone items
        durability = 20.0, -- mining damage needed to destroy
    },

    visuals = {
        colors = {
            medium = {0.4, 0.4, 0.45, 1.0},
            rich = {0.8, 0.7, 0.3, 1.0}, -- Gold-ish
            dense = {0.6, 0.6, 0.7, 1.0}, -- Palladium-ish
            outline = {0.2, 0.2, 0.2, 1.0}
        }
    }
}
