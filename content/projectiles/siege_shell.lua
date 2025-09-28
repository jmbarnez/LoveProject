return {
    id = "siege_shell",
    name = "Siege Shell",
    class = "Projectile",
    physics = {
        speed = 2200,
        drag = 0.05,
    },
    renderable = {
        type = "bullet",
        props = {
            kind = "shell",
            radius = 3.4,
            color = {0.95, 0.75, 0.45, 0.9},
        }
    },
    damage = {
        value = 6.2,
        splash = 120,
    },
    timed_life = {
        duration = 3.4,
    }
}
