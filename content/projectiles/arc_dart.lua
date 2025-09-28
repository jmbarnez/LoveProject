return {
    id = "arc_dart",
    name = "Arc Dart",
    class = "Projectile",
    physics = {
        speed = 4800,
        drag = 0.03,
    },
    renderable = {
        type = "bullet",
        props = {
            kind = "spark",
            radius = 2.0,
            color = {0.55, 0.95, 1.00, 0.9},
        }
    },
    damage = {
        value = 3.8,
        chainChance = 0.6,
        chainRange = 280,
        maxChains = 4,
        chainDamageFalloff = 0.7,
    },
    timed_life = {
        duration = 2.5,
    }
}
