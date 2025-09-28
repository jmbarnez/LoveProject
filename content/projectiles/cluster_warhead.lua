return {
    id = "cluster_warhead",
    name = "Cluster Warhead",
    class = "Projectile",
    physics = {
        speed = 700,
        drag = 0,
    },
    renderable = {
        type = "bullet",
        props = {
            kind = "missile",
            radius = 4.0,
            color = {1.00, 0.50, 0.20, 0.9},
        }
    },
    damage = {
        value = 5.0,
        bomblets = 6,
        splash = 90,
    },
    timed_life = {
        duration = 4.5,
    }
}
