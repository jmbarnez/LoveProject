return {
    id = "void_lance_beam",
    name = "Void Lance Beam",
    class = "Projectile",
    physics = {
        speed = 5600,
        drag = 0,
    },
    renderable = {
        type = "bullet",
        props = {
            kind = "beam",
            radius = 2.2,
            color = {0.85, 0.40, 1.00, 0.95},
        }
    },
    damage = {
        value = 5.5,
        shieldBypass = 0.6,
        energyLeech = 3.0,
    },
    timed_life = {
        duration = 3.0,
    }
}
