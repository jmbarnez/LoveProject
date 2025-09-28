return {
    id = "rapid_burst_round",
    name = "Burst Micro-Slug",
    class = "Projectile",
    physics = {
        speed = 4200,
        drag = 0,
    },
    renderable = {
        type = "bullet",
        props = {
            kind = "bullet",
            radius = 1.6,
            color = {0.35, 0.80, 1.00, 0.9},
        }
    },
    damage = {
        value = 1.2,
    },
    timed_life = {
        duration = 2.0,
    }
}
