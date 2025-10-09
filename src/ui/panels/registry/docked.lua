local PanelRegistry = require("src.ui.core.panel_registry")

PanelRegistry.register({
    id = "docked",
    defaultZ = 40,
    modal = true,
    useSelf = false, -- Docked module methods don't use self
    loader = function()
        return require("src.ui.docked")
    end,
    isVisible = function(panel)
        return panel.isVisible and panel.isVisible()
    end,
    setVisible = function(panel, open)
        panel.visible = open == true
    end,
    onOpen = function(panel)
        panel.visible = true
        -- Don't call show() here as it expects (player, station) parameters
        -- The docking system handles this directly
    end,
    captureTextInput = function(panel)
        return panel.isSearchActive and panel.isSearchActive()
    end,
    getRect = function()
        local Viewport = require("src.core.viewport")
        local sw, sh = Viewport.getDimensions()
        return { x = 0, y = 0, w = sw, h = sh }
    end,
    draw = function(panel, ...)
        if panel.draw then
            panel.draw(...)
        end
    end,
    update = function(panel, dt)
        if panel.update then
            panel.update(dt)
        end
    end,
    onClose = function(panel)
        local player = panel.player
        if player then
            local PlayerSystem = require("src.systems.player")
            PlayerSystem.undock(player)
        else
            if panel.hide then
                panel.hide()
            end
            panel.visible = false
        end
    end,
    mousepressed = function(panel, x, y, button, player)
        if panel.mousepressed then
            return panel.mousepressed(x, y, button, player)
        end
        return false
    end,
    mousereleased = function(panel, x, y, button, player)
        if panel.mousereleased then
            return panel.mousereleased(x, y, button, player)
        end
        return false
    end,
    mousemoved = function(panel, x, y, dx, dy, player)
        if panel.mousemoved then
            return panel.mousemoved(x, y, dx, dy, player)
        end
        return false
    end,
    wheelmoved = function(panel, dx, dy, player)
        if panel.wheelmoved then
            return panel.wheelmoved(dx, dy, player)
        end
        return false
    end,
    keypressed = function(panel, key, scancode, isrepeat, player)
        if panel.keypressed then
            return panel.keypressed(key, scancode, isrepeat, player)
        end
        return false
    end,
    textinput = function(panel, text, player)
        if panel.textinput then
            return panel.textinput(text, player)
        end
        return false
    end,
})
