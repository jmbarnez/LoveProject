local Theme = require("src.core.theme")

local AudioPanel = {}

local currentSettings
local hovered = {
    master_volume = false,
    sfx_volume = false,
    music_volume = false
}

local draggingSlider
local sliderRects = {}

function AudioPanel.setSettings(settings)
    currentSettings = settings
end

local function sliderColor(isHovered)
    if isHovered then
        return Theme.colors.textHighlight, Theme.effects.glowWeak * 0.3
    end
    return Theme.colors.bg3, Theme.effects.glowWeak * 0.1
end

local function sliderHandleColor(isHovered)
    if isHovered then
        return Theme.colors.accentGold, Theme.effects.glowWeak * 0.4
    end
    return Theme.colors.accent, Theme.effects.glowWeak * 0.2
end

function AudioPanel.draw(layout)
    local yOffset = layout.yOffset
    local labelX = layout.labelX
    local valueX = layout.valueX
    local itemHeight = layout.itemHeight

    Theme.setColor(Theme.colors.accent)
    love.graphics.setFont(Theme.fonts and (Theme.fonts.normal or Theme.fonts.small) or love.graphics.getFont())
    love.graphics.print("Audio Settings", labelX, yOffset)
    love.graphics.setFont(layout.settingsFont)
    yOffset = yOffset + 30

    sliderRects = {}

    Theme.setColor(Theme.colors.text)
    love.graphics.print("Master Volume:", labelX, yOffset)
    local masterText = string.format("%.2f", currentSettings.master_volume)
    love.graphics.print(masterText, valueX + 220, yOffset)
    local sliderX = valueX
    local sliderW = 200
    local sliderScreenY = yOffset - 5 - layout.scrollY
    local trackColor, trackGlow = sliderColor(hovered.master_volume)
    Theme.drawGradientGlowRect(sliderX, yOffset - 5, sliderW, 10, 2, trackColor, Theme.colors.bg2, Theme.colors.border, trackGlow)
    local handleX = sliderX + (sliderW - 10) * currentSettings.master_volume
    local handleColorValue, handleGlow = sliderHandleColor(hovered.master_volume)
    Theme.drawGradientGlowRect(handleX, yOffset - 7.5, 10, 15, 2, handleColorValue, Theme.colors.bg3, Theme.colors.border, handleGlow)
    sliderRects.master_volume = { x = sliderX, y = sliderScreenY, w = sliderW, h = 15 }
    yOffset = yOffset + itemHeight

    Theme.setColor(Theme.colors.text)
    love.graphics.print("SFX Volume:", labelX, yOffset)
    local sfxText = string.format("%.2f", currentSettings.sfx_volume)
    love.graphics.print(sfxText, valueX + 220, yOffset)
    sliderScreenY = yOffset - 5 - layout.scrollY
    trackColor, trackGlow = sliderColor(hovered.sfx_volume)
    Theme.drawGradientGlowRect(sliderX, yOffset - 5, sliderW, 10, 2, trackColor, Theme.colors.bg2, Theme.colors.border, trackGlow)
    handleX = sliderX + (sliderW - 10) * currentSettings.sfx_volume
    handleColorValue, handleGlow = sliderHandleColor(hovered.sfx_volume)
    Theme.drawGradientGlowRect(handleX, yOffset - 7.5, 10, 15, 2, handleColorValue, Theme.colors.bg3, Theme.colors.border, handleGlow)
    sliderRects.sfx_volume = { x = sliderX, y = sliderScreenY, w = sliderW, h = 15 }
    yOffset = yOffset + itemHeight

    Theme.setColor(Theme.colors.text)
    love.graphics.print("Music Volume:", labelX, yOffset)
    local musicText = string.format("%.2f", currentSettings.music_volume)
    love.graphics.print(musicText, valueX + 220, yOffset)
    sliderScreenY = yOffset - 5 - layout.scrollY
    trackColor, trackGlow = sliderColor(hovered.music_volume)
    Theme.drawGradientGlowRect(sliderX, yOffset - 5, sliderW, 10, 2, trackColor, Theme.colors.bg2, Theme.colors.border, trackGlow)
    handleX = sliderX + (sliderW - 10) * currentSettings.music_volume
    handleColorValue, handleGlow = sliderHandleColor(hovered.music_volume)
    Theme.drawGradientGlowRect(handleX, yOffset - 7.5, 10, 15, 2, handleColorValue, Theme.colors.bg3, Theme.colors.border, handleGlow)
    sliderRects.music_volume = { x = sliderX, y = sliderScreenY, w = sliderW, h = 15 }
    yOffset = yOffset + itemHeight

    layout.yOffset = yOffset
    return yOffset
end

function AudioPanel.mousepressed(x, y, button)
    if button ~= 1 then return false end
    for name, rect in pairs(sliderRects) do
        if x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h then
            draggingSlider = name
            local pct = (x - rect.x) / rect.w
            currentSettings[name] = math.max(0, math.min(1, pct))
            return true
        end
    end
    return false
end

function AudioPanel.mousereleased()
    draggingSlider = nil
end

function AudioPanel.mousemoved(x, y)
    for key in pairs(hovered) do hovered[key] = false end

    for name, rect in pairs(sliderRects) do
        if x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h then
            hovered[name] = true
        end
    end

    if draggingSlider then
        local rect = sliderRects[draggingSlider]
        if rect then
            local pct = (x - rect.x) / rect.w
            currentSettings[draggingSlider] = math.max(0, math.min(1, pct))
            return true
        end
    end

    return draggingSlider ~= nil
end

function AudioPanel.getContentHeight(baseY)
    local yOffset = baseY
    yOffset = yOffset + 30
    yOffset = yOffset + 40
    yOffset = yOffset + 40
    yOffset = yOffset + 40
    return yOffset
end

return AudioPanel
