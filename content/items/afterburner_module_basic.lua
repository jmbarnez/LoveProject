return {
    id = "afterburner_module_basic",
    name = "Basic Afterburner Module",
    type = "module",
    subtype = "movement",
    description = "A basic afterburner module that provides temporary speed boost when equipped in a movement slot.",
    value = 200,        -- GC
    price = 1000,       -- GC
    rarity = "Common",
    mass = 4,           -- kg
    volume = 2,         -- u³
    stack = 1,
    tags = {"movement", "module", "speed", "afterburner"},
    flavor = "Standard issue afterburner system for enhanced propulsion.",
    icon = {
        size = 32,
        shapes = {
            {
                type = "rect",
                x = 6, y = 6, w = 20, h = 20,
                color = {1.0, 0.4, 0.0, 1.0},
                mode = "fill"
            },
            {
                type = "rect", 
                x = 8, y = 8, w = 16, h = 16,
                color = {1.0, 0.6, 0.2, 1.0},
                mode = "line",
                lineWidth = 2
            },
            {
                type = "circle",
                x = 16, y = 16, r = 5,
                color = {1.0, 0.8, 0.4, 1.0},
                mode = "fill"
            },
            -- Flame effects
            {
                type = "line",
                x1 = 4, y1 = 12, x2 = 6, y2 = 12,
                color = {1.0, 0.6, 0.0, 0.8},
                lineWidth = 3
            },
            {
                type = "line",
                x1 = 4, y1 = 16, x2 = 6, y2 = 16,
                color = {1.0, 0.8, 0.2, 0.9},
                lineWidth = 4
            },
            {
                type = "line",
                x1 = 4, y1 = 20, x2 = 6, y2 = 20,
                color = {1.0, 0.6, 0.0, 0.8},
                lineWidth = 3
            },
            {
                type = "line",
                x1 = 26, y1 = 12, x2 = 28, y2 = 12,
                color = {1.0, 0.6, 0.0, 0.8},
                lineWidth = 3
            },
            {
                type = "line",
                x1 = 26, y1 = 16, x2 = 28, y2 = 16,
                color = {1.0, 0.8, 0.2, 0.9},
                lineWidth = 4
            },
            {
                type = "line",
                x1 = 26, y1 = 20, x2 = 28, y2 = 20,
                color = {1.0, 0.6, 0.0, 0.8},
                lineWidth = 3
            }
        }
    },
    -- Module properties
    module = {
        type = "movement",
        ability_type = "afterburner",
        slot_type = "movement",
        passive = false,  -- Active module - shows on hotbar
        -- Afterburner specific properties
        max_charge = 100,        -- Maximum charge
        charge_rate = 25,        -- Charge per second
        drain_rate = 50,         -- Drain per second when active
        speed_multiplier = 2.0,  -- Speed boost multiplier
        cooldown = 1.0,          -- Cooldown after depletion
        energy_cost = 0          -- Energy cost per second (0 = no energy cost)
    }
}
