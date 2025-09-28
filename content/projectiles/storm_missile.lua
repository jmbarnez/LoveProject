return {
    id = "storm_missile",
    name = "Storm Missile",
    class = "Projectile",
    physics = {
        speed = 900,
        drag = 0,
    },
    renderable = {
        type = "bullet",
        props = {
            kind = "missile",
            radius = 3.2,
            color = {1.00, 0.65, 0.25, 0.9},
        }
    },
    damage = {
        value = 3.0,
        splash = 60,
    },
    timed_life = {
        duration = 4.2,
    }
}
