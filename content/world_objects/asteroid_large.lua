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
        radius = 52,
    },

    mineable = {
        resourceType = "stones",
        resources = 140,
        durability = 30.0,
        -- Hotspot configuration
        maxHotspots = 4,
        hotspotRadius = 18,
        hotspotDamageMultiplier = 2.2,
        hotspotLifetime = 10.0,
        hotspotSpawnChance = 0.25,
        hotspotSpawnInterval = 2.5
    },

    visuals = {
        colors = {
            small = {0.42, 0.42, 0.46, 1.0},
            medium = {0.38, 0.38, 0.42, 1.0},
            large = {0.32, 0.32, 0.36, 1.0},
            outline = {0.18, 0.18, 0.2, 1.0},
            chunkPalette = {
                {0.63, 0.52, 0.48, 1.0},
                {0.52, 0.55, 0.67, 1.0},
                {0.57, 0.49, 0.58, 1.0},
            },
            chunkOutline = {0.17, 0.17, 0.19, 1.0},
        }
    }
}
