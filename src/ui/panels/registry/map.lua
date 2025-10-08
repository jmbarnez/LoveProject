local PanelRegistry = require("src.ui.core.panel_registry")

PanelRegistry.register({
    id = "map",
    defaultZ = 50,
    loader = function()
        return require("src.ui.map")
    end,
    isVisible = function(panel)
        if panel.isVisible then
            return panel.isVisible()
        end
        return panel.visible == true
    end,
    setVisible = function(panel, open)
        if open then
            if panel.show then
                panel.show()
            else
                panel.visible = true
            end
        else
            if panel.hide then
                panel.hide()
            else
                panel.visible = false
            end
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
            panel.draw(...)
        end
    end,
    update = function(panel, dt, ...)
        if panel.update then
            panel.update(dt, ...)
        end
    end,
})
