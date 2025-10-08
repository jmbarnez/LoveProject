local PanelRegistry = require("src.ui.core.panel_registry")

PanelRegistry.register({
    id = "settings",
    defaultZ = 110,
    modal = true,
    loader = function()
        return require("src.ui.settings_panel")
    end,
    isVisible = function(panel)
        return panel.visible == true
    end,
    setVisible = function(panel, open)
        panel.visible = open == true
    end,
    onOpen = function(panel)
        panel.visible = true
    end,
    onClose = function(panel)
        panel.visible = false
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
})
