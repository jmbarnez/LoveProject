local Window = require("src.ui.common.window")
local Viewport = require("src.core.viewport")

local ShipWindow = {}

function ShipWindow.ensure(state, drawCallback)
    if state.window then return state.window end

    state.window = Window.new({
        title = "Ship Fitting",
        width = 1280,
        height = 800,
        resizable = true,
        useLoadPanelTheme = true,
        draggable = true,
        closable = true,
        drawContent = function(window, x, y, w, h)
            if drawCallback then
                drawCallback(state, window, x, y, w, h)
            end
        end,
        onShow = function()
            state.visible = true
        end,
        onClose = function()
            state.visible = false
            local Sound = require("src.core.sound")
            Sound.triggerEvent('ui_button_click')
            if _G.UIManager and _G.UIManager.close then
                _G.UIManager.close("ship")
            end
        end
    })

    return state.window
end

function ShipWindow.centerIfHidden(state)
    if not state.window or state.window.visible then return end
    local sw, sh = Viewport.getDimensions()
    state.window.x = math.floor((sw - state.window.width) * 0.5)
    state.window.y = math.floor((sh - state.window.height) * 0.5)
end

function ShipWindow.show(state)
    if state.window then
        state.window:show()
    end
end

function ShipWindow.hide(state)
    if state.window then
        state.window:hide()
    end
end

return ShipWindow
