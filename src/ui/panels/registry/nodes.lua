local PanelRegistry = require("src.ui.core.panel_registry")

PanelRegistry.register({
    id = "nodes",
    defaultZ = 45,
    modal = true,
    useSelf = true, -- Nodes module methods use self (defined with :)
    loader = function()
        local Nodes = require("src.ui.nodes")
        local instance = Nodes:new()
        return instance
    end,
    isVisible = function(panel)
        return panel.visible == true
    end,
    setVisible = function(panel, open)
        panel.visible = open == true
    end,
    onOpen = function(panel)
        panel.visible = true
        if panel.show then
            panel:show()
        end
    end,
    onClose = function(panel)
        panel.visible = false
        if panel.hide then
            panel:hide()
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
            panel:draw(...)
        end
    end,
    update = function(panel, dt, ...)
        if panel.update then
            panel:update(dt, ...)
        end
    end,
    mousepressed = function(panel, ...)
        if panel.mousepressed then
            return panel:mousepressed(...)
        end
        return false
    end,
    mousereleased = function(panel, ...)
        if panel.mousereleased then
            return panel:mousereleased(...)
        end
        return false
    end,
    mousemoved = function(panel, ...)
        if panel.mousemoved then
            return panel:mousemoved(...)
        end
        return false
    end,
    wheelmoved = function(panel, ...)
        if panel.wheelmoved then
            return panel:wheelmoved(...)
        end
        return false
    end,
    keypressed = function(panel, ...)
        if panel.keypressed then
            return panel:keypressed(...)
        end
        return false
    end,
    textinput = function(panel, ...)
        if panel.textinput then
            return panel:textinput(...)
        end
        return false
    end,
    captureTextInput = function(panel)
        return panel.state and panel.state:isInputActive()
    end,
})
