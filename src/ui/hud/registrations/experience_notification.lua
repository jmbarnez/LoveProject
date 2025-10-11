local HUDRegistry = require("src.ui.hud.registry")

HUDRegistry.register({
    id = "experience_notification",
    priority = 800, -- High priority
    loader = function()
        return require("src.ui.hud.experience_notification")
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
