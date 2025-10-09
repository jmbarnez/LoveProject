local PanelRegistry = require("src.ui.core.panel_registry")

PanelRegistry.register({
    id = "debug",
    defaultZ = 120,
    useSelf = false, -- Debug module methods don't use self
    loader = function()
        return require("src.ui.debug_panel")
    end,
    isVisible = function(panel)
        return panel.isVisible and panel.isVisible() or panel.visible == true
    end,
    setVisible = function(panel, open)
        panel.visible = open == true
    end,
    onOpen = function(panel)
        panel.visible = true
        if panel.setVisible then
            panel.setVisible(true)
        end
    end,
    onClose = function(panel)
        panel.visible = false
        if panel.setVisible then
            panel.setVisible(false)
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
