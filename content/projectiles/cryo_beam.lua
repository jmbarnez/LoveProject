return {
    id = "cryo_beam",
    name = "Cryo Beam",
    class = "Projectile",
    physics = {
        speed = 5000,
        drag = 0,
    },
    renderable = {
        type = "bullet",
        props = {
            kind = "beam",
            radius = 1.8,
            color = {0.55, 0.90, 1.00, 0.9},
        }
    },
    damage = {
        value = 2.6,
        slowEffect = { multiplier = 0.6, duration = 2.5 },
    },
    timed_life = {
        duration = 2.2,
    }
}
