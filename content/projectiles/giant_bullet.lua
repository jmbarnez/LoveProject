-- Data definition for a giant cannon projectile.
return {
    id = "giant_bullet",
    name = "Giant Slug",
    class = "Projectile",

    physics = {
        speed = 3000,
        drag = 0, -- No drag for simple bullets
    },

    renderable = {
        type = "bullet",
        props = {
            kind = "bullet",
            radius = 6,
            color = {0.8, 0.4, 0.2, 1.0},
        }
    },

    damage = {
        value = 10,
    },

    timed_life = {
        duration = 3.0,
    }
}