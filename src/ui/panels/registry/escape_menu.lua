local PanelRegistry = require("src.ui.core.panel_registry")

PanelRegistry.register({
    id = "escape",
    defaultZ = 200, -- Highest z-index to ensure it always appears on top
    modal = true,
    useSelf = false, -- Escape menu module methods don't use self
    loader = function()
        return require("src.ui.escape_menu")
    end,
    isVisible = function(panel)
        return panel.visible == true
    end,
    setVisible = function(panel, open)
        panel.visible = open == true
    end,
    onOpen = function(panel)
        if panel.show then
            panel.show()
        else
            panel.visible = true
        end
        panel.showSaveSlots = false
    end,
    onClose = function(panel)
        if panel.hide then
            panel.hide()
        else
            panel.visible = false
        end
        panel.showSaveSlots = false
    end,
    getRect = function(panel)
        local window = panel.window
        if window then
            return { x = window.x, y = window.y, w = window.width, h = window.height }
        end
        return nil
    end,
    draw = function(panel)
        if panel.draw then
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
    mousepressed = function(panel, x, y, button, player)
        if panel.mousepressed then
            -- Escape panel expects (x, y, button) not (x, y, button, player)
            return panel.mousepressed(x, y, button)
        end
        return false
    end,
    mousereleased = function(panel, x, y, button, player)
        if panel.mousereleased then
            -- Escape panel expects (x, y, button) not (x, y, button, player)
            return panel.mousereleased(x, y, button)
        end
        return false
    end,
    mousemoved = function(panel, x, y, dx, dy)
        if panel.mousemoved then
            return panel.mousemoved(x, y, dx, dy)
        end
        return false
    end,
})
