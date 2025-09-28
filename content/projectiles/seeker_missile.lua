return {
    id = "seeker_missile",
    name = "Seeker Missile",
    class = "Projectile",
    physics = {
        speed = 950,
        drag = 0,
    },
    renderable = {
        type = "bullet",
        props = {
            kind = "missile",
            radius = 3.4,
            color = {0.00, 0.85, 1.00, 0.9},
        }
    },
    damage = {
        value = 3.6,
    },
    timed_life = {
        duration = 4.8,
    }
}
