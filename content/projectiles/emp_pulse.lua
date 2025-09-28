return {
    id = "emp_pulse",
    name = "EMP Pulse",
    class = "Projectile",
    physics = {
        speed = 3200,
        drag = 0.02,
    },
    renderable = {
        type = "bullet",
        props = {
            kind = "pulse",
            radius = 3.0,
            color = {0.35, 0.90, 1.00, 0.85},
        }
    },
    damage = {
        value = 1.8,
        empStrength = { shield = 2.2, systems = 1.6, duration = 3.5 },
    },
    timed_life = {
        duration = 3.2,
    }
}
