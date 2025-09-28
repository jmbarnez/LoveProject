return {
    id = "nanite_cloud",
    name = "Nanite Cloud",
    class = "Projectile",
    physics = {
        speed = 2800,
        drag = 0.08,
    },
    renderable = {
        type = "bullet",
        props = {
            kind = "cloud",
            radius = 2.8,
            color = {0.45, 0.95, 0.85, 0.8},
        }
    },
    damage = {
        value = 2.0,
        healAllies = 2.0,
        naniteDuration = 3.0,
    },
    timed_life = {
        duration = 2.6,
    }
}
