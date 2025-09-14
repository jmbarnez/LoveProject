-- Data definition for a standard gun projectile.
return {
    id = "gun_bullet",
    name = "Kinetic Slug",
    class = "Projectile",

    physics = {
        speed = 4800,
        drag = 0, -- No drag for simple bullets
    },

    renderable = {
        type = "bullet",
        props = {
            kind = "bullet",
            radius = 2,
            color = {0.35, 0.70, 1.00, 1.0},
        }
    },

    damage = {
        value = 2,
    },

    timed_life = {
        duration = 2.5,
    }
}
