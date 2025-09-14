local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local Settings = require("src.core.settings")
local IconRenderer = require("src.content.icon_renderer")

local SettingsPanel = {}

SettingsPanel.visible = false

local currentGraphicsSettings
local currentAudioSettings
local resolutions
local selectedResolutionIndex
local selectedFullscreenTypeIndex
local keymap
local bindingAction
local draggingSlider = nil

local fullscreenTypes = {"windowed", "fullscreen", "borderless"}
local vsyncTypes = {"Off", "On"}
local fpsLimitTypes = {"Unlimited", "30", "60", "120", "144", "240"}
-- Reticle color picker state (always visible sliders in popup)
local colorPickerOpen = true
local resolutionDropdownOpen = false
local fullscreenDropdownOpen = false
local vsyncDropdownOpen = false
local fpsLimitDropdownOpen = false
local reticleColorDropdownOpen = false -- legacy (unused)
local reticleGalleryOpen = false
local scrollY = 0
local scrollDragOffset = 0
local contentHeight = 900 -- Increased for audio settings

function SettingsPanel.init()
    currentGraphicsSettings = Settings.getGraphicsSettings()
    currentAudioSettings = Settings.getAudioSettings()
    -- Ensure font_scale exists with default value
    if not currentGraphicsSettings.font_scale then
        currentGraphicsSettings.font_scale = 1.0
    end
    -- Ensure helpers_enabled exists with default value
    if currentGraphicsSettings.helpers_enabled == nil then
        currentGraphicsSettings.helpers_enabled = true
    end
    if not currentGraphicsSettings.reticle_style then
        currentGraphicsSettings.reticle_style = 1
    end
    keymap = Settings.getKeymap()

    -- Find the index of the current fullscreen type
    if not currentGraphicsSettings.fullscreen then
        selectedFullscreenTypeIndex = 1 -- windowed
    elseif currentGraphicsSettings.fullscreen_type == "desktop" then
        selectedFullscreenTypeIndex = 2 -- fullscreen
    else
        selectedFullscreenTypeIndex = 3 -- borderless
    end
end

function SettingsPanel.update(dt)
    if not SettingsPanel.visible then return end
    -- Update logic for the settings panel
end

function SettingsPanel.draw()
    if not SettingsPanel.visible then return end

    if not resolutions then
        resolutions = Settings.getAvailableResolutions()
        -- Find the index of the current resolution
        selectedResolutionIndex = 1 -- Default
        currentGraphicsSettings = Settings.getGraphicsSettings() -- Re-fetch current settings
        currentAudioSettings = Settings.getAudioSettings()
        -- Ensure font_scale exists with default value
        if not currentGraphicsSettings.font_scale then
            currentGraphicsSettings.font_scale = 1.0
        end
        if currentGraphicsSettings.helpers_enabled == nil then
            currentGraphicsSettings.helpers_enabled = true
        end
        for i, res in ipairs(resolutions) do
            if res.width == currentGraphicsSettings.resolution.width and res.height == currentGraphicsSettings.resolution.height then
                selectedResolutionIndex = i
                break
            end
        end
    end

    local sw, sh = Viewport.getDimensions()
    local w, h = 500, 600 -- Increased height for keybindings
    local x = (sw - w) / 2
    local y = (sh - h) / 2

    -- Draw menu background
    Theme.drawGradientGlowRect(x, y, w, h, 4, Theme.colors.bg1, Theme.colors.bg2, Theme.colors.primary, Theme.effects.glowWeak * 0.3)
    Theme.drawEVEBorder(x, y, w, h, 4, Theme.colors.border, 2)

    -- Draw title
    Theme.setColor(Theme.colors.textHighlight)
    local titleText = "Settings"
    local font = love.graphics.getFont()
    local titleW = font:getWidth(titleText)
    love.graphics.print(titleText, x + (w - titleW) / 2, y + 15)

    -- Close button
    local mx, my = Viewport.getMousePosition()
    local closeRect = { x = x + w - 26, y = y + 6, w = 20, h = 20 }
    local closeHover = mx >= closeRect.x and mx <= closeRect.x + closeRect.w and my >= closeRect.y and my <= closeRect.y + closeRect.h
    Theme.drawCloseButton(closeRect, closeHover)
    SettingsPanel._closeButton = closeRect
    
    love.graphics.push()
    local innerTop = y + 40
    local innerH = h - 80
    love.graphics.setScissor(x, innerTop, w, innerH)
    love.graphics.translate(0, -scrollY)


    -- Graphics settings
    local yOffset = y + 60
    local labelX = x + 20
    local valueX = x + 150
    local dropdownW = 150
    local itemHeight = 40

    -- Resolution
    Theme.setColor(Theme.colors.text)
    love.graphics.print("Resolution:", labelX, yOffset)
    local resText = "..."
    if resolutions and resolutions[selectedResolutionIndex] then
        resText = resolutions[selectedResolutionIndex].width .. "x" .. resolutions[selectedResolutionIndex].height
    end
    Theme.drawGradientGlowRect(valueX, yOffset - 2, dropdownW, 24, 2, Theme.colors.bg3, Theme.colors.bg2, Theme.colors.border, Theme.effects.glowWeak * 0.1)
    Theme.setColor(Theme.colors.textHighlight)
    love.graphics.print(resText, valueX + 5, yOffset + 4)
    love.graphics.polygon("fill", valueX + dropdownW - 15, yOffset + 8, valueX + dropdownW - 5, yOffset + 8, valueX + dropdownW - 10, yOffset + 13) -- Arrow
    yOffset = yOffset + itemHeight

    -- Display Mode
    Theme.setColor(Theme.colors.text)
    love.graphics.print("Display Mode:", labelX, yOffset)
    Theme.drawGradientGlowRect(valueX, yOffset - 2, dropdownW, 24, 2, Theme.colors.bg3, Theme.colors.bg2, Theme.colors.border, Theme.effects.glowWeak * 0.1)
    Theme.setColor(Theme.colors.textHighlight)
    love.graphics.print(fullscreenTypes[selectedFullscreenTypeIndex], valueX + 5, yOffset + 4)
    love.graphics.polygon("fill", valueX + dropdownW - 15, yOffset + 8, valueX + dropdownW - 5, yOffset + 8, valueX + dropdownW - 10, yOffset + 13) -- Arrow
    yOffset = yOffset + itemHeight

    -- VSync
    Theme.setColor(Theme.colors.text)
    love.graphics.print("VSync:", labelX, yOffset)
    Theme.drawGradientGlowRect(valueX, yOffset - 2, dropdownW, 24, 2, Theme.colors.bg3, Theme.colors.bg2, Theme.colors.border, Theme.effects.glowWeak * 0.1)
    Theme.setColor(Theme.colors.textHighlight)
    love.graphics.print(currentGraphicsSettings.vsync and "On" or "Off", valueX + 5, yOffset + 4)
    love.graphics.polygon("fill", valueX + dropdownW - 15, yOffset + 8, valueX + dropdownW - 5, yOffset + 8, valueX + dropdownW - 10, yOffset + 13) -- Arrow
    yOffset = yOffset + itemHeight

    -- Max FPS
    Theme.setColor(Theme.colors.text)
    love.graphics.print("Max FPS:", labelX, yOffset)
    local fpsText = currentGraphicsSettings.max_fps == 0 and "Unlimited" or tostring(currentGraphicsSettings.max_fps)
    Theme.drawGradientGlowRect(valueX, yOffset - 2, dropdownW, 24, 2, Theme.colors.bg3, Theme.colors.bg2, Theme.colors.border, Theme.effects.glowWeak * 0.1)
    Theme.setColor(Theme.colors.textHighlight)
    love.graphics.print(fpsText, valueX + 5, yOffset + 4)
    love.graphics.polygon("fill", valueX + dropdownW - 15, yOffset + 8, valueX + dropdownW - 5, yOffset + 8, valueX + dropdownW - 10, yOffset + 13) -- Arrow
    yOffset = yOffset + itemHeight

    -- UI Scale
    Theme.setColor(Theme.colors.text)
    love.graphics.print("UI Scale:", labelX, yOffset)
    local scaleText = string.format("%.2f", currentGraphicsSettings.ui_scale)
    love.graphics.print(scaleText, x + 400, yOffset)
    -- Simple slider
    local sliderX = valueX
    local sliderW = 200
    Theme.drawGradientGlowRect(sliderX, yOffset - 5, sliderW, 10, 2, Theme.colors.bg3, Theme.colors.bg2, Theme.colors.border, Theme.effects.glowWeak * 0.1)
    local handleX = sliderX + (sliderW - 10) * (currentGraphicsSettings.ui_scale - 0.5) / 1.5
    Theme.drawGradientGlowRect(handleX, yOffset - 7.5, 10, 15, 2, Theme.colors.accent, Theme.colors.bg3, Theme.colors.border, Theme.effects.glowWeak * 0.2)
    yOffset = yOffset + itemHeight

    -- Font Scale
    Theme.setColor(Theme.colors.text)
    love.graphics.print("Font Scale:", labelX, yOffset)
    local fontScaleText = string.format("%.2f", currentGraphicsSettings.font_scale or 1.0)
    love.graphics.print(fontScaleText, x + 400, yOffset)
    -- Font scale slider
    local fontSliderX = valueX
    local fontSliderW = 200
    Theme.drawGradientGlowRect(fontSliderX, yOffset - 5, fontSliderW, 10, 2, Theme.colors.bg3, Theme.colors.bg2, Theme.colors.border, Theme.effects.glowWeak * 0.1)
    local fontScale = currentGraphicsSettings.font_scale or 1.0
    local fontHandleX = fontSliderX + (fontSliderW - 10) * (fontScale - 0.5) / 1.5
    Theme.drawGradientGlowRect(fontHandleX, yOffset - 7.5, 10, 15, 2, Theme.colors.accent, Theme.colors.bg3, Theme.colors.border, Theme.effects.glowWeak * 0.2)
    yOffset = yOffset + itemHeight

    -- (Reticle style arrows removed; use popup instead)

    -- Reticle popup trigger, current preview, and color dropdown
    Theme.setColor(Theme.colors.text)
    love.graphics.print("Reticle:", labelX, yOffset)
    local btnX, btnY, btnW, btnH = valueX, yOffset - 4, 140, 26
    local mx, my = Viewport.getMousePosition()
    local btnHover = mx >= btnX and mx <= btnX + btnW and my + scrollY >= btnY and my + scrollY <= btnY + btnH
    Theme.drawStyledButton(btnX, btnY, btnW, btnH, "Choose Reticle...", btnHover, love.timer.getTime())
    SettingsPanel._reticleButtonRect = { x = btnX, y = btnY, w = btnW, h = btnH }
    -- Preview next to button (same height as button)
    local previewSize = btnH
    local pvX, pvY = btnX + btnW + 10, btnY
    Theme.drawGradientGlowRect(pvX, pvY, previewSize, previewSize, 3, Theme.colors.bg2, Theme.colors.bg1, Theme.colors.border, Theme.effects.glowWeak * 0.1)
    local Reticle = require("src.ui.hud.reticle")
    love.graphics.push()
    love.graphics.translate(pvX + previewSize * 0.5, pvY + previewSize * 0.5)
    Theme.setColor(Theme.colors.textHighlight)
    local previewScale = (previewSize / 32) * 0.85 * 0.8
    Reticle.drawPreset(currentGraphicsSettings.reticle_style or 1, previewScale, Theme.colors.textHighlight)
    love.graphics.pop()
    yOffset = yOffset + itemHeight

    -- Helpers toggle
    Theme.setColor(Theme.colors.text)
    love.graphics.print("Show Helpers:", labelX, yOffset)
    local toggleX, toggleY, toggleW, toggleH = valueX, yOffset - 2, 70, 24
    local enabled = currentGraphicsSettings.helpers_enabled ~= false
    Theme.drawGradientGlowRect(toggleX, toggleY, toggleW, toggleH, 3,
        enabled and Theme.colors.bg3 or Theme.colors.bg2,
        Theme.colors.bg1, Theme.colors.border, Theme.effects.glowWeak * 0.1)
    Theme.setColor(enabled and Theme.colors.accent or Theme.colors.textSecondary)
    local label = enabled and "On" or "Off"
    local tf = Theme.fonts and Theme.fonts.small or love.graphics.getFont()
    love.graphics.setFont(tf)
    local tw = tf:getWidth(label)
    love.graphics.print(label, toggleX + (toggleW - tw) / 2, toggleY + (toggleH - tf:getHeight()) / 2)
    love.graphics.setFont(Theme.fonts and Theme.fonts.normal or love.graphics.getFont())
    yOffset = yOffset + itemHeight

    -- Audio settings
    yOffset = yOffset + itemHeight
    Theme.setColor(Theme.colors.text)
    love.graphics.print("Audio", x + 20, yOffset)
    yOffset = yOffset + 30

    -- Master Volume
    Theme.setColor(Theme.colors.text)
    love.graphics.print("Master Volume:", labelX, yOffset)
    local masterVolumeText = string.format("%.2f", currentAudioSettings.master_volume)
    love.graphics.print(masterVolumeText, x + 400, yOffset)
    local masterSliderX = valueX
    local masterSliderW = 200
    Theme.drawGradientGlowRect(masterSliderX, yOffset - 5, masterSliderW, 10, 2, Theme.colors.bg3, Theme.colors.bg2, Theme.colors.border, Theme.effects.glowWeak * 0.1)
    local masterHandleX = masterSliderX + (masterSliderW - 10) * currentAudioSettings.master_volume
    Theme.drawGradientGlowRect(masterHandleX, yOffset - 7.5, 10, 15, 2, Theme.colors.accent, Theme.colors.bg3, Theme.colors.border, Theme.effects.glowWeak * 0.2)
    yOffset = yOffset + itemHeight

    -- SFX Volume
    Theme.setColor(Theme.colors.text)
    love.graphics.print("SFX Volume:", labelX, yOffset)
    local sfxVolumeText = string.format("%.2f", currentAudioSettings.sfx_volume)
    love.graphics.print(sfxVolumeText, x + 400, yOffset)
    local sfxSliderX = valueX
    local sfxSliderW = 200
    Theme.drawGradientGlowRect(sfxSliderX, yOffset - 5, sfxSliderW, 10, 2, Theme.colors.bg3, Theme.colors.bg2, Theme.colors.border, Theme.effects.glowWeak * 0.1)
    local sfxHandleX = sfxSliderX + (sfxSliderW - 10) * currentAudioSettings.sfx_volume
    Theme.drawGradientGlowRect(sfxHandleX, yOffset - 7.5, 10, 15, 2, Theme.colors.accent, Theme.colors.bg3, Theme.colors.border, Theme.effects.glowWeak * 0.2)
    yOffset = yOffset + itemHeight

    -- Music Volume
    Theme.setColor(Theme.colors.text)
    love.graphics.print("Music Volume:", labelX, yOffset)
    local musicVolumeText = string.format("%.2f", currentAudioSettings.music_volume)
    love.graphics.print(musicVolumeText, x + 400, yOffset)
    local musicSliderX = valueX
    local musicSliderW = 200
    Theme.drawGradientGlowRect(musicSliderX, yOffset - 5, musicSliderW, 10, 2, Theme.colors.bg3, Theme.colors.bg2, Theme.colors.border, Theme.effects.glowWeak * 0.1)
    local musicHandleX = musicSliderX + (musicSliderW - 10) * currentAudioSettings.music_volume
    Theme.drawGradientGlowRect(musicHandleX, yOffset - 7.5, 10, 15, 2, Theme.colors.accent, Theme.colors.bg3, Theme.colors.border, Theme.effects.glowWeak * 0.2)
    yOffset = yOffset + itemHeight


    -- Keybindings
    yOffset = yOffset + itemHeight
    Theme.setColor(Theme.colors.text)
    love.graphics.print("Keybindings", x + 20, yOffset)
    love.graphics.setFont(Theme.fonts.small)
    love.graphics.print("(Click to change)", x + 150, yOffset + 2)
    love.graphics.setFont(Theme.fonts.normal)
    yOffset = yOffset + 30
    
    -- Use consistent order for keybindings
    local keybindOrder = {
        "toggle_inventory", "toggle_bounty", "toggle_skills",
        "toggle_map", "dock", 
        "hotbar_1", "hotbar_2", "hotbar_3", "hotbar_4", "hotbar_5"
    }
    
    for _, action in ipairs(keybindOrder) do
        local key = keymap[action]
        if key then
            Theme.setColor(Theme.colors.text)
            love.graphics.print(action, x + 20, yOffset)
            
            -- Draw keybinding as a button
            local btnX, btnY, btnW, btnH = x + 200, yOffset - 2, 100, 24
            local keyText = bindingAction == action and "Press key..." or key
            local mx, my = Viewport.getMousePosition()
            local hover = mx >= btnX and mx <= btnX + btnW and my + scrollY >= btnY and my + scrollY <= btnY + btnH
            
            -- Button background
            Theme.drawGradientGlowRect(btnX, btnY, btnW, btnH, 3,
                hover and Theme.colors.bg3 or Theme.colors.bg2,
                Theme.colors.bg1, Theme.colors.border, Theme.effects.glowWeak * 0.2)
            
            -- Button text
            Theme.setColor(bindingAction == action and Theme.colors.accent or Theme.colors.textHighlight)
            love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
            local textW = love.graphics.getFont():getWidth(keyText)
            love.graphics.print(keyText, btnX + (btnW - textW) / 2, btnY + (btnH - 12) / 2)
            
            yOffset = yOffset + 30
        end
    end

    -- Update scrollable content height based on last yOffset
    contentHeight = math.max(innerH, (yOffset - innerTop) + 20)
    love.graphics.pop()
    love.graphics.setScissor()
    
    -- Button area background
    local buttonAreaY = y + h - 60
    Theme.drawGradientGlowRect(x, buttonAreaY, w, 60, 0, Theme.colors.bg1, Theme.colors.bg2, Theme.colors.primary, Theme.effects.glowWeak * 0.3)
    Theme.drawEVEBorder(x, buttonAreaY, w, 60, 0, Theme.colors.border, 2)

    -- Dropdowns must be drawn last to be on top, outside of the scrolled scissor area
    local dropdownYOffset = y + 60 - scrollY
    if resolutionDropdownOpen then
        local dropdownY = dropdownYOffset + 0*itemHeight + 25
        Theme.drawGradientGlowRect(valueX, dropdownY, dropdownW, #resolutions * 20 + 10, 2, Theme.colors.bg0, Theme.colors.bg1, Theme.colors.border, Theme.effects.glowWeak * 0.2)
        for i, res in ipairs(resolutions) do
            local resStr = res.width .. "x" .. res.height
            if i == selectedResolutionIndex then
                Theme.setColor(Theme.colors.accent)
            else
                Theme.setColor(Theme.colors.text)
            end
            love.graphics.print(resStr, valueX + 5, dropdownY + 5 + (i - 1) * 20)
        end
        Theme.setColor(Theme.colors.text)
    end

    if fullscreenDropdownOpen then
        local dropdownY = dropdownYOffset + 1*itemHeight + 25
        Theme.drawGradientGlowRect(valueX, dropdownY, dropdownW, #fullscreenTypes * 20 + 10, 2, Theme.colors.bg0, Theme.colors.bg1, Theme.colors.border, Theme.effects.glowWeak * 0.2)
        for i, fstype in ipairs(fullscreenTypes) do
            if i == selectedFullscreenTypeIndex then
                Theme.setColor(Theme.colors.accent)
            else
                Theme.setColor(Theme.colors.text)
            end
            love.graphics.print(fstype, valueX + 5, dropdownY + 5 + (i - 1) * 20)
        end
        Theme.setColor(Theme.colors.text)
    end

    if vsyncDropdownOpen then
        local dropdownY = dropdownYOffset + 2*itemHeight + 25
        Theme.drawGradientGlowRect(valueX, dropdownY, dropdownW, #vsyncTypes * 20 + 10, 2, Theme.colors.bg0, Theme.colors.bg1, Theme.colors.border, Theme.effects.glowWeak * 0.2)
        for i, vsyncType in ipairs(vsyncTypes) do
            local isSelected = (currentGraphicsSettings.vsync and i == 2) or (not currentGraphicsSettings.vsync and i == 1)
            if isSelected then
                Theme.setColor(Theme.colors.accent)
            else
                Theme.setColor(Theme.colors.text)
            end
            love.graphics.print(vsyncType, valueX + 5, dropdownY + 5 + (i - 1) * 20)
        end
        Theme.setColor(Theme.colors.text)
    end

    if fpsLimitDropdownOpen then
        local dropdownY = dropdownYOffset + 3*itemHeight + 25
        Theme.drawGradientGlowRect(valueX, dropdownY, dropdownW, #fpsLimitTypes * 20 + 10, 2, Theme.colors.bg0, Theme.colors.bg1, Theme.colors.border, Theme.effects.glowWeak * 0.2)
        for i, fpsType in ipairs(fpsLimitTypes) do
            local fpsValue = fpsType == "Unlimited" and 0 or tonumber(fpsType)
            if fpsValue == currentGraphicsSettings.max_fps then
                Theme.setColor(Theme.colors.accent)
            else
                Theme.setColor(Theme.colors.text)
            end
            love.graphics.print(fpsType, valueX + 5, dropdownY + 5 + (i - 1) * 20)
        end
        Theme.setColor(Theme.colors.text)
    end

    -- Apply and Exit buttons
    local buttonW, buttonH = 100, 30
    local exitButtonX = x + (w / 2) - buttonW - 10
    local applyButtonX = x + (w / 2) + 10
    local buttonY = y + h - buttonH - 15

    -- Apply Button
    Theme.drawGradientGlowRect(applyButtonX, buttonY, buttonW, buttonH, 4, Theme.colors.success, Theme.colors.bg2, Theme.colors.primary, Theme.effects.glowWeak * 0.2)
    Theme.drawEVEBorder(applyButtonX, buttonY, buttonW, buttonH, 4, Theme.colors.border, 1)
    Theme.setColor(Theme.colors.text)
    local applyText = "Apply"
    local applyTextW = font:getWidth(applyText)
    love.graphics.printf(applyText, applyButtonX, buttonY + (buttonH - font:getHeight()) / 2, buttonW, "center")

    -- Exit Button
    Theme.drawGradientGlowRect(exitButtonX, buttonY, buttonW, buttonH, 4, Theme.colors.danger, Theme.colors.bg2, Theme.colors.primary, Theme.effects.glowWeak * 0.2)
    Theme.drawEVEBorder(exitButtonX, buttonY, buttonW, buttonH, 4, Theme.colors.border, 1)
    Theme.setColor(Theme.colors.text)
    local exitText = "Exit"
    local exitTextW = font:getWidth(exitText)
    love.graphics.printf(exitText, exitButtonX, buttonY + (buttonH - font:getHeight()) / 2, buttonW, "center")

    -- Scrollbar
    local scrollbarX = x + w - 10
    local scrollbarY = innerTop
    local scrollbarH = innerH
    if contentHeight > innerH then
        local thumbH = math.max(24, scrollbarH * (innerH / contentHeight))
        local trackRange = scrollbarH - thumbH
        local thumbY = scrollbarY + (trackRange > 0 and (trackRange * (scrollY / (contentHeight - innerH))) or 0)
        Theme.drawGradientGlowRect(scrollbarX, scrollbarY, 8, scrollbarH, 2, Theme.colors.bg0, Theme.colors.bg1, Theme.colors.border, 0)
        Theme.drawGradientGlowRect(scrollbarX, thumbY, 8, thumbH, 2, Theme.colors.accent, Theme.colors.bg3, Theme.colors.border, 0)
        SettingsPanel._scrollbarTrack = { x = scrollbarX, y = scrollbarY, w = 8, h = scrollbarH }
        SettingsPanel._scrollbarThumb = { x = scrollbarX, y = thumbY, w = 8, h = thumbH }
    else
        SettingsPanel._scrollbarTrack = nil
        SettingsPanel._scrollbarThumb = nil
    end

    -- Reticle Gallery Popup
    if reticleGalleryOpen then
        local sw, sh = Viewport.getDimensions()
        local gw, gh = 560, 420
        local gx, gy = (sw - gw) / 2, (sh - gh) / 2
        Theme.drawGradientGlowRect(gx, gy, gw, gh, 6, Theme.colors.bg1, Theme.colors.bg0, Theme.colors.accent, Theme.effects.glowWeak)
        Theme.drawEVEBorder(gx, gy, gw, gh, 6, Theme.colors.border, 8)
        Theme.setColor(Theme.colors.textHighlight)
        love.graphics.print("Choose Reticle", gx + 16, gy + 12)
        -- Color selector inside popup (RGB sliders)
        -- Determine current color (RGB)
        local function getCurrentRGB()
          local c = currentGraphicsSettings.reticle_color_rgb
          if c and type(c) == 'table' then return c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1 end
          local ThemeMod = require('src.core.theme')
          local name = currentGraphicsSettings.reticle_color or 'accent'
          local map = {
            accent = ThemeMod.colors.accent,
            white = {1,1,1,1},
            cyan = ThemeMod.colors.info,
            green = ThemeMod.colors.success,
            red = ThemeMod.colors.danger,
            yellow = ThemeMod.colors.warning,
            magenta = ThemeMod.colors.accentPink,
            teal = ThemeMod.colors.accentTeal,
            gold = ThemeMod.colors.accentGold,
          }
          local cc = map[(name or 'accent'):lower()] or ThemeMod.colors.accent
          return cc[1], cc[2], cc[3], cc[4] or 1
        end
        local cr, cg, cb, ca = getCurrentRGB()
        -- Always-visible RGB sliders
        local sx, sy = gx + 16, gy + 40
        local sliderW, sliderH = 240, 10
        local function drawSlider(label, value, ry, color)
          Theme.setColor(Theme.colors.text)
          love.graphics.print(label, sx, ry - 12)
          Theme.drawGradientGlowRect(sx, ry, sliderW, sliderH, 2, Theme.colors.bg3, Theme.colors.bg2, Theme.colors.border, Theme.effects.glowWeak * 0.1)
          Theme.setColor(color)
          local fillW = math.max(0, math.min(sliderW, sliderW * value))
          Theme.drawGradientGlowRect(sx, ry, fillW, sliderH, 2, color, color, Theme.colors.border, 0)
          Theme.drawEVEBorder(sx, ry, sliderW, sliderH, 2, Theme.colors.border, 1)
          -- Handle knob
          Theme.setColor(Theme.colors.textHighlight)
          local knobX = sx + fillW - 4
          love.graphics.rectangle('fill', knobX, ry - 2, 8, sliderH + 4)
        end
        drawSlider('R', cr, sy, {1,0,0,1})
        drawSlider('G', cg, sy + 24, {0,1,0,1})
        drawSlider('B', cb, sy + 48, {0,0,1,1})
        SettingsPanel._colorSliders = {
          { x = sx, y = sy, w = sliderW, h = sliderH, key = 'r' },
          { x = sx, y = sy + 24, w = sliderW, h = sliderH, key = 'g' },
          { x = sx, y = sy + 48, w = sliderW, h = sliderH, key = 'b' },
        }
        -- Gallery
        local px, py = gx + 16, sy + 80
        local cols, cell, gap = 10, 44, 8
        local total, rows = 50, math.ceil(50/cols)
        SettingsPanel._reticlePopup = { x = px, y = py, cols = cols, rows = rows, cell = cell, gap = gap }
        local Reticle = require("src.ui.hud.reticle")
        local curStyle = currentGraphicsSettings.reticle_style or 1
        for i = 1, total do
            local r = math.floor((i-1)/cols)
            local c = (i-1) % cols
            local cx = px + c * (cell + gap)
            local cy = py + r * (cell + gap)
            local isSel = (i == curStyle)
            Theme.drawGradientGlowRect(cx, cy, cell, cell, 3, isSel and Theme.colors.bg3 or Theme.colors.bg2, Theme.colors.bg1, Theme.colors.border, Theme.effects.glowWeak * 0.1)
            love.graphics.push()
            love.graphics.translate(cx + cell * 0.5, cy + cell * 0.5)
            -- Use selected color for previews
            Theme.setColor({cr, cg, cb, 1})
            local previewScale = 0.8 * (cell / 32) * 0.85
            Reticle.drawPreset(i, previewScale, {cr, cg, cb, 1})
            love.graphics.pop()
        end
        -- Done button
        local doneW, doneH = 90, 28
        local doneX, doneY = gx + gw - doneW - 16, gy + gh - doneH - 12
        local mx, my = Viewport.getMousePosition()
        local hover = mx >= doneX and mx <= doneX + doneW and my >= doneY and my <= doneY + doneH
        Theme.drawStyledButton(doneX, doneY, doneW, doneH, "Done", hover, love.timer.getTime())
        SettingsPanel._reticleDone = { x = doneX, y = doneY, w = doneW, h = doneH }
    else
        SettingsPanel._reticlePopup = nil
        SettingsPanel._reticleDone = nil
    end
end

function SettingsPanel.mousepressed(x, y, button)
    if not SettingsPanel.visible then return false, false end

    local sw, sh = Viewport.getDimensions()
    local w, h = 500, 600
    local panelX = (sw - w) / 2
    local panelY = (sh - h) / 2

    -- Transform mouse position to account for scroll (define early)
    local mouseY = y + scrollY

    local valueX = panelX + 150
    local dropdownW = 150
    local itemHeight = 40
    
    -- Use original mouse Y for dropdowns as they are drawn outside the scroll area
    local dropdownMouseY = y 
    local dropdownYOffset = panelY + 60 - scrollY

    if resolutionDropdownOpen then
        local dropdownY = dropdownYOffset + 0*itemHeight + 25
        local dropdownH = #resolutions * 20 + 10
        if x > valueX and x < valueX + dropdownW and dropdownMouseY > dropdownY and dropdownMouseY < dropdownY + dropdownH then
            local itemIndex = math.floor((dropdownMouseY - dropdownY - 5) / 20) + 1
            if itemIndex >= 1 and itemIndex <= #resolutions then
                selectedResolutionIndex = itemIndex
                resolutionDropdownOpen = false
                return true
            end
        end
        resolutionDropdownOpen = false
    end

    if fullscreenDropdownOpen then
        local dropdownY = dropdownYOffset + 1*itemHeight + 25
        local dropdownH = #fullscreenTypes * 20 + 10
        if x > valueX and x < valueX + dropdownW and dropdownMouseY > dropdownY and dropdownMouseY < dropdownY + dropdownH then
            local itemIndex = math.floor((dropdownMouseY - dropdownY - 5) / 20) + 1
            if itemIndex >= 1 and itemIndex <= #fullscreenTypes then
                selectedFullscreenTypeIndex = itemIndex
                fullscreenDropdownOpen = false
                return true
            end
        end
        fullscreenDropdownOpen = false
    end

    if vsyncDropdownOpen then
        local dropdownY = dropdownYOffset + 2*itemHeight + 25
        local dropdownH = #vsyncTypes * 20 + 10
        if x > valueX and x < valueX + dropdownW and dropdownMouseY > dropdownY and dropdownMouseY < dropdownY + dropdownH then
            local itemIndex = math.floor((dropdownMouseY - dropdownY - 5) / 20) + 1
            if itemIndex >= 1 and itemIndex <= #vsyncTypes then
                currentGraphicsSettings.vsync = (itemIndex == 2)
                vsyncDropdownOpen = false
                return true
            end
        end
        vsyncDropdownOpen = false
    end

    if fpsLimitDropdownOpen then
        local dropdownY = dropdownYOffset + 3*itemHeight + 25
        local dropdownH = #fpsLimitTypes * 20 + 10
        if x > valueX and x < valueX + dropdownW and dropdownMouseY > dropdownY and dropdownMouseY < dropdownY + dropdownH then
            local itemIndex = math.floor((dropdownMouseY - dropdownY - 5) / 20) + 1
            if itemIndex >= 1 and itemIndex <= #fpsLimitTypes then
                local fpsType = fpsLimitTypes[itemIndex]
                currentGraphicsSettings.max_fps = fpsType == "Unlimited" and 0 or tonumber(fpsType)
                fpsLimitDropdownOpen = false
                return true
            end
        end
        fpsLimitDropdownOpen = false
    end

    -- UI Element Interaction (Dropdowns, Sliders, Buttons)
    -- This block calculates yOffset sequentially to match the draw order.
    local yOffset = panelY + 60

    -- Resolution
    if x > valueX and x < valueX + dropdownW and mouseY > yOffset - 2 and mouseY < yOffset + 22 then
        resolutionDropdownOpen = not resolutionDropdownOpen
        fullscreenDropdownOpen, vsyncDropdownOpen, fpsLimitDropdownOpen = false, false, false
        return true
    end
    yOffset = yOffset + itemHeight

    -- Display Mode
    if x > valueX and x < valueX + dropdownW and mouseY > yOffset - 2 and mouseY < yOffset + 22 then
        fullscreenDropdownOpen = not fullscreenDropdownOpen
        resolutionDropdownOpen, vsyncDropdownOpen, fpsLimitDropdownOpen = false, false, false
        return true
    end
    yOffset = yOffset + itemHeight

    -- VSync
    if x > valueX and x < valueX + dropdownW and mouseY > yOffset - 2 and mouseY < yOffset + 22 then
        vsyncDropdownOpen = not vsyncDropdownOpen
        resolutionDropdownOpen, fullscreenDropdownOpen, fpsLimitDropdownOpen = false, false, false
        return true
    end
    yOffset = yOffset + itemHeight

    -- Max FPS
    if x > valueX and x < valueX + dropdownW and mouseY > yOffset - 2 and mouseY < yOffset + 22 then
        fpsLimitDropdownOpen = not fpsLimitDropdownOpen
        resolutionDropdownOpen, fullscreenDropdownOpen, vsyncDropdownOpen = false, false, false
        return true
    end
    yOffset = yOffset + itemHeight

    -- UI Scale slider
    if not bindingAction then
        local sliderX = valueX
        local sliderW = 200
        if x > sliderX and x < sliderX + sliderW and mouseY > yOffset - 7.5 and mouseY < yOffset + 7.5 then
            draggingSlider = "ui_scale"
            return true
        end
    end
    yOffset = yOffset + itemHeight

    -- Font Scale slider
    if not bindingAction then
        local fontSliderX = valueX
        local fontSliderW = 200
        if x > fontSliderX and x < fontSliderX + fontSliderW and mouseY > yOffset - 7.5 and mouseY < yOffset + 7.5 then
            draggingSlider = "font_scale"
            return true
        end
    end
    yOffset = yOffset + itemHeight

    -- Reticle popup open button only (color is in popup)
    do
        local r = SettingsPanel._reticleButtonRect
        if r then
            if x >= r.x and x <= r.x + r.w and mouseY >= r.y and mouseY <= r.y + r.h then
                reticleGalleryOpen = true
                return true
            end
        end
    end
    yOffset = yOffset + itemHeight

    -- Helpers toggle
    local toggleX, toggleY, toggleW, toggleH = valueX, yOffset - 2, 70, 24
    if x > toggleX and x < toggleX + toggleW and mouseY > toggleY and mouseY < toggleY + toggleH then
        currentGraphicsSettings.helpers_enabled = not (currentGraphicsSettings.helpers_enabled ~= false)
        return true
    end
    yOffset = yOffset + itemHeight

    -- Audio sliders
    yOffset = yOffset + itemHeight -- Skip "Audio" label
    yOffset = yOffset + 30

    -- Master Volume slider
    if not bindingAction then
        local masterSliderX = valueX
        local masterSliderW = 200
        if x > masterSliderX and x < masterSliderX + masterSliderW and mouseY > yOffset - 7.5 and mouseY < yOffset + 7.5 then
            draggingSlider = "master_volume"
            return true
        end
    end
    yOffset = yOffset + itemHeight

    -- SFX Volume slider
    if not bindingAction then
        local sfxSliderX = valueX
        local sfxSliderW = 200
        if x > sfxSliderX and x < sfxSliderX + sfxSliderW and mouseY > yOffset - 7.5 and mouseY < yOffset + 7.5 then
            draggingSlider = "sfx_volume"
            return true
        end
    end
    yOffset = yOffset + itemHeight

    -- Music Volume slider
    if not bindingAction then
        local musicSliderX = valueX
        local musicSliderW = 200
        if x > musicSliderX and x < musicSliderX + musicSliderW and mouseY > yOffset - 7.5 and mouseY < yOffset + 7.5 then
            draggingSlider = "music_volume"
            return true
        end
    end
    yOffset = yOffset + itemHeight

    -- Keybindings
    yOffset = yOffset + itemHeight -- spacing for "Keybindings" label
    yOffset = yOffset + 30 -- for the label itself

    -- Use the same consistent order as in drawing
    local keybindOrder = {
        "toggle_inventory", "toggle_bounty", "toggle_skills",
        "toggle_map", "dock",
        "hotbar_1", "hotbar_2", "hotbar_3", "hotbar_4", "hotbar_5"
    }

    for _, action in ipairs(keybindOrder) do
        local key = keymap[action]
        if key then
            -- Match the exact button coordinates from drawing
            local btnX, btnY, btnW, btnH = panelX + 200, yOffset - 2, 100, 24
            if x >= btnX and x <= btnX + btnW and mouseY >= btnY and mouseY <= btnY + btnH then
                bindingAction = action
                return true
            end
            yOffset = yOffset + 30
        end
    end

    -- Handle reticle popup interactions
    if reticleGalleryOpen then
        local sw, sh = Viewport.getDimensions()
        local gw, gh = 560, 420
        local gx, gy = (sw - gw) / 2, (sh - gh) / 2
        -- Handle RGB slider input
        if SettingsPanel._colorSliders then
            for _, s in ipairs(SettingsPanel._colorSliders) do
                if x >= s.x and x <= s.x + s.w and y >= s.y and y <= s.y + s.h then
                    draggingSlider = 'reticle_color_' .. s.key
                    -- set value immediately
                    local pct = (x - s.x) / s.w
                    local r, g, b, a = 1,1,1,1
                    if currentGraphicsSettings.reticle_color_rgb and type(currentGraphicsSettings.reticle_color_rgb) == 'table' then
                        r = currentGraphicsSettings.reticle_color_rgb[1] or 1
                        g = currentGraphicsSettings.reticle_color_rgb[2] or 1
                        b = currentGraphicsSettings.reticle_color_rgb[3] or 1
                        a = currentGraphicsSettings.reticle_color_rgb[4] or 1
                    end
                    if s.key == 'r' then r = math.max(0, math.min(1, pct)) end
                    if s.key == 'g' then g = math.max(0, math.min(1, pct)) end
                    if s.key == 'b' then b = math.max(0, math.min(1, pct)) end
                    currentGraphicsSettings.reticle_color_rgb = { r, g, b, a }
                    return true
                end
            end
        end
        -- Done button
        if SettingsPanel._reticleDone then
            local r = SettingsPanel._reticleDone
            if x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then
                reticleGalleryOpen = false
                reticleColorDropdownOpen = false
                return true
            end
        end
        -- Grid click
        if SettingsPanel._reticlePopup then
            local g = SettingsPanel._reticlePopup
            for i = 1, 50 do
                local r = math.floor((i-1)/g.cols)
                local c = (i-1) % g.cols
                local rx = g.x + c * (g.cell + g.gap)
                local ry = g.y + r * (g.cell + g.gap)
                if x >= rx and x <= rx + g.cell and y >= ry and y <= ry + g.cell then
                    currentGraphicsSettings.reticle_style = i
                    return true
                end
            end
        end
        -- Click outside popup closes it
        if not (x >= gx and x <= gx + gw and y >= gy and y <= gy + gh) then
            reticleGalleryOpen = false
            reticleColorDropdownOpen = false
            return true
        end
    end

    -- Scrollbar interactions (track and thumb)
    if SettingsPanel._scrollbarTrack and SettingsPanel._scrollbarThumb then
        local tr = SettingsPanel._scrollbarTrack
        local th = SettingsPanel._scrollbarThumb
        -- Click on thumb: start dragging
        if x >= th.x and x <= th.x + th.w and y >= th.y and y <= th.y + th.h then
            draggingSlider = "scrollbar"
            scrollDragOffset = y - th.y
            return true
        end
        -- Click on track: jump thumb to position
        if x >= tr.x and x <= tr.x + tr.w and y >= tr.y and y <= tr.y + tr.h then
            local sw, sh = Viewport.getDimensions()
            local w, h = 500, 600
            local innerH = h - 80
            local trackRange = tr.h - th.h
            local rel = math.max(0, math.min(trackRange, (y - tr.y) - th.h * 0.5))
            local frac = trackRange > 0 and (rel / trackRange) or 0
            local maxScroll = math.max(0, (contentHeight or innerH) - innerH)
            scrollY = math.max(0, math.min(maxScroll, frac * maxScroll))
            return true
        end
    end

    -- Apply and Exit buttons
    local buttonW, buttonH = 100, 30
    local exitButtonX = panelX + (w / 2) - buttonW - 10
    local applyButtonX = panelX + (w / 2) + 10
    local buttonY = panelY + h - buttonH - 15

    if y > buttonY and y < buttonY + buttonH then
        -- Apply Button
        if x > applyButtonX and x < applyButtonX + buttonW then
            local newGraphicsSettings = {
                resolution = resolutions[selectedResolutionIndex],
                fullscreen = selectedFullscreenTypeIndex > 1,
                fullscreen_type = "desktop",
                vsync = currentGraphicsSettings.vsync,
                max_fps = currentGraphicsSettings.max_fps,
                ui_scale = currentGraphicsSettings.ui_scale,
                font_scale = currentGraphicsSettings.font_scale,
                helpers_enabled = currentGraphicsSettings.helpers_enabled ~= false,
                reticle_style = math.max(1, math.min(50, currentGraphicsSettings.reticle_style or 1)),
                reticle_color = currentGraphicsSettings.reticle_color or "accent",
                reticle_color_rgb = currentGraphicsSettings.reticle_color_rgb,
            }
            Settings.applyGraphicsSettings(newGraphicsSettings)
            Settings.applyAudioSettings(currentAudioSettings)
            Settings.save()
            Viewport.init(newGraphicsSettings.resolution.width, newGraphicsSettings.resolution.height)
            -- Reload fonts with new UI scale
            local Theme = require("src.core.theme")
            if Theme.loadFonts then Theme.loadFonts() end
            IconRenderer.clearCache()
            -- Rebuild canvased icons that may be invalidated by setMode
            local Content = require("src.content.content")
            if Content and Content.rebuildIcons then Content.rebuildIcons() end
            return true
        end

        -- Exit Button
        if x > exitButtonX and x < exitButtonX + buttonW then
            SettingsPanel.toggle()
            return true
        end
    end

    if SettingsPanel._closeButton then
        local btn = SettingsPanel._closeButton
        if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
            SettingsPanel.toggle()
            return true, true
        end
    end

    if x > panelX and x < panelX + w and y > panelY and y < panelY + h then
        return true
    end

    return false
end

function SettingsPanel.mousereleased(x, y, button)
    if not SettingsPanel.visible then return false end
    draggingSlider = nil
    return false
end

function SettingsPanel.mousemoved(x, y, dx, dy)
    if not SettingsPanel.visible or not draggingSlider then return false end

    local vx, vy = Viewport.toVirtual(x, y)
    x, y = vx, vy

    local sw, sh = Viewport.getDimensions()
    local w, h = 500, 600
    local panelX = (sw - w) / 2
    local panelY = (sh - h) / 2
    local valueX = panelX + 150
    local sliderW = 200

    -- Confine mouse to panel bounds while dragging sliders
    if x < panelX then x = panelX end
    if x > panelX + w then x = panelX + w end

    if draggingSlider == "ui_scale" then
        local pct = (x - valueX) / sliderW
        currentGraphicsSettings.ui_scale = math.max(0.5, math.min(2.0, 0.5 + pct * 1.5))
    elseif draggingSlider == "font_scale" then
        local pct = (x - valueX) / sliderW
        currentGraphicsSettings.font_scale = math.max(0.5, math.min(2.0, 0.5 + pct * 1.5))
    elseif draggingSlider == "scrollbar" then
        -- Drag scrollbar thumb
        local sw, sh = Viewport.getDimensions()
        local w, h = 500, 600
        local innerH = h - 80
        local tr = SettingsPanel._scrollbarTrack
        local th = SettingsPanel._scrollbarThumb
        if tr and th then
            local trackRange = tr.h - th.h
            local newThumbY = math.max(tr.y, math.min(tr.y + trackRange, (y - scrollDragOffset)))
            local rel = newThumbY - tr.y
            local frac = trackRange > 0 and (rel / trackRange) or 0
            local maxScroll = math.max(0, (contentHeight or innerH) - innerH)
            scrollY = math.max(0, math.min(maxScroll, frac * maxScroll))
        end
    elseif draggingSlider == "master_volume" then
        local pct = (x - valueX) / sliderW
        currentAudioSettings.master_volume = math.max(0, math.min(1, pct))
    elseif draggingSlider == "sfx_volume" then
        local pct = (x - valueX) / sliderW
        currentAudioSettings.sfx_volume = math.max(0, math.min(1, pct))
    elseif draggingSlider == "music_volume" then
        local pct = (x - valueX) / sliderW
        currentAudioSettings.music_volume = math.max(0, math.min(1, pct))
    elseif draggingSlider == "reticle_color_r" or draggingSlider == "reticle_color_g" or draggingSlider == "reticle_color_b" then
        if SettingsPanel._colorSliders then
            local r, g, b, a = 1,1,1,1
            if currentGraphicsSettings.reticle_color_rgb and type(currentGraphicsSettings.reticle_color_rgb) == 'table' then
                r = currentGraphicsSettings.reticle_color_rgb[1] or 1
                g = currentGraphicsSettings.reticle_color_rgb[2] or 1
                b = currentGraphicsSettings.reticle_color_rgb[3] or 1
                a = currentGraphicsSettings.reticle_color_rgb[4] or 1
            end
            for _, s in ipairs(SettingsPanel._colorSliders) do
                if draggingSlider == ('reticle_color_' .. s.key) then
                    local pct = math.max(0, math.min(1, (x - s.x) / s.w))
                    if s.key == 'r' then r = pct end
                    if s.key == 'g' then g = pct end
                    if s.key == 'b' then b = pct end
                end
            end
            currentGraphicsSettings.reticle_color_rgb = { r, g, b, a }
        end
    end

    return true
end

function SettingsPanel.wheelmoved(x, y)
    if not SettingsPanel.visible then return false end
    local sw, sh = Viewport.getDimensions()
    local w, h = 500, 600
    local innerH = h - 80
    local maxScroll = math.max(0, (contentHeight or innerH) - innerH)
    scrollY = math.max(0, math.min(maxScroll, scrollY - y * 20))
    return true
end

function SettingsPanel.keypressed(key)
    if not SettingsPanel.visible then return false end

    if bindingAction then
        Settings.setKeyBinding(bindingAction, key)
        keymap = Settings.getKeymap()
        bindingAction = nil
        return true
    end

    return false
end

function SettingsPanel.toggle()
    SettingsPanel.visible = not SettingsPanel.visible
end

function SettingsPanel.isBinding()
    return bindingAction ~= nil
end

return SettingsPanel
