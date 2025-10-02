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
        radius = 25,
        isTrigger = true
    },
    
    interactable = {
        range = 50,
        requiresKey = "reward_crate_key"
    }
}