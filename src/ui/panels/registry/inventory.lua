local PanelRegistry = require("src.ui.core.panel_registry")

PanelRegistry.register({
    id = "inventory",
    defaultZ = 10,
    loader = function()
        return require("src.ui.inventory")
    end,
    isVisible = function(panel)
        return panel.visible == true
    end,
    setVisible = function(panel, open)
        panel.visible = open == true
        if not open and panel.clearSearchFocus then
            panel.clearSearchFocus()
        end
    end,
    captureTextInput = function(panel)
        return panel.isSearchInputActive and panel.isSearchInputActive()
    end,
    onOpen = function(panel)
        panel.visible = true
    end,
    onClose = function(panel)
        panel.visible = false
        if panel.clearSearchFocus then
            panel.clearSearchFocus()
        end
        local TooltipManager = require("src.ui.tooltip_manager")
        TooltipManager.clearTooltip()
    end,
    getRect = function(panel)
        if panel.getRect then
            return panel.getRect()
        end
        return nil
    end,
    draw = function(panel)
        if panel.visible and panel.draw then
            panel.draw()
        end
    end,
    update = function(panel, dt)
        if panel.visible and panel.update then
            panel.update(dt)
        end
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
    end,
    wheelmoved = function(panel, ...)
        if panel.wheelmoved then
            return panel.wheelmoved(...)
        end
        return false
    end,
    keypressed = function(panel, ...)
        if panel.keypressed then
            return panel.keypressed(...)
        end
        return false
    end,
    textinput = function(panel, ...)
        if panel.textinput then
            return panel.textinput(...)
        end
        return false
    end,
})
