return {
    id = "corrosion_stream",
    name = "Corrosion Stream",
    class = "Projectile",
    physics = {
        speed = 4200,
        drag = 0.05,
    },
    renderable = {
        type = "bullet",
        props = {
            kind = "beam",
            radius = 1.7,
            color = {0.75, 0.95, 0.45, 0.9},
        }
    },
    damage = {
        value = 2.8,
        armorCorrosion = { multiplier = 0.7, duration = 3.0 },
    },
    timed_life = {
        duration = 2.0,
    }
}
