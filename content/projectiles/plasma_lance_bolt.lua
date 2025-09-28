return {
    id = "plasma_lance_bolt",
    name = "Plasma Lance Bolt",
    class = "Projectile",
    physics = {
        speed = 5200,
        drag = 0.05,
    },
    renderable = {
        type = "bullet",
        props = {
            kind = "plasma",
            radius = 2.4,
            color = {0.90, 0.45, 1.00, 1.0},
        }
    },
    damage = {
        value = 5.2,
    },
    timed_life = {
        duration = 2.5,
    }
}
