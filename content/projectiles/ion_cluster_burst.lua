return {
    id = "ion_cluster_burst",
    name = "Ion Cluster Burst",
    class = "Projectile",
    physics = {
        speed = 4400,
        drag = 0.05,
    },
    renderable = {
        type = "bullet",
        props = {
            kind = "ion",
            radius = 2.0,
            color = {0.55, 0.95, 1.00, 0.9},
        }
    },
    damage = {
        value = 3.0,
        ionChance = 0.35,
    },
    timed_life = {
        duration = 2.4,
    }
}
