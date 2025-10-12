return {
    id = "dash_module_basic",
    name = "Basic Dash Module",
    type = "module",
    subtype = "ability",
    description = "A basic dash module that provides enhanced dash capabilities when equipped in an ability slot.",
    value = 150,        -- GC
    price = 750,        -- GC
    rarity = "Common",
    mass = 3,           -- kg
    volume = 1.5,       -- u³
    stack = 1,
    tags = {"ability", "module", "movement", "dash"},
    flavor = "Standard issue thruster enhancement for improved maneuverability.",
    icon = {
        size = 32,
        shapes = {
            {
                type = "rect",
                x = 8, y = 8, w = 16, h = 16,
                color = {0.2, 0.6, 1.0, 1.0},
                mode = "fill"
            },
            {
                type = "rect", 
                x = 10, y = 10, w = 12, h = 12,
                color = {0.4, 0.8, 1.0, 1.0},
                mode = "line",
                lineWidth = 2
            },
            {
                type = "circle",
                x = 16, y = 16, r = 4,
                color = {0.6, 0.9, 1.0, 1.0},
                mode = "fill"
            },
            -- Thruster lines
            {
                type = "line",
                x1 = 4, y1 = 16, x2 = 8, y2 = 16,
                color = {0.8, 0.9, 1.0, 1.0},
                lineWidth = 2
            },
            {
                type = "line",
                x1 = 24, y1 = 16, x2 = 28, y2 = 16,
                color = {0.8, 0.9, 1.0, 1.0},
                lineWidth = 2
            },
            {
                type = "line",
                x1 = 16, y1 = 4, x2 = 16, y2 = 8,
                color = {0.8, 0.9, 1.0, 1.0},
                lineWidth = 2
            },
            {
                type = "line",
                x1 = 16, y1 = 24, x2 = 16, y2 = 28,
                color = {0.8, 0.9, 1.0, 1.0},
                lineWidth = 2
            }
        }
    },
    -- Module properties
    module = {
        type = "ability",
        ability_type = "dash",
        slot_type = "ability"
    }
}
