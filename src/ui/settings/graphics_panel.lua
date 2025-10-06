local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local Dropdown = require("src.ui.common.dropdown")
local Strings = require("src.core.strings")

local GraphicsPanel = {}

local currentSettings

local vsyncTypes = {Strings.getUI("off"), Strings.getUI("on")}
local fpsLimitTypes = {Strings.getUI("unlimited"), "30", "60", "120", "144", "240"}

local vsyncDropdown
local fpsLimitDropdown

local accentGalleryOpen = false

local accentColorSliders = {
    r = { value = 0.7, dragging = false },
    g = { value = 0.7, dragging = false },
    b = { value = 0.7, dragging = false }
}

local accentThemeLastChanged = 0
local accentThemeChangeDuration = 0.5

local accentPopup
local accentSpectrum
local accentDone

local function cloneSettings(src)
    if not src then return {} end
    local copy = {}
    for k, v in pairs(src) do
        if type(v) == "table" then
            copy[k] = cloneSettings(v)
        else
            copy[k] = v
        end
    end
    return copy
end

local accentThemes = {
    { name = "Cyan/Lavender", color = {0.2, 0.8, 0.9, 1.0} },
    { name = "Blue/Purple", color = {0.4, 0.6, 1.0, 1.0} },
    { name = "Green/Emerald", color = {0.3, 0.9, 0.4, 1.0} },
    { name = "Red/Orange", color = {0.9, 0.3, 0.2, 1.0} },
    { name = "Monochrome", color = {0.7, 0.7, 0.7, 1.0} },
    { name = "Custom", color = {0.7, 0.7, 0.7, 1.0} }
}

local function hsvToRgb(h, s, v)
    local r, g, b
    local i = math.floor(h / 60)
    local f = (h / 60) - i
    local p = v * (1 - s)
    local q = v * (1 - s * f)
    local t = v * (1 - s * (1 - f))

    if i == 0 then
        r, g, b = v, t, p
    elseif i == 1 then
        r, g, b = q, v, p
    elseif i == 2 then
        r, g, b = p, v, t
    elseif i == 3 then
        r, g, b = p, q, v
    elseif i == 4 then
        r, g, b = t, p, v
    else
        r, g, b = v, p, q
    end

    return r, g, b
end

local function rgbToHsv(r, g, b)
    local max = math.max(r, g, b)
    local min = math.min(r, g, b)
    local diff = max - min

    local h = 0
    local s = max == 0 and 0 or (diff / max)
    local v = max

    if diff ~= 0 then
        if max == r then
            h = ((g - b) / diff) % 6
        elseif max == g then
            h = (b - r) / diff + 2
        else
            h = (r - g) / diff + 4
        end
        h = h * 60
        if h < 0 then h = h + 360 end
    end

    return { h = h, s = s, v = v }
end

local function applyCustomAccentColor(r, g, b)
    local ThemeMod = require("src.core.theme")

    ThemeMod.colors.accent = {r, g, b, 1.00}
    ThemeMod.colors.accentGold = {r, g, b, 1.00}
    ThemeMod.colors.accentTeal = {r, g, b, 1.00}
    ThemeMod.colors.accentPink = {r, g, b, 1.00}
    ThemeMod.colors.border = {r, g, b, 0.8}
    ThemeMod.colors.borderBright = {r, g, b, 0.8}

    ThemeMod.turretSlotColors = {
        {r, g, b, 1.00},
        {r, g, b, 1.00},
        {r, g, b, 1.00},
        {r, g, b, 1.00},
    }

    if currentSettings then
        currentSettings.accent_color_rgb = {r, g, b, 1.0}
        currentSettings.accent_theme = "Custom"
    end

    accentThemeLastChanged = love.timer.getTime()
end

local function applyAccentTheme(themeName)
    local ThemeMod = require("src.core.theme")

    if themeName == "Cyan/Lavender" then
        ThemeMod.colors.accent = {0.2, 0.8, 0.9, 1.00}
        ThemeMod.colors.accentGold = {0.2, 0.8, 0.9, 1.00}
        ThemeMod.colors.accentTeal = {0.2, 0.8, 0.9, 1.00}
        ThemeMod.colors.accentPink = {0.2, 0.8, 0.9, 1.00}
        ThemeMod.colors.border = {0.5, 0.7, 0.9, 0.8}
        ThemeMod.colors.borderBright = {0.5, 0.7, 0.9, 0.8}
        ThemeMod.colors.bg0 = {0.00, 0.00, 0.00, 1.00}
        ThemeMod.colors.bg1 = {0.00, 0.00, 0.00, 1.00}
        ThemeMod.colors.windowBg = {0.00, 0.00, 0.00, 1.00}
    elseif themeName == "Blue/Purple" then
        ThemeMod.colors.accent = {0.4, 0.6, 1.0, 1.00}
        ThemeMod.colors.accentGold = {0.4, 0.6, 1.0, 1.00}
        ThemeMod.colors.accentTeal = {0.4, 0.6, 1.0, 1.00}
        ThemeMod.colors.accentPink = {0.4, 0.6, 1.0, 1.00}
        ThemeMod.colors.border = {0.4, 0.6, 1.0, 0.8}
        ThemeMod.colors.borderBright = {0.4, 0.6, 1.0, 0.8}
        ThemeMod.colors.bg0 = {0.00, 0.00, 0.00, 1.00}
        ThemeMod.colors.bg1 = {0.00, 0.00, 0.00, 1.00}
        ThemeMod.colors.windowBg = {0.00, 0.00, 0.00, 1.00}
    elseif themeName == "Green/Emerald" then
        ThemeMod.colors.accent = {0.3, 0.9, 0.4, 1.00}
        ThemeMod.colors.accentGold = {0.3, 0.9, 0.4, 1.00}
        ThemeMod.colors.accentTeal = {0.3, 0.9, 0.4, 1.00}
        ThemeMod.colors.accentPink = {0.3, 0.9, 0.4, 1.00}
        ThemeMod.colors.border = {0.3, 0.9, 0.4, 0.8}
        ThemeMod.colors.borderBright = {0.3, 0.9, 0.4, 0.8}
        ThemeMod.colors.bg0 = {0.00, 0.00, 0.00, 1.00}
        ThemeMod.colors.bg1 = {0.00, 0.00, 0.00, 1.00}
        ThemeMod.colors.windowBg = {0.00, 0.00, 0.00, 1.00}
    elseif themeName == "Red/Orange" then
        ThemeMod.colors.accent = {0.9, 0.3, 0.2, 1.00}
        ThemeMod.colors.accentGold = {0.9, 0.3, 0.2, 1.00}
        ThemeMod.colors.accentTeal = {0.9, 0.3, 0.2, 1.00}
        ThemeMod.colors.accentPink = {0.9, 0.3, 0.2, 1.00}
        ThemeMod.colors.border = {0.9, 0.3, 0.2, 0.8}
        ThemeMod.colors.borderBright = {0.9, 0.3, 0.2, 0.8}
        ThemeMod.colors.bg0 = {0.00, 0.00, 0.00, 1.00}
        ThemeMod.colors.bg1 = {0.00, 0.00, 0.00, 1.00}
        ThemeMod.colors.windowBg = {0.00, 0.00, 0.00, 1.00}
    elseif themeName == "Monochrome" then
        ThemeMod.colors.accent = {0.7, 0.7, 0.7, 1.00}
        ThemeMod.colors.accentGold = {0.7, 0.7, 0.7, 1.00}
        ThemeMod.colors.accentTeal = {0.7, 0.7, 0.7, 1.00}
        ThemeMod.colors.accentPink = {0.7, 0.7, 0.7, 1.00}
        ThemeMod.colors.border = {0.7, 0.7, 0.7, 0.8}
        ThemeMod.colors.borderBright = {0.7, 0.7, 0.7, 0.8}
        ThemeMod.colors.bg0 = {0.00, 0.00, 0.00, 1.00}
        ThemeMod.colors.bg1 = {0.00, 0.00, 0.00, 1.00}
        ThemeMod.colors.windowBg = {0.00, 0.00, 0.00, 1.00}
    end

    if themeName ~= "Custom" and currentSettings then
        currentSettings.accent_theme = themeName
        currentSettings.accent_color_rgb = nil
    end

    accentThemeLastChanged = love.timer.getTime()
end

local function ensureDropdowns()
    if not vsyncDropdown then
        vsyncDropdown = Dropdown.new({
            x = 0,
            y = 0,
            options = vsyncTypes,
            selectedIndex = 1,
            onSelect = function(index)
                if currentSettings then
                    currentSettings.vsync = (index == 2)
                end
            end
        })
    end

    if not fpsLimitDropdown then
        fpsLimitDropdown = Dropdown.new({
            x = 0,
            y = 0,
            options = fpsLimitTypes,
            selectedIndex = 3,
            onSelect = function(index)
                if not currentSettings then return end
                local fpsMap = {
                    [1] = 0,
                    [2] = 30,
                    [3] = 60,
                    [4] = 120,
                    [5] = 144,
                    [6] = 240
                }
                currentSettings.max_fps_index = index
                currentSettings.max_fps = fpsMap[index] or 60
            end
        })
    end
end

local function refreshDropdowns()
    if not currentSettings then return end
    ensureDropdowns()

    vsyncDropdown:setSelectedIndex(currentSettings.vsync and 2 or 1)

    local fpsToIndex = {
        [0] = 1,
        [30] = 2,
        [60] = 3,
        [120] = 4,
        [144] = 5,
        [240] = 6
    }
    local idx = fpsToIndex[currentSettings.max_fps or 60] or 3
    currentSettings.max_fps_index = idx
    fpsLimitDropdown:setSelectedIndex(idx)
end


local function drawAccentGallery()
    if not accentGalleryOpen then
        accentPopup = nil
        accentSpectrum = nil
        accentDone = nil
        GraphicsPanel._colorPickerSliders = nil
        return
    end

    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local gw, gh = 600, 450
    local gx, gy = (sw - gw) / 2, (sh - gh) / 2
    Theme.drawGradientGlowRect(gx, gy, gw, gh, 6, Theme.colors.bg1, Theme.colors.bg0, Theme.colors.accent, Theme.effects.glowWeak)
    Theme.drawEVEBorder(gx, gy, gw, gh, 6, Theme.colors.border, 8)
    Theme.setColor(Theme.colors.textHighlight)
    love.graphics.print("Choose Accent Theme", gx + 16, gy + 12)

    local pickerX = gx + 20
    local pickerY = gy + 60
    local pickerSize = 200
    local previewSize = 80

    local cr, cg, cb = accentColorSliders.r.value, accentColorSliders.g.value, accentColorSliders.b.value
    if currentSettings and currentSettings.accent_color_rgb then
        cr = currentSettings.accent_color_rgb[1]
        cg = currentSettings.accent_color_rgb[2]
        cb = currentSettings.accent_color_rgb[3]
    end

    local spectrumX = pickerX
    local spectrumY = pickerY
    local spectrumW = pickerSize
    local spectrumH = pickerSize

    for x = 0, spectrumW - 1 do
        for y = 0, spectrumH - 1 do
            local h = (x / spectrumW) * 360
            local s = 1.0
            local v = 1.0 - (y / spectrumH)
            local r, g, b = hsvToRgb(h, s, v)
            Theme.setColor({r, g, b, 1})
            love.graphics.rectangle("fill", spectrumX + x, spectrumY + y, 1, 1)
        end
    end

    Theme.setColor(Theme.colors.border)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", spectrumX, spectrumY, spectrumW, spectrumH)

    local currentH = rgbToHsv(cr, cg, cb)
    local indicatorX = spectrumX + (currentH.h / 360) * spectrumW
    local indicatorY = spectrumY + (1 - currentH.v) * spectrumH

    Theme.setColor({1, 1, 1, 1})
    love.graphics.setLineWidth(2)
    love.graphics.line(indicatorX - 8, indicatorY, indicatorX + 8, indicatorY)
    love.graphics.line(indicatorX, indicatorY - 8, indicatorX, indicatorY + 8)
    Theme.setColor({0, 0, 0, 1})
    love.graphics.setLineWidth(1)
    love.graphics.line(indicatorX - 9, indicatorY, indicatorX + 9, indicatorY)
    love.graphics.line(indicatorX, indicatorY - 9, indicatorX, indicatorY + 9)

    accentSpectrum = { x = spectrumX, y = spectrumY, w = spectrumW, h = spectrumH }

    local previewX = pickerX + pickerSize + 20
    local previewY = pickerY
    Theme.setColor({cr, cg, cb, 1})
    love.graphics.rectangle("fill", previewX, previewY, previewSize, previewSize)
    Theme.setColor(Theme.colors.border)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", previewX, previewY, previewSize, previewSize)

    Theme.setColor(Theme.colors.text)
    local labelText = "Custom Color"
    local labelW = Theme.fonts.small:getWidth(labelText)
    love.graphics.print(labelText, previewX + (previewSize - labelW) / 2, previewY - 20)

    local rgbY = previewY + previewSize + 10
    local rgbText = string.format("R: %d  G: %d  B: %d",
        math.floor(cr * 255),
        math.floor(cg * 255),
        math.floor(cb * 255))
    love.graphics.print(rgbText, previewX, rgbY)

    local hsvY = rgbY + 15
    local hsvText = string.format("H: %d°  S: %d%%  V: %d%%",
        math.floor(currentH.h),
        math.floor(currentH.s * 100),
        math.floor(currentH.v * 100))
    love.graphics.print(hsvText, previewX, hsvY)

    local doneW, doneH = 90, 28
    local doneX, doneY = gx + gw - doneW - 16, gy + gh - doneH - 12
    local mx, my = Viewport.getMousePosition()
    local doneHover = mx >= doneX and mx <= doneX + doneW and my >= doneY and my <= doneY + doneH
    Theme.drawStyledButton(doneX, doneY, doneW, doneH, "Done", doneHover, love.timer.getTime())
    accentDone = { _rect = { x = doneX, y = doneY, w = doneW, h = doneH } }

    GraphicsPanel._colorPickerSliders = {}
    local sliderStartY = previewY + previewSize + 60
    local sliderWidth = previewSize + pickerSize - 20
    for idx, channel in ipairs({"r", "g", "b"}) do
        local sliderY = sliderStartY + (idx - 1) * 30
        local sliderX = pickerX
        Theme.drawGradientGlowRect(sliderX, sliderY, sliderWidth, 10, 2, Theme.colors.bg3, Theme.colors.bg2, Theme.colors.border, Theme.effects.glowWeak * 0.1)
        local handleX = sliderX + (sliderWidth - 10) * accentColorSliders[channel].value
        Theme.drawGradientGlowRect(handleX, sliderY - 4, 10, 18, 2, Theme.colors.accent, Theme.colors.bg3, Theme.colors.border, Theme.effects.glowWeak * 0.2)
        GraphicsPanel._colorPickerSliders[channel] = { x = sliderX, y = sliderY - 4, w = sliderWidth, h = 18 }
    end
end

-- (reticle gallery removed)

local function handleAccentGalleryClick(screenX, screenY)
    if not accentGalleryOpen then
        return false
    end

    if accentDone and screenX >= accentDone._rect.x and screenX <= accentDone._rect.x + accentDone._rect.w and screenY >= accentDone._rect.y and screenY <= accentDone._rect.y + accentDone._rect.h then
        local Sound = require("src.core.sound")
        Sound.playSFX("button_click")
        accentGalleryOpen = false
        return true
    end

    if accentSpectrum and screenX >= accentSpectrum.x and screenX <= accentSpectrum.x + accentSpectrum.w and screenY >= accentSpectrum.y and screenY <= accentSpectrum.y + accentSpectrum.h then
        local h = ((screenX - accentSpectrum.x) / accentSpectrum.w) * 360
        local v = 1.0 - ((screenY - accentSpectrum.y) / accentSpectrum.h)
        local s = 1.0

        local r, g, b = hsvToRgb(h, s, v)

        accentColorSliders.r.value = r
        accentColorSliders.g.value = g
        accentColorSliders.b.value = b

        applyCustomAccentColor(r, g, b)
        return true
    end

    if GraphicsPanel._colorPickerSliders then
        for channel, rect in pairs(GraphicsPanel._colorPickerSliders) do
            if screenX >= rect.x and screenX <= rect.x + rect.w and screenY >= rect.y and screenY <= rect.y + rect.h then
                local value = math.max(0, math.min(1, (screenX - rect.x) / rect.w))
                accentColorSliders[channel].value = value
                accentColorSliders[channel].dragging = true
                applyCustomAccentColor(accentColorSliders.r.value, accentColorSliders.g.value, accentColorSliders.b.value)
                return true
            end
        end
    end

    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local gw, gh = 600, 450
    local gx, gy = (sw - gw) / 2, (sh - gh) / 2
    if screenX >= gx and screenX <= gx + gw and screenY >= gy and screenY <= gy + gh then
        return true
    end

    return false
end

function GraphicsPanel.init()
    ensureDropdowns()
end

function GraphicsPanel.setSettings(settings)
    currentSettings = settings
    refreshDropdowns()

    if currentSettings then
        if currentSettings.accent_color_rgb and currentSettings.accent_theme == "Custom" then
            local rgb = currentSettings.accent_color_rgb
            accentColorSliders.r.value = rgb[1] or 0.7
            accentColorSliders.g.value = rgb[2] or 0.7
            accentColorSliders.b.value = rgb[3] or 0.7
            applyCustomAccentColor(accentColorSliders.r.value, accentColorSliders.g.value, accentColorSliders.b.value)
        else
            applyAccentTheme(currentSettings.accent_theme or "Monochrome")
        end
    end
end

function GraphicsPanel.draw(layout)
    ensureDropdowns()

    local yOffset = layout.yOffset
    local labelX = layout.labelX
    local valueX = layout.valueX
    local itemHeight = layout.itemHeight
    local mx, scrolledMouseY = layout.mx, layout.scrolledMouseY

    Theme.setColor(Theme.colors.accent)
    love.graphics.setFont(Theme.fonts and (Theme.fonts.normal or Theme.fonts.small) or love.graphics.getFont())
    love.graphics.print("Graphics Settings", labelX, yOffset)
    love.graphics.setFont(layout.settingsFont)
    yOffset = yOffset + 30

    Theme.setColor(Theme.colors.text)
    love.graphics.print("VSync:", labelX, yOffset)
    vsyncDropdown:setPosition(valueX, yOffset - 2 - layout.scrollY)
    yOffset = yOffset + itemHeight

    Theme.setColor(Theme.colors.text)
    love.graphics.print("Max FPS:", labelX, yOffset)
    fpsLimitDropdown:setPosition(valueX, yOffset - 2 - layout.scrollY)
    yOffset = yOffset + itemHeight

    Theme.setColor(Theme.colors.text)
    love.graphics.print("Show FPS:", labelX, yOffset)
    local showFpsToggleX = valueX
    local showFpsToggleY = yOffset - 4
    local showFpsToggleW = 60
    local showFpsToggleH = 26
    local showFpsToggleHover = mx >= showFpsToggleX and mx <= showFpsToggleX + showFpsToggleW and scrolledMouseY >= showFpsToggleY and scrolledMouseY <= showFpsToggleY + showFpsToggleH
    local showFpsToggleActive = currentSettings and currentSettings.show_fps or false
    Theme.drawStyledButton(showFpsToggleX, showFpsToggleY, showFpsToggleW, showFpsToggleH, showFpsToggleActive and "ON" or "OFF", showFpsToggleHover, love.timer.getTime())
    GraphicsPanel._showFpsToggleRect = { x = showFpsToggleX, y = showFpsToggleY - layout.scrollY, w = showFpsToggleW, h = showFpsToggleH }
    yOffset = yOffset + itemHeight

    

    Theme.setColor(Theme.colors.text)
    love.graphics.print("Accent Color:", labelX, yOffset)
    local accentBtnX, accentBtnY, accentBtnW, accentBtnH = valueX, yOffset - 4, 140, 26
    local accentBtnHover = mx >= accentBtnX and mx <= accentBtnX + accentBtnW and scrolledMouseY >= accentBtnY and scrolledMouseY <= accentBtnY + accentBtnH
    Theme.drawStyledButton(accentBtnX, accentBtnY, accentBtnW, accentBtnH, "Select Accent", accentBtnHover, love.timer.getTime())
    GraphicsPanel._accentButtonRect = { x = accentBtnX, y = accentBtnY - layout.scrollY, w = accentBtnW, h = accentBtnH }

    local accentPreviewSize = accentBtnH
    local accentPreviewX, accentPreviewY = accentBtnX + accentBtnW + 10, accentBtnY
    Theme.drawGradientGlowRect(accentPreviewX, accentPreviewY, accentPreviewSize, accentPreviewSize, 3, Theme.colors.bg2, Theme.colors.bg1, Theme.colors.border, Theme.effects.glowWeak * 0.1)
    local currentTheme = currentSettings and currentSettings.accent_theme or "Monochrome"
    local previewColor = Theme.colors.accent
    if currentTheme == "Custom" and currentSettings and currentSettings.accent_color_rgb then
        previewColor = currentSettings.accent_color_rgb
    end
    Theme.setColor(previewColor)
    love.graphics.rectangle("fill", accentPreviewX + 2, accentPreviewY + 2, accentPreviewSize - 4, accentPreviewSize - 4)
    Theme.setColor(Theme.colors.text)
    local themeText = currentTheme
    local themeTextX = accentPreviewX + accentPreviewSize + 10
    local themeTextY = accentPreviewY + (accentPreviewSize - Theme.fonts.medium:getHeight()) / 2
    love.graphics.print(themeText, themeTextX, themeTextY)
    yOffset = yOffset + itemHeight

    layout.yOffset = yOffset
    return yOffset
end

function GraphicsPanel.drawOverlays()
    drawAccentGallery()
end

function GraphicsPanel.drawForeground(mx, my)
    if vsyncDropdown then
        vsyncDropdown:drawButtonOnly(mx, my)
        fpsLimitDropdown:drawButtonOnly(mx, my)
        vsyncDropdown:drawOptionsOnly(mx, my)
        fpsLimitDropdown:drawOptionsOnly(mx, my)
    end
end

function GraphicsPanel.mousepressed(raw_x, raw_y, button)
    if button ~= 1 then return false end

    local screenX, screenY = Viewport.toScreen(raw_x, raw_y)
    if handleAccentGalleryClick(screenX, screenY) then return true end

    if GraphicsPanel._accentButtonRect and raw_x >= GraphicsPanel._accentButtonRect.x and raw_x <= GraphicsPanel._accentButtonRect.x + GraphicsPanel._accentButtonRect.w and raw_y >= GraphicsPanel._accentButtonRect.y and raw_y <= GraphicsPanel._accentButtonRect.y + GraphicsPanel._accentButtonRect.h then
        local Sound = require("src.core.sound")
        Sound.playSFX("button_click")
        accentGalleryOpen = not accentGalleryOpen
        return true
    end

    if GraphicsPanel._showFpsToggleRect and raw_x >= GraphicsPanel._showFpsToggleRect.x and raw_x <= GraphicsPanel._showFpsToggleRect.x + GraphicsPanel._showFpsToggleRect.w and raw_y >= GraphicsPanel._showFpsToggleRect.y and raw_y <= GraphicsPanel._showFpsToggleRect.y + GraphicsPanel._showFpsToggleRect.h then
        local Sound = require("src.core.sound")
        Sound.playSFX("button_click")
        if currentSettings then
            currentSettings.show_fps = not currentSettings.show_fps
        end
        return true
    end

    if vsyncDropdown and vsyncDropdown:mousepressed(raw_x, raw_y, button) then return true end
    if fpsLimitDropdown and fpsLimitDropdown:mousepressed(raw_x, raw_y, button) then return true end

    return false
end

function GraphicsPanel.mousemoved(x, y)
    if GraphicsPanel._colorPickerSliders then
        for channel, slider in pairs(GraphicsPanel._colorPickerSliders) do
            if accentColorSliders[channel].dragging then
                local value = math.max(0, math.min(1, (x - slider.x) / slider.w))
                accentColorSliders[channel].value = value
                applyCustomAccentColor(accentColorSliders.r.value, accentColorSliders.g.value, accentColorSliders.b.value)
            end
        end
    end

    if vsyncDropdown then vsyncDropdown:mousemoved(x, y) end
    if fpsLimitDropdown then fpsLimitDropdown:mousemoved(x, y) end
end

function GraphicsPanel.mousereleased()
    GraphicsPanel.stopDragging()
end

function GraphicsPanel.stopDragging()
    for _, slider in pairs(accentColorSliders) do
        slider.dragging = false
    end
end

function GraphicsPanel.beginSliderDrag(channel)
    if accentColorSliders[channel] then
        accentColorSliders[channel].dragging = true
    end
end

function GraphicsPanel.getContentHeight(baseY, itemHeight)
    local yOffset = baseY
    yOffset = yOffset + 30 -- section label
    yOffset = yOffset + itemHeight -- vsync
    yOffset = yOffset + itemHeight -- fps
    yOffset = yOffset + itemHeight -- show fps
    yOffset = yOffset + itemHeight -- accent
    return yOffset
end

GraphicsPanel.refreshDropdowns = refreshDropdowns
GraphicsPanel.applyAccentTheme = applyAccentTheme
GraphicsPanel.applyCustomAccentColor = applyCustomAccentColor
GraphicsPanel.handleAccentGalleryClick = handleAccentGalleryClick

return GraphicsPanel
