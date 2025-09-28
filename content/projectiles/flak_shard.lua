return {
    id = "flak_shard",
    name = "Flak Shard",
    class = "Projectile",
    physics = {
        speed = 3200,
        drag = 0.15,
    },
    renderable = {
        type = "bullet",
        props = {
            kind = "fragment",
            radius = 2.0,
            color = {1.00, 0.75, 0.35, 0.9},
        }
    },
    damage = {
        value = 3,
        splash = 80,
    },
    timed_life = {
        duration = 1.8,
    }
}
