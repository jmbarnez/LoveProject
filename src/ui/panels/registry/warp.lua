local PanelRegistry = require("src.ui.core.panel_registry")

PanelRegistry.register({
    id = "warp",
    defaultZ = 60,
    modal = true,
    loader = function()
        local Warp = require("src.ui.warp")
        local instance = Warp:new()
        if instance.init then
            instance:init()
        end
        return instance
    end,
    isVisible = function(panel)
        return panel.visible == true
    end,
    setVisible = function(panel, open)
        if open then
            if panel.show then
                panel:show()
            else
                panel.visible = true
            end
        else
            if panel.hide then
                panel:hide()
            else
                panel.visible = false
            end
        end
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
            panel:mousemoved(...)
        end
    end,
    wheelmoved = function(panel, ...)
        if panel.wheelmoved then
            return panel:wheelmoved(...)
        end
        return false
    end,
    useSelf = true,
})
