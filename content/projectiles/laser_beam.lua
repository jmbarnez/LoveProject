-- Data definition for a laser beam projectile.
return {
    id = "laser_beam",
    name = "Laser Beam",
    class = "Projectile",

    physics = {
        speed = 0, -- Beams should not advance position; collision handles ray
        drag = 0,
    },

    renderable = {
        type = "bullet",
        props = {
            kind = "laser",
            length = 1500, -- Maximum beam length
            tracerWidth = 4,
            angle = 0, -- Will be set when fired
            color = {0.30, 0.85, 1.00, 0.9}
        }
    },

    -- Enable collision and damage for laser beams so hits are detected and applied
    collidable = {
        radius = 2, -- small collision radius so the beam is included in collision queries
    },

    -- Default damage for the beam; can be overridden when firing via opts.damage
    damage = 15,

    timed_life = {
        -- Charged pulse effect: buildup + flash then immediate disappear
        duration = 0.15, -- 0.1s buildup + 0.05s flash
    },

    -- Charged pulse effect properties
    charged_pulse = {
        buildup_time = 0.1,  -- Energy charging phase
        flash_time = 0.05,   -- Intense beam flash
    }
}
