local PanelRegistry = require("src.ui.core.panel_registry")

PanelRegistry.register({
    id = "skills",
    defaultZ = 30,
    useSelf = false, -- Skills module methods don't use self
    loader = function()
        return require("src.ui.skills")
    end,
    isVisible = function(panel)
        return panel.visible == true
    end,
    setVisible = function(panel, open)
        panel.visible = open == true
    end,
    getRect = function(panel)
        local window = panel.window
        if window then
            return { x = window.x, y = window.y, w = window.width, h = window.height }
        end
        return nil
    end,
    draw = function(panel)
        if panel.visible and panel.draw then
            panel.draw()
        end
    end,
    update = function(panel, dt)
        if panel.update then
            panel.update(dt)
        end
    end,
    keypressed = function(panel, ...)
        if panel.keypressed then
            return panel.keypressed(...)
        end
        return false
    end,
    mousepressed = function(panel, x, y, button)
        if panel.mousepressed then
            return panel.mousepressed(x, y, button)
        end
        return false
    end,
    mousereleased = function(panel, x, y, button)
        if panel.mousereleased then
            return panel.mousereleased(x, y, button)
        end
        return false
    end,
})
