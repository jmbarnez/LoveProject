return {
    id = "fusion_pulse_beam",
    name = "Fusion Pulse Beam",
    class = "Projectile",
    physics = {
        speed = 5000,
        drag = 0,
    },
    renderable = {
        type = "bullet",
        props = {
            kind = "beam",
            radius = 2.0,
            color = {1.00, 0.60, 0.20, 0.95},
        }
    },
    damage = {
        value = 4.8,
    },
    timed_life = {
        duration = 2.8,
    }
}
