local PanelRegistry = require("src.ui.core.panel_registry")

PanelRegistry.register({
    id = "ship",
    defaultZ = 15,
    useSelf = true, -- Ship module methods use self (defined with :)
    loader = function()
        local Ship = require("src.ui.ship")
        local instance = Ship:new()
        return instance
    end,
    isVisible = function(panel)
        return panel.visible == true
    end,
    setVisible = function(panel, open)
        panel.visible = open == true
        if open and panel.show then
            panel:show()
        elseif not open and panel.hide then
            panel:hide()
        end
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
    draw = function(panel)
        if panel.ensure then
            local instance = panel.ensure()
            if instance and instance.window then
                instance.window.visible = panel.visible
                instance.window:draw()
                if panel.visible and instance.drawDropdownOptions then
                    instance:drawDropdownOptions()
                end
            end
            return
        end

        if panel.visible and panel.draw then
            panel:draw()
        end
    end,
    update = function(panel, dt)
        if panel.update then
            panel:update(dt)
        end
    end,
    keypressed = function(panel, ...)
        if panel.keypressed then
            return panel:keypressed(...)
        end
        return false
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
})
