local HUDRegistry = require("src.ui.hud.registry")

HUDRegistry.register({
    id = "tooltip_manager",
    priority = 950, -- Very high priority - above most UI but below cursor
    loader = function()
        return require("src.ui.tooltip_manager")
    end,
    update = function(module, dt)
        if module.update then
            module.update(dt)
        end
    end,
    draw = function(module)
        if module and module.draw then
            module.draw()
        end
    end,
})
