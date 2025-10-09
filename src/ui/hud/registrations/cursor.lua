local HUDRegistry = require("src.ui.hud.registry")

HUDRegistry.register({
    id = "cursor",
    priority = 1000, -- Highest priority - always on top
    loader = function()
        return require("src.ui.hud.cursor")
    end,
    update = function(module, dt)
        if module.update then
            module.update(dt)
        end
    end,
    draw = function(module)
        if module then
            module.setVisible(true)
            module.applySettings()
            module.draw()
        end
    end,
})
