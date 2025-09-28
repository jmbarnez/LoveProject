return {
    id = "scatter_pellet",
    name = "Scatter Pellet",
    class = "Projectile",
    physics = {
        speed = 3600,
        drag = 0.1,
    },
    renderable = {
        type = "bullet",
        props = {
            kind = "pellet",
            radius = 1.2,
            color = {1.00, 0.70, 0.25, 0.85},
        }
    },
    damage = {
        value = 0.9,
    },
    timed_life = {
        duration = 1.2,
    }
}
