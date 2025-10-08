local PanelRegistry = require("src.ui.core.panel_registry")

PanelRegistry.register({
    id = "docked",
    defaultZ = 40,
    modal = true,
    loader = function()
        return require("src.ui.docked")
    end,
    isVisible = function(panel)
        return panel.isVisible and panel.isVisible()
    end,
    setVisible = function(panel, open)
        if panel.setVisible then
            panel.setVisible(open == true)
        else
            panel.visible = open == true
        end
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
})
