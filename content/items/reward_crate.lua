return {
    id = "reward_crate",
    name = "Reward Crate",
    type = "consumable",
    rarity = "Common",
    tier = 1,
    stack = 5,
    value = 0,
    price = 0,
    mass = 1.0,
    volume = 1.0,
    tags = { "crate", "reward", "consumable" },
    description = "A sealed container that hums with latent energy. Use it while holding a reward key to crack it open.",
    flavor = "The outer shell bears the insignia of forgotten contractors.",
    consumable = true,
    icon = {
        size = 32,
        shapes = {
            { type = "rectangle", mode = "fill", color = {0.18, 0.2, 0.28, 1.0}, x = 6, y = 8, w = 20, h = 16, rx = 3, ry = 3 },
            { type = "rectangle", mode = "line", color = {0.42, 0.46, 0.68, 1.0}, x = 6, y = 8, w = 20, h = 16, rx = 3, ry = 3, width = 2 },
            { type = "rectangle", mode = "fill", color = {0.26, 0.3, 0.46, 1.0}, x = 6, y = 14, w = 20, h = 4 },
            { type = "rectangle", mode = "fill", color = {0.95, 0.8, 0.3, 1.0}, x = 14, y = 9, w = 4, h = 14 },
            { type = "rectangle", mode = "fill", color = {0.98, 0.9, 0.55, 1.0}, x = 14, y = 14, w = 4, h = 4 },
            { type = "circle", mode = "fill", color = {0.9, 0.6, 0.2, 1.0}, x = 16, y = 20, r = 2 },
        }
    }
}
