local PanelRegistry = require("src.ui.core.panel_registry")

PanelRegistry.register({
    id = "map",
    defaultZ = 50,
    useSelf = false, -- Map module methods don't use self
    loader = function()
        return require("src.ui.map")
    end,
    isVisible = function(panel)
        if panel.isVisible then
            return panel.isVisible()
        end
        return panel.visible == true
    end,
    setVisible = function(panel, open)
        panel.visible = open == true
    end,
    onOpen = function(panel)
        panel.visible = true
        if panel.show then
            -- Get player reference from UIManager
            local UIManager = require("src.core.ui_manager")
            local player = UIManager._player
            panel.show(player)
        end
    end,
    onClose = function(panel)
        panel.visible = false
        if panel.hide then
            panel.hide()
        end
        -- Reset map state when closing
        if panel.dragging then
            panel.dragging = false
        end
        if panel._drawPlayer then
            panel._drawPlayer = nil
        end
        if panel._drawWorld then
            panel._drawWorld = nil
        end
        if panel._mapBounds then
            panel._mapBounds = nil
        end
        if panel._contentBounds then
            panel._contentBounds = nil
        end
    end,
    getRect = function(panel)
        local window = panel.window
        if window then
            return { x = window.x, y = window.y, w = window.width, h = window.height }
        end
        return nil
    end,
    draw = function(panel, ...)
        if panel.draw then
            panel.draw(...)
        end
    end,
    update = function(panel, dt, ...)
        if panel.update then
            panel.update(dt, ...)
        end
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
    keypressed = function(panel, key)
        if panel.keypressed then
            return panel.keypressed(key)
        end
        return false
    end,
})
