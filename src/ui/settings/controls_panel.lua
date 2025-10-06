local Theme = require("src.core.theme")
local Strings = require("src.core.strings")
local Settings = require("src.core.settings")

local ControlsPanel = {}

local keymap = {}
local bindingAction
local buttonRects = {}
local keymapChangedCallback

local keybindOrder = {
    "toggle_inventory", "toggle_ship", "toggle_skills",
    "toggle_map",
    "hotbar_1", "hotbar_2", "hotbar_3", "hotbar_4", "hotbar_5", "hotbar_6", "hotbar_7"
}

function ControlsPanel.setKeymap(map, onChanged)
    keymap = map or {}
    keymapChangedCallback = onChanged
end

function ControlsPanel.draw(layout)
    local yOffset = layout.yOffset
    local labelX = layout.labelX

    Theme.setColor(Theme.colors.accent)
    love.graphics.setFont(Theme.fonts and (Theme.fonts.normal or Theme.fonts.small) or love.graphics.getFont())
    love.graphics.print("Controls", labelX, yOffset)
    love.graphics.setFont(layout.settingsFont)
    yOffset = yOffset + 30

    Theme.setColor(Theme.colors.text)
    love.graphics.print("Keybindings", labelX, yOffset)
    yOffset = yOffset + 30

    buttonRects = {}

    local mx, my = layout.mx, layout.scrolledMouseY
    local btnXBase = layout.x + 200

    for _, action in ipairs(keybindOrder) do
        local key = keymap[action]
        Theme.setColor(Theme.colors.text)
        love.graphics.print(action, layout.x + 20, yOffset)

        local btnW, btnH = 100, 24
        local btnX, btnY = btnXBase, yOffset - 2
        local hover = mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH
        local keyText = key or "Not Set"
        if bindingAction == action then
            keyText = Strings.getControl("press_key")
        end
        Theme.drawStyledButton(btnX, btnY, btnW, btnH, keyText, hover, love.timer.getTime(), nil, bindingAction == action, { compact = true })
        buttonRects[action] = { x = btnX, y = btnY - layout.scrollY, w = btnW, h = btnH }
        yOffset = yOffset + 30
    end

    layout.yOffset = yOffset
    return yOffset
end

function ControlsPanel.mousepressed(x, y, button)
    if button ~= 1 then return false end
    for action, rect in pairs(buttonRects) do
        if x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h then
            local Sound = require("src.core.sound")
            Sound.playSFX("button_click")
            bindingAction = action
            return true
        end
    end
    return false
end

function ControlsPanel.keypressed(key)
    if not bindingAction then return false end
    Settings.setKeyBinding(bindingAction, key)
    keymap = Settings.getKeymap() or keymap
    if keymapChangedCallback then
        keymapChangedCallback(keymap)
    end
    bindingAction = nil
    return true
end

function ControlsPanel.isBinding()
    return bindingAction ~= nil
end

function ControlsPanel.resetBinding()
    bindingAction = nil
end

function ControlsPanel.getContentHeight(baseY)
    local yOffset = baseY
    yOffset = yOffset + 30
    yOffset = yOffset + 30
    yOffset = yOffset + 30 * #keybindOrder
    return yOffset
end

return ControlsPanel
