local PanelRegistry = require("src.ui.core.panel_registry")

PanelRegistry.register({
    id = "inventory",
    defaultZ = 10,
    useSelf = false, -- Inventory module methods don't use self
    loader = function()
        local Inventory = require("src.ui.inventory")
        local instance = Inventory:new()
        return instance
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
    mousepressed = function(panel, x, y, button, player)
        if panel.mousepressed then
            -- Inventory panel expects (x, y, button) not (x, y, button, player)
            return panel.mousepressed(x, y, button)
        end
        return false
    end,
    mousereleased = function(panel, x, y, button, player)
        if panel.mousereleased then
            -- Inventory panel expects (x, y, button) not (x, y, button, player)
            return panel.mousereleased(x, y, button)
        end
        return false
    end,
    mousemoved = function(panel, x, y, dx, dy)
        if panel.mousemoved then
            return panel.mousemoved(x, y, dx, dy)
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
