-- Data definition for a guided missile projectile.
return {
    id = "missile",
    name = "Guided Missile",
    class = "Projectile",

    physics = {
        speed = 600,
        drag = 0,
    },

    renderable = {
        type = "bullet",
        props = {
            kind = "missile",
            radius = 4,
            color = {1.0, 0.7, 0.25, 1.0}
        }
    },

    damage = {
        value = 15,
    },

    timed_life = {
        duration = 4.0,
    }
}