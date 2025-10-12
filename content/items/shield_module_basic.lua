return {
    id = "shield_module_basic",
    name = "Basic Shield Module",
    type = "module",
    subtype = "shield",
    description = "A basic shield module that provides 5 shield HP when equipped in a shield slot.",
    value = 100,        -- GC
    price = 500,        -- GC
    rarity = "Common",
    mass = 5,           -- kg
    volume = 2,         -- u³
    stack = 1,
    tags = {"shield", "module", "defense"},
    flavor = "Standard issue shield generator for civilian vessels.",
    icon = {
        size = 32,
        shapes = {
            {
                type = "circle",
                x = 16, y = 16, r = 12,
                color = {0.2, 0.6, 1.0, 1.0},
                mode = "fill"
            },
            {
                type = "circle", 
                x = 16, y = 16, r = 9,
                color = {0.4, 0.8, 1.0, 1.0},
                mode = "line",
                lineWidth = 2
            },
            {
                type = "circle",
                x = 16, y = 16, r = 6,
                color = {0.6, 0.9, 1.0, 1.0},
                mode = "line",
                lineWidth = 1
            }
        }
    },
    -- Module properties
    module = {
        type = "shield",
        shield_hp = 50,        -- HP
        shield_regen = 0.8,    -- HP/s - much slower
        slot_type = "shield"
    }
}