local PanelRegistry = require("src.ui.core.panel_registry")

PanelRegistry.register({
    id = "settings",
    defaultZ = 110,
    modal = true,
    useSelf = false, -- Settings module methods don't use self
    loader = function()
        return require("src.ui.settings_panel")
    end,
    isVisible = function(panel)
        return panel.visible == true
    end,
    setVisible = function(panel, open)
        panel.visible = open == true
    end,
    onOpen = function(panel)
        -- Ensure the panel is initialized
        if not panel.window and panel.init then
            panel.init()
        end
        panel.visible = true
        if panel.window then
            panel.window:show()
        end
    end,
    onClose = function(panel)
        panel.visible = false
        if panel.window then
            panel.window:hide()
        end
    end,
    getRect = function(panel)
        local window = panel.window
        if window then
            return { x = window.x, y = window.y, w = window.width, h = window.height }
        end
        return nil
    end,
    draw = function(panel)
        if panel.window then
            panel.window.visible = panel.visible
            if panel.visible then
                panel.window:draw()
            end
        elseif panel.draw then
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
    mousepressed = function(panel, ...)
        if panel.mousepressed then
            return panel.mousepressed(...)
        end
        return false
    end,
    mousereleased = function(panel, ...)
        if panel.mousereleased then
            return panel.mousereleased(...)
        end
        return false
    end,
    mousemoved = function(panel, ...)
        if panel.mousemoved then
            return panel.mousemoved(...)
        end
        return false
    end,
})
