return {
    id = "inferno_stream",
    name = "Inferno Stream",
    class = "Projectile",
    physics = {
        speed = 4600,
        drag = 0.05,
    },
    renderable = {
        type = "bullet",
        props = {
            kind = "flame",
            radius = 2.2,
            color = {1.00, 0.45, 0.05, 0.95},
        }
    },
    damage = {
        value = 3.5,
        damageOverTime = { amount = 1.5, duration = 3.5 },
    },
    timed_life = {
        duration = 1.8,
    }
}
