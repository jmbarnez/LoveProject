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
            -20, -15,  -- Top-left
            -25, -10,  -- Left-top
            -25, 10,   -- Left-bottom
            -20, 15,   -- Bottom-left
            -10, 20,   -- Bottom-left
            10, 20,    -- Bottom-right
            20, 15,    -- Right-bottom
            25, 10,    -- Right
            25, -10,   -- Right-top
            20, -15,   -- Top-right
            10, -20,   -- Top-right
            -10, -20,  -- Top-left
        },
        isTrigger = false
    },
    
    interactable = {
        range = 25,
        requiresKey = "reward_crate_key"
    },
    
    physics = {
        mass = 200,
        radius = 25
    }
}