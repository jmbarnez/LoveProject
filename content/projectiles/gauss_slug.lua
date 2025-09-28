return {
    id = "gauss_slug",
    name = "Gauss Slug",
    class = "Projectile",
    physics = {
        speed = 6000,
        drag = 0,
    },
    renderable = {
        type = "bullet",
        props = {
            kind = "slug",
            radius = 3.2,
            color = {0.65, 0.85, 1.00, 1.0},
        }
    },
    damage = {
        value = 6,
    },
    timed_life = {
        duration = 3.5,
    }
}
