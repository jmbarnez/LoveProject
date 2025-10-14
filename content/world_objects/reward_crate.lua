return {
    id = "reward_crate",
    name = "Reward Crate",
    description = "A sealed container that hums with latent energy. Requires a reward key to open.",
    
    renderable = {
        type = "reward_crate",
        props = {
            radius = 25,
            size = 1.0
        }
    },
    
    -- Simple rectangle collision shape - matches visual exactly
    collidable = {
        shape = "polygon",
        vertices = {
            -25, -15,  -- Top-left
            -25, 15,   -- Bottom-left
            25, 15,    -- Bottom-right
            25, -15,   -- Top-right
        }
    },
    
    interactable = {
        range = 25,
        requiresKey = "reward_crate_key"
    },

    -- By adding the windfield_physics component, the crate becomes part of the physics world.
    -- We define it as a "dynamic" body, which means it can be moved and pushed.
    -- To make it feel heavy, like a station, we give it a very high mass.
    windfield_physics = {
        bodyType = "dynamic",
        mass = 5000, -- A high mass makes it very resistant to movement.
        fixedRotation = true -- Prevents it from spinning when hit.
    }
}