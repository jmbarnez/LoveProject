local PanelRegistry = require("src.ui.core.panel_registry")

PanelRegistry.register({
    id = "debug",
    defaultZ = 120,
    loader = function()
        return require("src.ui.debug_panel")
    end,
    isVisible = function(panel)
        return panel.isVisible and panel.isVisible() or panel.visible == true
    end,
    setVisible = function(panel, open)
        if panel.setVisible then
            panel.setVisible(open == true)
        else
            panel.visible = open == true
        end
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
