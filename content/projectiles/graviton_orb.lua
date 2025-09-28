return {
    id = "graviton_orb",
    name = "Graviton Orb",
    class = "Projectile",
    physics = {
        speed = 2600,
        drag = 0.04,
    },
    renderable = {
        type = "bullet",
        props = {
            kind = "orb",
            radius = 3.0,
            color = {0.65, 0.55, 1.00, 0.9},
        }
    },
    damage = {
        value = 3.8,
        gravityWell = { radius = 180, force = 140, duration = 2.5 },
    },
    timed_life = {
        duration = 3.2,
    }
}
