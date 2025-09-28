return {
    id = "tidal_wave",
    name = "Tidal Wave",
    class = "Projectile",
    physics = {
        speed = 3400,
        drag = 0.03,
    },
    renderable = {
        type = "bullet",
        props = {
            kind = "wave",
            radius = 2.6,
            color = {0.30, 0.75, 1.00, 0.85},
        }
    },
    damage = {
        value = 2.2,
        knockbackForce = 280,
        waveRadius = 220,
    },
    timed_life = {
        duration = 3.0,
    }
}
