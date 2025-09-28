return {
    id = "rail_lance_spike",
    name = "Rail Spike",
    class = "Projectile",
    physics = {
        speed = 7200,
        drag = 0,
    },
    renderable = {
        type = "bullet",
        props = {
            kind = "spike",
            radius = 2.2,
            color = {0.80, 0.95, 1.00, 1.0},
        }
    },
    damage = {
        value = 7.5,
    },
    timed_life = {
        duration = 3.8,
    }
}
