return {
    id = "breach_round",
    name = "Breach Round",
    class = "Projectile",
    physics = {
        speed = 5600,
        drag = 0,
    },
    renderable = {
        type = "bullet",
        props = {
            kind = "slug",
            radius = 2.4,
            color = {1.00, 0.55, 0.35, 0.9},
        }
    },
    damage = {
        value = 5.8,
        subsystemDamage = 1.5,
    },
    timed_life = {
        duration = 3.0,
    }
}
