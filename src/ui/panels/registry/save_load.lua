local PanelRegistry = require("src.ui.core.panel_registry")

PanelRegistry.register({
    id = "save_load",
    defaultZ = 120, -- Higher than escape menu (100) and settings (110)
    modal = true,
    useSelf = false, -- SaveLoad module methods don't use self
    loader = function()
        return require("src.ui.save_load_panel")
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
    end,
    onClose = function(panel)
        if panel.hide then
            panel.hide()
        else
            panel.visible = false
        end
    end,
    getRect = function(panel)
        if panel.window and panel.window.window then
            local window = panel.window.window
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
    textinput = function(panel, ...)
        if panel.textinput then
            return panel.textinput(...)
        end
        return false
    end
})
