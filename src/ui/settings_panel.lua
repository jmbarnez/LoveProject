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
    local doneButton = {_rect = {x = doneX, y = doneY, w = doneW, h = doneH}}
    local hover = Theme.handleButtonClick(doneButton, Viewport.getMousePosition())
    Theme.drawStyledButton(doneX, doneY, doneW, doneH, "Done", hover, love.timer.getTime())
    SettingsPanel._reticleDone = doneButton
    else
        SettingsPanel._reticlePopup = nil
        SettingsPanel._reticleDone = nil
    end
end

function SettingsPanel.mousepressed(x, y, button)
    if not SettingsPanel.visible or button ~= 1 then return false end

    local vx, vy = Viewport.toVirtual(x, y)
    x, y = vx, vy

    local sw, sh = Viewport.getDimensions()
    local w, h = 500, 600
    local panelX = (sw - w) / 2
    local panelY = (sh - h) / 2

    -- Handle close button
    if SettingsPanel._closeButton and x >= SettingsPanel._closeButton.x and x <= SettingsPanel._closeButton.x + SettingsPanel._closeButton.w and
       y >= SettingsPanel._closeButton.y and y <= SettingsPanel._closeButton.y + SettingsPanel._closeButton.h then
        SettingsPanel.visible = false
        return true
    end

    -- Handle reticle gallery done button
    if SettingsPanel._reticleDone and x >= SettingsPanel._reticleDone._rect.x and x <= SettingsPanel._reticleDone._rect.x + SettingsPanel._reticleDone._rect.w and
       y >= SettingsPanel._reticleDone._rect.y and y <= SettingsPanel._reticleDone._rect.y + SettingsPanel._reticleDone._rect.h then
        reticleGalleryOpen = false
        return true
    end

    -- Handle reticle selection
    if SettingsPanel._reticlePopup and x >= SettingsPanel._reticlePopup.x and y >= SettingsPanel._reticlePopup.y then
        local col = math.floor((x - SettingsPanel._reticlePopup.x) / (SettingsPanel._reticlePopup.cell + SettingsPanel._reticlePopup.gap))
        local row = math.floor((y - SettingsPanel._reticlePopup.y) / (SettingsPanel._reticlePopup.cell + SettingsPanel._reticlePopup.gap))
        local index = row * SettingsPanel._reticlePopup.cols + col + 1
        
        if index >= 1 and index <= 50 then
            currentGraphicsSettings.reticle_style = index
            return true
        end
    end

    -- Handle color sliders
    if SettingsPanel._colorSliders then
        for _, slider in ipairs(SettingsPanel._colorSliders) do
            if x >= slider.x and x <= slider.x + slider.w and y >= slider.y - 10 and y <= slider.y + slider.h + 10 then
                draggingSlider = 'reticle_color_' .. slider.key
                scrollDragOffset = y - slider.y
                return true
            end
        end
    end

    -- Handle scrollbar
    if SettingsPanel._scrollbarThumb and x >= SettingsPanel._scrollbarThumb.x and x <= SettingsPanel._scrollbarThumb.x + SettingsPanel._scrollbarThumb.w and
       y >= SettingsPanel._scrollbarThumb.y and y <= SettingsPanel._scrollbarThumb.y + SettingsPanel._scrollbarThumb.h then
        draggingSlider = "scrollbar"
        scrollDragOffset = y - SettingsPanel._scrollbarThumb.y
        return true
    end

    local buttonW, buttonH = 100, 30
    local exitButtonX = panelX + (w / 2) - buttonW - 10
    local applyButtonX = panelX + (w / 2) + 10
    local buttonY = panelY + h - buttonH - 15

    -- Apply Button
    local applyButton = {_rect = {x = applyButtonX, y = buttonY, w = buttonW, h = buttonH}}
    if Theme.handleButtonClick(applyButton, x, y, function()
        local newGraphicsSettings = {
            resolution = resolutions[selectedResolutionIndex],
            fullscreen = selectedFullscreenTypeIndex > 1,
            fullscreen_type = selectedFullscreenTypeIndex == 2 and "desktop" or "borderless",
            vsync = currentGraphicsSettings.vsync,
            max_fps = currentGraphicsSettings.max_fps,
            font_scale = currentGraphicsSettings.font_scale,
            helpers_enabled = currentGraphicsSettings.helpers_enabled,
            reticle_style = currentGraphicsSettings.reticle_style,
            reticle_color = currentGraphicsSettings.reticle_color
        }
        local newAudioSettings = {
            master_volume = currentAudioSettings.master_volume,
            music_volume = currentAudioSettings.music_volume,
            sfx_volume = currentAudioSettings.sfx_volume,
            ui_sounds_enabled = currentAudioSettings.ui_sounds_enabled ~= false,
            ui_sounds_volume = currentAudioSettings.ui_sounds_volume or 1.0
        }
        Settings.applySettings(newGraphicsSettings, newAudioSettings)
        Settings.saveSettings()
    end) then
        return true
    end

    -- Exit Button
    local exitButton = {_rect = {x = exitButtonX, y = buttonY, w = buttonW, h = buttonH}}
    if Theme.handleButtonClick(exitButton, x, y, function()
        SettingsPanel.toggle()
    end) then
        return true
    end

    -- Close Button
    if SettingsPanel._closeButton then
        local btn = SettingsPanel._closeButton
        local closeButton = {_rect = {x = btn.x, y = btn.y, w = btn.w, h = btn.h}}
        if Theme.handleButtonClick(closeButton, x, y, function()
            SettingsPanel.visible = false
        end) then
{{ ... }}
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
