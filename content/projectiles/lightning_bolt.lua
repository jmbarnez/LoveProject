return {
    id = "lightning_bolt",
    name = "Lightning Bolt",
    class = "Projectile",

    physics = {
        speed = 2000,
        drag = 0,
    },

    renderable = {
        type = "bullet",
        props = {
            kind = "lightning",
            length = 10,
            tracerWidth = 3,
            angle = 0,
            color = {1.0, 1.0, 0.5, 1.0}
        }
    },

    collidable = {
        radius = 5,
    },

    damage = 10,

    timed_life = {
        duration = 0.5,
    },

    chaining = {
        chain_radius = 500,
        max_chains = 3,
        damage_falloff = 0.75,
    }
}
