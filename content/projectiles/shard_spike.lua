return {
    id = "shard_spike",
    name = "Shard Spike",
    class = "Projectile",
    physics = {
        speed = 5000,
        drag = 0.02,
    },
    renderable = {
        type = "bullet",
        props = {
            kind = "spike",
            radius = 1.8,
            color = {0.90, 0.40, 0.95, 0.9},
        }
    },
    damage = {
        value = 3.2,
        bleedingChance = 0.3,
    },
    timed_life = {
        duration = 2.6,
    }
}
