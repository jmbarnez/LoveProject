local PanelRegistry = require("src.ui.core.panel_registry")

PanelRegistry.register({
    id = "warp",
    defaultZ = 60,
    modal = true,
    useSelf = true, -- Warp module methods use self (defined with :)
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
})
