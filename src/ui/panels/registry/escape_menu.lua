local PanelRegistry = require("src.ui.core.panel_registry")

PanelRegistry.register({
    id = "escape",
    defaultZ = 100,
    modal = true,
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
})
