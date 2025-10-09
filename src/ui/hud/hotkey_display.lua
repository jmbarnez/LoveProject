local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local Settings = require("src.core.settings")

local HotkeyDisplay = {}

function HotkeyDisplay.draw()
    local keymap = Settings.getKeymap()
    if not keymap then return end

    local sw, sh = Viewport.getDimensions()
    local s = math.min(sw / 1920, sh / 1080)
    local w, h = math.floor(220 * s), math.floor(160 * s)
    local pad = math.floor(16 * s)
    local x, y = sw - w - pad, pad + h + pad

    local panelW = w
    local panelH = 120 * s
    
    Theme.drawGradientGlowRect(x, y, panelW, panelH, 8,
        Theme.colors.bg1, Theme.colors.bg0,
        Theme.colors.primary, Theme.effects.glowWeak)
    
    Theme.drawEVEBorder(x + 4, y + 4, panelW - 8, panelH - 8, 6, Theme.colors.primary, 8)

    love.graphics.setFont(Theme.fonts.small)
    Theme.setColor(Theme.colors.text)

    local yOffset = y + 10
    local xOffset = x + 10
    local lineHeight = 15 * s

    local hotkeys = {
        { action = "Dock", key = keymap.dock },
        { action = "Cargo", key = keymap.toggle_cargo },
        { action = "Skills", key = keymap.toggle_skills },
        { action = "Map", key = keymap.toggle_map },
    }

    for _, hotkey in ipairs(hotkeys) do
        love.graphics.print(hotkey.action .. ": " .. hotkey.key, xOffset, yOffset)
        yOffset = yOffset + lineHeight
    end
end

return HotkeyDisplay
