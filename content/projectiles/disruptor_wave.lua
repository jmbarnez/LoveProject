return {
    id = "disruptor_wave",
    name = "Disruptor Wave",
    class = "Projectile",
    physics = {
        speed = 5400,
        drag = 0.02,
    },
    renderable = {
        type = "bullet",
        props = {
            kind = "wave",
            radius = 2.6,
            color = {0.45, 0.95, 1.00, 0.9},
        }
    },
    damage = {
        value = 4.2,
        shieldBreaker = 1.6,
    },
    timed_life = {
        duration = 3.0,
    }
}
