return {
    id = "solar_flare",
    name = "Solar Flare",
    class = "Projectile",
    physics = {
        speed = 4400,
        drag = 0.05,
    },
    renderable = {
        type = "bullet",
        props = {
            kind = "flare",
            radius = 2.4,
            color = {1.00, 0.70, 0.20, 0.9},
        }
    },
    damage = {
        value = 3.8,
        burnRadius = 160,
        burnDamage = { amount = 1.2, duration = 4.0 },
    },
    timed_life = {
        duration = 2.6,
    }
}
