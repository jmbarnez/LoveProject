local HUDRegistry = require("src.ui.hud.registry")

HUDRegistry.register({
    id = "notifications",
    priority = 900, -- High priority - above most UI
    loader = function()
        return require("src.ui.notifications")
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
