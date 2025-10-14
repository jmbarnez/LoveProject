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
    
    collidable = {
        shape = "polygon",
        vertices = {
            -25, -15,  -- Top-left
            -25, 15,   -- Bottom-left
            25, 15,    -- Bottom-right
            25, -15,   -- Top-right
        },
        isTrigger = false
    },
    
    interactable = {
        range = 25,
        requiresKey = "reward_crate_key"
    },
    
    windfield_physics = {
        colliderType = "polygon",
        mass = 5,
        restitution = 0.1,
        friction = 0.8,
        fixedRotation = false,
        bodyType = "dynamic",
        vertices = {
            -25, -15,  -- Top-left
            -25, 15,   -- Bottom-left
            25, 15,    -- Bottom-right
            25, -15,   -- Top-right
        },
    },
}