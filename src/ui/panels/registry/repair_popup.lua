local PanelRegistry = require("src.ui.core.panel_registry")

PanelRegistry.register({
    id = "repairPopup",
    defaultZ = 112,
    modal = true,
    loader = function()
        return require("src.ui.repair_popup")
    end,
    isVisible = function(panel)
        return panel.visible == true
    end,
    setVisible = function(panel, open)
        panel.visible = open == true
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
})
