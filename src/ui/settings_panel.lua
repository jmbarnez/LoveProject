local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local Settings = require("src.core.settings")
local IconRenderer = require("src.content.icon_renderer")
local AuroraTitle = require("src.shaders.aurora_title")
local Notifications = require("src.ui.notifications")
local Window = require("src.ui.common.window")
local Dropdown = require("src.ui.common.dropdown")

local SettingsPanel = {}

SettingsPanel.visible = false
-- Aurora shader for title effect (initialized on first use)
SettingsPanel.auroraShader = nil

local currentGraphicsSettings
local currentAudioSettings
local keymap
local bindingAction
local draggingSlider = nil

local vsyncTypes = {"Off", "On"}
local fpsLimitTypes = {"Unlimited", "30", "60", "120", "144", "240"}
-- Reticle color picker state (always visible sliders in popup)
local colorPickerOpen = true
local reticleGalleryOpen = false
local scrollY = 0
local scrollDragOffset = 0
local contentHeight = 0 -- Will be calculated dynamically

-- Track when accent theme was last changed for visual feedback
local accentThemeLastChanged = 0
local accentThemeChangeDuration = 0.5 -- Duration of highlight effect in seconds

-- Standardized dropdown components
local vsyncDropdown
local fpsLimitDropdown
local accentThemeDropdown

-- Slider hover tracking
local hoveredSlider = {
    master_volume = false,
    sfx_volume = false,
    music_volume = false
}

-- Helper function to truncate text with ellipsis if it doesn't fit
local function truncateText(text, maxWidth, font)
    local textWidth = font:getWidth(text)
    if textWidth <= maxWidth then
        return text
    end

    local ellipsis = "..."
    local ellipsisWidth = font:getWidth(ellipsis)

    if ellipsisWidth >= maxWidth then
        return ""
    end

    local truncated = text
    while font:getWidth(truncated .. ellipsis) > maxWidth and #truncated > 0 do
        truncated = truncated:sub(1, -2)
    end

    return truncated .. ellipsis
end

function SettingsPanel.calculateContentHeight()
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()

    -- Check if we're in fullscreen mode
    local windowMode = love.window.getMode()
    local isFullscreen = false
    if type(windowMode) == "table" and windowMode.fullscreen then
        isFullscreen = true
    elseif type(windowMode) == "boolean" then
        isFullscreen = windowMode
    elseif type(windowMode) == "number" then
        -- Handle case where getMode returns a number (some LÖVE versions)
        isFullscreen = (windowMode == 1)
    end

    -- Responsive panel sizing based on screen resolution and window mode
    local panelWidth, panelHeight
    if isFullscreen then
        -- In fullscreen mode, use more generous sizing for better usability
        if sw <= 800 or sh <= 600 then
            -- For small fullscreen (800x600 or smaller), use 90% to leave some margin
            panelWidth = math.floor(sw * 0.9)
            panelHeight = math.floor(sh * 0.9)
        elseif sw <= 1024 or sh <= 768 then
            -- For medium fullscreen, use 85%
            panelWidth = math.floor(sw * 0.85)
            panelHeight = math.floor(sh * 0.85)
        else
            -- For large fullscreen, use 80%
            panelWidth = math.floor(sw * 0.8)
            panelHeight = math.floor(sh * 0.8)
        end
    else
        -- In windowed mode, use the previous responsive logic
        if sw <= 800 or sh <= 600 then
            -- For small windows (800x600 or smaller), use more conservative sizing
            panelWidth = math.floor(sw * 0.95)  -- Use 95% of width
            panelHeight = math.floor(sh * 0.95) -- Use 95% of height
        elseif sw <= 1024 or sh <= 768 then
            -- For medium windows (1024x768 or smaller), use 90% sizing
            panelWidth = math.floor(sw * 0.9)
            panelHeight = math.floor(sh * 0.9)
        else
            -- For larger windows, use 80% sizing
            panelWidth = math.floor(sw * 0.8)
            panelHeight = math.floor(sh * 0.8)
        end
    end

    -- Ensure minimum panel size (larger minimum for fullscreen)
    if isFullscreen then
        panelWidth = math.max(panelWidth, 700)
        panelHeight = math.max(panelHeight, 500)
    else
        panelWidth = math.max(panelWidth, 600)
        panelHeight = math.max(panelHeight, 400)
    end

    -- Ensure panel doesn't exceed screen bounds
    panelWidth = math.min(panelWidth, sw - 20)
    panelHeight = math.min(panelHeight, sh - 20)

    local x = math.floor((sw - panelWidth) / 2)
    local y = math.floor((sh - panelHeight) / 2)
    local w, h = panelWidth, panelHeight
    local innerTop = y + 40
    local innerH = h - 80

-- Calculate yOffset based on all the UI elements
local yOffset = y + 60
local itemHeight = 40

-- Graphics settings (vsync, max fps)
yOffset = yOffset + itemHeight * 2

-- UI Scale slider
yOffset = yOffset + itemHeight

-- Font Scale slider
yOffset = yOffset + itemHeight

-- Reticle button
yOffset = yOffset + itemHeight

-- Accent Color Theme
yOffset = yOffset + itemHeight

-- Helpers toggle
yOffset = yOffset + itemHeight

-- Audio settings section
yOffset = yOffset + itemHeight + 30 -- "Audio" label + spacing
yOffset = yOffset + itemHeight * 3 -- 3 volume sliders

-- Keybindings section
yOffset = yOffset + itemHeight + 30 -- "Keybindings" label + spacing
local keybindOrder = {
    "toggle_inventory", "toggle_bounty", "toggle_skills",
    "toggle_map", "dock",
    "hotbar_1", "hotbar_2", "hotbar_3", "hotbar_4", "hotbar_5"
}
yOffset = yOffset + 30 * #keybindOrder -- Each keybinding takes 30 pixels

-- Update scrollable content height based on last yOffset
contentHeight = (yOffset - innerTop) + 20

-- Allow content to be taller than panel height for scrolling
-- The scrollbar will handle showing content that extends beyond the panel
end

function SettingsPanel.init()
    SettingsPanel.window = Window.new({
        title = "Settings",
        width = 800,
        height = 600,
        minWidth = 600,
        minHeight = 400,
        draggable = true,
        resizable = true,
        drawContent = SettingsPanel.drawContent,
        onClose = function()
            SettingsPanel.visible = false
        end
    })

    currentGraphicsSettings = Settings.getGraphicsSettings()
    currentAudioSettings = Settings.getAudioSettings()
    -- Ensure helpers_enabled exists with default value
    if currentGraphicsSettings.helpers_enabled == nil then
        currentGraphicsSettings.helpers_enabled = true
    end
    if not currentGraphicsSettings.reticle_style then
        currentGraphicsSettings.reticle_style = 1
    end
    keymap = Settings.getKeymap()

    -- Load resolutions early
    resolutions = Settings.getAvailableResolutions()
    -- Find the index of the current resolution
    selectedResolutionIndex = 1 -- Default
    for i, res in ipairs(resolutions) do
        if res.width == currentGraphicsSettings.resolution.width and res.height == currentGraphicsSettings.resolution.height then
            selectedResolutionIndex = i
            break
        end
    end

    -- Find the index of the current fullscreen type
    if currentGraphicsSettings.fullscreen then
        selectedFullscreenTypeIndex = 2 -- fullscreen
    else
        selectedFullscreenTypeIndex = 1 -- windowed
    end

    -- Debug: Print current fullscreen settings
    print("SettingsPanel.init - Current fullscreen settings:")
    print("  fullscreen: " .. tostring(currentGraphicsSettings.fullscreen))
    print("  fullscreen_type: " .. (currentGraphicsSettings.fullscreen_type or "nil"))
    print("  borderless: " .. tostring(currentGraphicsSettings.borderless))
    print("  selectedFullscreenTypeIndex: " .. selectedFullscreenTypeIndex)
    print("  Available resolutions count: " .. (#resolutions or 0))

    -- Apply the current accent theme
    applyAccentTheme(currentGraphicsSettings.accent_theme or "Cyan/Lavender")

    -- Initialize standardized dropdown components
    local valueX = 150
    local itemHeight = 40

    -- VSync dropdown
    vsyncDropdown = Dropdown.new({
        x = valueX,
        y = 60,
        options = vsyncTypes,
        selectedIndex = currentGraphicsSettings.vsync and 2 or 1,
        onSelect = function(index, option)
            currentGraphicsSettings.vsync = (index == 2)
        end
    })

    -- FPS Limit dropdown
    fpsLimitDropdown = Dropdown.new({
        x = valueX,
        y = 60 + itemHeight,
        options = fpsLimitTypes,
        selectedIndex = 1,
        onSelect = function(index, option)
            currentGraphicsSettings.max_fps = (option == "Unlimited") and 0 or tonumber(option)
        end
    })

    -- Accent Theme dropdown
    local accentThemes = {"Cyan/Lavender", "Blue/Purple", "Green/Emerald", "Red/Orange", "Monochrome"}
    local themeIndex = 1
    for i, theme in ipairs(accentThemes) do
        if theme == (currentGraphicsSettings.accent_theme or "Cyan/Lavender") then
            themeIndex = i
            break
        end
    end

    accentThemeDropdown = Dropdown.new({
        x = valueX,
        y = 60 + itemHeight * 2,
        options = accentThemes,
        selectedIndex = themeIndex,
        onSelect = function(index, option)
            currentGraphicsSettings.accent_theme = option
            applyAccentTheme(option)
            Notifications.add("Accent color changed to " .. option, "info")
            accentThemeLastChanged = love.timer.getTime()
        end
    })
end

function SettingsPanel.update(dt)
    if not SettingsPanel.window.visible then return end
    -- Update logic for the settings panel
end

function SettingsPanel.draw()
    if not SettingsPanel.window.visible then return end

    SettingsPanel.window:draw()
end

function SettingsPanel.drawContent(window, x, y, w, h)
    -- Set a consistent font for the entire settings panel
    local settingsFont = Theme.fonts and (Theme.fonts.small or Theme.fonts.normal) or love.graphics.getFont()
    love.graphics.setFont(settingsFont)

    local mx, my = Viewport.getMousePosition()

    love.graphics.push()
    local innerTop = y
    local innerH = h - 60  -- Leave room for bottom bar with Apply button
    love.graphics.setScissor(x, innerTop, w, innerH)
    love.graphics.translate(0, -scrollY)

    -- Settings content with organized sections
    local pad = (Theme.ui and Theme.ui.contentPadding) or 20
    local yOffset = y + 60
    local labelX = x + pad
    local valueX = x + 150
    local dropdownW = 150
    local itemHeight = 40
    local sectionSpacing = 60  -- Space between sections

    -- === GRAPHICS SECTION ===
    Theme.setColor(Theme.colors.accent)
    love.graphics.setFont(Theme.fonts and (Theme.fonts.normal or Theme.fonts.small) or love.graphics.getFont())
    love.graphics.print("Graphics Settings", labelX, yOffset)
    love.graphics.setFont(settingsFont)
    yOffset = yOffset + 30

    -- VSync
    Theme.setColor(Theme.colors.text)
    love.graphics.print("VSync:", labelX, yOffset)
    vsyncDropdown:setPosition(valueX, yOffset - 2 - scrollY)
    yOffset = yOffset + itemHeight

    -- Max FPS
    Theme.setColor(Theme.colors.text)
    love.graphics.print("Max FPS:", labelX, yOffset)
    fpsLimitDropdown:setPosition(valueX, yOffset - 2 - scrollY)
    yOffset = yOffset + itemHeight


    -- Reticle popup trigger, current preview, and color dropdown
    Theme.setColor(Theme.colors.text)
    love.graphics.print("Reticle:", labelX, yOffset)
    local btnX, btnY, btnW, btnH = valueX, yOffset - 4, 140, 26
    local mx, my = Viewport.getMousePosition()
    local btnHover = mx >= btnX and mx <= btnX + btnW and my + scrollY >= btnY and my + scrollY <= btnY + btnH
    -- Show full text without truncation
    Theme.drawStyledButton(btnX, btnY, btnW, btnH, "Select Reticle", btnHover, love.timer.getTime())
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

    -- Accent Color Theme
    Theme.setColor(Theme.colors.text)
    love.graphics.print("Accent Color:", labelX, yOffset)
    accentThemeDropdown:setPosition(valueX, yOffset - 2 - scrollY)
    yOffset = yOffset + itemHeight

    -- Helpers toggle
    Theme.setColor(Theme.colors.text)
    love.graphics.print("Show Helpers:", labelX, yOffset)
    local toggleX, toggleY, toggleW, toggleH = valueX, yOffset - 2, 70, 24
    local enabled = currentGraphicsSettings.helpers_enabled ~= false
    local toggleHover = mx >= toggleX and mx <= toggleX + toggleW and my + scrollY >= toggleY and my + scrollY <= toggleY + toggleH
    Theme.drawStyledButton(toggleX, toggleY, toggleW, toggleH, enabled and "On" or "Off", toggleHover, love.timer.getTime())
    yOffset = yOffset + itemHeight + sectionSpacing

    -- === AUDIO SECTION ===
    Theme.setColor(Theme.colors.accent)
    love.graphics.setFont(Theme.fonts and (Theme.fonts.normal or Theme.fonts.small) or love.graphics.getFont())
    love.graphics.print("Audio Settings", labelX, yOffset)
    love.graphics.setFont(settingsFont)
    yOffset = yOffset + 30

    -- Master Volume
    Theme.setColor(Theme.colors.text)
    love.graphics.print("Master Volume:", labelX, yOffset)
    local masterVolumeText = string.format("%.2f", currentAudioSettings.master_volume)
    love.graphics.print(masterVolumeText, x + 400, yOffset)
    local masterSliderX = valueX
    local masterSliderW = 200
    local masterHandleX = masterSliderX + (masterSliderW - 10) * currentAudioSettings.master_volume

    -- Draw slider track with hover effect
    local masterSliderTrackColor = hoveredSlider.master_volume and Theme.colors.textHighlight or Theme.colors.bg3
    local masterSliderTrackGlow = hoveredSlider.master_volume and Theme.effects.glowWeak * 0.3 or Theme.effects.glowWeak * 0.1
    Theme.drawGradientGlowRect(masterSliderX, yOffset - 5, masterSliderW, 10, 2, masterSliderTrackColor, Theme.colors.bg2, Theme.colors.border, masterSliderTrackGlow)

    -- Draw slider handle with hover effect
    local masterHandleColor = hoveredSlider.master_volume and Theme.colors.accentGold or Theme.colors.accent
    local masterHandleGlow = hoveredSlider.master_volume and Theme.effects.glowWeak * 0.4 or Theme.effects.glowWeak * 0.2
    Theme.drawGradientGlowRect(masterHandleX, yOffset - 7.5, 10, 15, 2, masterHandleColor, Theme.colors.bg3, Theme.colors.border, masterHandleGlow)
    yOffset = yOffset + itemHeight

    -- SFX Volume
    Theme.setColor(Theme.colors.text)
    love.graphics.print("SFX Volume:", labelX, yOffset)
    local sfxVolumeText = string.format("%.2f", currentAudioSettings.sfx_volume)
    love.graphics.print(sfxVolumeText, x + 400, yOffset)
    local sfxSliderX = valueX
    local sfxSliderW = 200
    local sfxHandleX = sfxSliderX + (sfxSliderW - 10) * currentAudioSettings.sfx_volume

    -- Draw slider track with hover effect
    local sfxSliderTrackColor = hoveredSlider.sfx_volume and Theme.colors.textHighlight or Theme.colors.bg3
    local sfxSliderTrackGlow = hoveredSlider.sfx_volume and Theme.effects.glowWeak * 0.3 or Theme.effects.glowWeak * 0.1
    Theme.drawGradientGlowRect(sfxSliderX, yOffset - 5, sfxSliderW, 10, 2, sfxSliderTrackColor, Theme.colors.bg2, Theme.colors.border, sfxSliderTrackGlow)

    -- Draw slider handle with hover effect
    local sfxHandleColor = hoveredSlider.sfx_volume and Theme.colors.accentGold or Theme.colors.accent
    local sfxHandleGlow = hoveredSlider.sfx_volume and Theme.effects.glowWeak * 0.4 or Theme.effects.glowWeak * 0.2
    Theme.drawGradientGlowRect(sfxHandleX, yOffset - 7.5, 10, 15, 2, sfxHandleColor, Theme.colors.bg3, Theme.colors.border, sfxHandleGlow)
    yOffset = yOffset + itemHeight

    -- Music Volume
    Theme.setColor(Theme.colors.text)
    love.graphics.print("Music Volume:", labelX, yOffset)
    local musicVolumeText = string.format("%.2f", currentAudioSettings.music_volume)
    love.graphics.print(musicVolumeText, x + 400, yOffset)
    local musicSliderX = valueX
    local musicSliderW = 200
    local musicHandleX = musicSliderX + (musicSliderW - 10) * currentAudioSettings.music_volume

    -- Draw slider track with hover effect
    local musicSliderTrackColor = hoveredSlider.music_volume and Theme.colors.textHighlight or Theme.colors.bg3
    local musicSliderTrackGlow = hoveredSlider.music_volume and Theme.effects.glowWeak * 0.3 or Theme.effects.glowWeak * 0.1
    Theme.drawGradientGlowRect(musicSliderX, yOffset - 5, musicSliderW, 10, 2, musicSliderTrackColor, Theme.colors.bg2, Theme.colors.border, musicSliderTrackGlow)

    -- Draw slider handle with hover effect
    local musicHandleColor = hoveredSlider.music_volume and Theme.colors.accentGold or Theme.colors.accent
    local musicHandleGlow = hoveredSlider.music_volume and Theme.effects.glowWeak * 0.4 or Theme.effects.glowWeak * 0.2
    Theme.drawGradientGlowRect(musicHandleX, yOffset - 7.5, 10, 15, 2, musicHandleColor, Theme.colors.bg3, Theme.colors.border, musicHandleGlow)
    yOffset = yOffset + itemHeight + sectionSpacing

    -- === CONTROLS SECTION ===
    Theme.setColor(Theme.colors.accent)
    love.graphics.setFont(Theme.fonts and (Theme.fonts.normal or Theme.fonts.small) or love.graphics.getFont())
    love.graphics.print("Controls", x + 20, yOffset)
    love.graphics.setFont(settingsFont)
    yOffset = yOffset + 30

    -- Keybindings
    Theme.setColor(Theme.colors.text)
    love.graphics.print("Keybindings", labelX, yOffset)
    love.graphics.print("(Click to change)", labelX + 130, yOffset + 2)
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
            local textW = settingsFont:getWidth(keyText)
            love.graphics.print(keyText, btnX + (btnW - textW) / 2, btnY + (btnH - settingsFont:getHeight()) / 2)
            
            yOffset = yOffset + 30
        end
    end

    -- Calculate content height
    SettingsPanel.calculateContentHeight()
    print("Content height: " .. (contentHeight or 0) .. ", innerH: " .. innerH .. ", should show scrollbar: " .. tostring(contentHeight > innerH))

    love.graphics.pop() -- End of scrollable content translation

    -- Scrollbar (inside scissor, but not translated)
    local scrollbarX = x + w - 12
    local scrollbarY = innerTop
    local scrollbarH = innerH
    if contentHeight > innerH then
        local thumbH = math.max(20, scrollbarH * (innerH / contentHeight))
        local trackRange = scrollbarH - thumbH
        local thumbY = scrollbarY + (trackRange > 0 and (trackRange * (scrollY / (contentHeight - innerH))) or 0)

        -- Draw scrollbar track (background)
        Theme.drawGradientGlowRect(scrollbarX, scrollbarY, 8, scrollbarH, 2, Theme.colors.bg0, Theme.colors.bg1, Theme.colors.border, Theme.effects.glowWeak * 0.1)
        -- Draw scrollbar thumb (handle)
        Theme.drawGradientGlowRect(scrollbarX, thumbY, 8, thumbH, 2, Theme.colors.accent, Theme.colors.bg3, Theme.colors.border, Theme.effects.glowWeak * 0.2)

        -- Store scrollbar bounds for mouse interaction (convert to screen coordinates)
        local windowX, windowY = 0, 0
        if SettingsPanel.window then
            windowX, windowY = SettingsPanel.window.x, SettingsPanel.window.y
        end
        SettingsPanel._scrollbarTrack = { x = scrollbarX + windowX, y = scrollbarY + windowY, w = 8, h = scrollbarH }
        SettingsPanel._scrollbarThumb = { x = scrollbarX + windowX, y = thumbY + windowY, w = 8, h = thumbH }
    else
        SettingsPanel._scrollbarTrack = nil
        SettingsPanel._scrollbarThumb = nil
    end

    -- Draw dropdowns within the normal scissor context (they now respect clipping)
    -- First draw all dropdown buttons (for proper z-ordering)
    vsyncDropdown:drawButtonOnly(mx, my)
    fpsLimitDropdown:drawButtonOnly(mx, my)
    accentThemeDropdown:drawButtonOnly(mx, my)

    -- Then draw options for any open dropdowns (on top)
    vsyncDropdown:drawOptionsOnly(mx, my)
    fpsLimitDropdown:drawOptionsOnly(mx, my)
    accentThemeDropdown:drawOptionsOnly(mx, my)

    -- Apply button (green)
    local buttonW, buttonH = 100, 30
    local applyButtonX = x + (w / 2) - buttonW / 2
    local buttonAreaY = y + h - 60
    local buttonY = buttonAreaY + 15
    local applyBtnHover = mx >= applyButtonX and mx <= applyButtonX + buttonW and my >= buttonY and my <= buttonY + buttonH

    -- Draw green Apply button
    Theme.setColor(Theme.colors.success)  -- Green color
    love.graphics.rectangle("fill", applyButtonX, buttonY, buttonW, buttonH)
    Theme.setColor(Theme.colors.success[1] * 0.8, Theme.colors.success[2] * 0.8, Theme.colors.success[3] * 0.8, 1)  -- Darker green for border
    love.graphics.rectangle("line", applyButtonX, buttonY, buttonW, buttonH)

    -- Button text
    Theme.setColor(Theme.colors.textHighlight)
    local font = Theme.fonts and (Theme.fonts.small or Theme.fonts.normal) or love.graphics.getFont()
    local textW = font:getWidth("Apply")
    local textH = font:getHeight()
    love.graphics.print("Apply", applyButtonX + (buttonW - textW) / 2, buttonY + (buttonH - textH) / 2)

    -- Reticle Gallery Popup
    if reticleGalleryOpen then
        local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
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

function SettingsPanel.mousepressed(raw_x, raw_y, button)
    if not SettingsPanel.window.visible then return false end

    if SettingsPanel.window:mousepressed(raw_x, raw_y, button) then
        return true
    end

    -- Use raw screen coordinates for all checks
    local x, y = raw_x, raw_y

    -- Get geometry from the window object
    local win = SettingsPanel.window
    local panelX, panelY, w, h = win.x, win.y, win.width, win.height
    local content = win:getContentBounds()
    local contentX, contentY, contentW, contentH = content.x, content.y, content.w, content.h
    local innerTop = contentY
    local innerH = contentH - 60
    local valueX = contentX + 150
    local dropdownW = 150
    local itemHeight = 40

    -- Check if click is outside the panel
    local isInsidePanel = x >= panelX and x <= panelX + w and y >= panelY and y <= panelY + h
    if not isInsidePanel then
        -- Close dropdowns if clicking outside (handled by dropdown components)
        return false
    end

    -- Calculate button positions for dropdown alignment (same as in draw function)
    local yOffsetUnscrolled = panelY + 60
    local vsyncButtonY = yOffsetUnscrolled
    local fpsButtonY = vsyncButtonY + itemHeight
    local accentButtonY = fpsButtonY + itemHeight * 2  -- Skip UI scale and font scale sliders

    -- Handle dropdown clicks using standardized components
    if vsyncDropdown:mousepressed(x, y, button) then return true end
    if fpsLimitDropdown:mousepressed(x, y, button) then return true end
    if accentThemeDropdown:mousepressed(x, y, button) then return true end
    
    -- Handle apply button
    local buttonW, buttonH = 100, 30
    local applyButtonX = panelX + (w / 2) - buttonW / 2
    local buttonAreaY = panelY + h - 60
    local buttonY = buttonAreaY + 15
    if x >= applyButtonX and x <= applyButtonX + buttonW and y >= buttonY and y <= buttonY + buttonH then
        local newGraphicsSettings = {}
        for k, v in pairs(currentGraphicsSettings) do newGraphicsSettings[k] = v end
        local newAudioSettings = {}
        for k, v in pairs(currentAudioSettings) do newAudioSettings[k] = v end
        Settings.applySettings(newGraphicsSettings, newAudioSettings)
        Settings.save()
        Notifications.add("Settings applied successfully!", "success")
        return true
    end

    -- Handle reticle gallery pop-up interactions
    if reticleGalleryOpen then
        if SettingsPanel._reticleDone and x >= SettingsPanel._reticleDone._rect.x and x <= SettingsPanel._reticleDone._rect.x + SettingsPanel._reticleDone._rect.w and
           y >= SettingsPanel._reticleDone._rect.y and y <= SettingsPanel._reticleDone._rect.y + SettingsPanel._reticleDone._rect.h then
            reticleGalleryOpen = false
            return true
        end
        if SettingsPanel._reticlePopup and x >= SettingsPanel._reticlePopup.x and y >= SettingsPanel._reticlePopup.y then
            local col = math.floor((x - SettingsPanel._reticlePopup.x) / (SettingsPanel._reticlePopup.cell + SettingsPanel._reticlePopup.gap))
            local row = math.floor((y - SettingsPanel._reticlePopup.y) / (SettingsPanel._reticlePopup.cell + SettingsPanel._reticlePopup.gap))
            if col >= 0 and col < SettingsPanel._reticlePopup.cols and row >= 0 and row < SettingsPanel._reticlePopup.rows then
                local index = row * SettingsPanel._reticlePopup.cols + col + 1
                if index >= 1 and index <= 50 then
                    currentGraphicsSettings.reticle_style = index
                    return true
                end
            end
        end
        if SettingsPanel._colorSliders then
            for _, slider in ipairs(SettingsPanel._colorSliders) do
                if x >= slider.x and x <= slider.x + slider.w and y >= slider.y - 10 and y <= slider.y + slider.h + 10 then
                    draggingSlider = 'reticle_color_' .. slider.key
                    return true
                end
            end
        end
        -- If in reticle popup, consume the click so it doesn't affect underlying UI
        local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
        local gw, gh = 560, 420
        local gx, gy = (sw - gw) / 2, (sh - gh) / 2
        if x >= gx and x <= gx + gw and y >= gy and y <= gy + gh then
            return true
        end
    end

    -- Handle scrollbar clicking and dragging
    if contentHeight > innerH then
        local scrollbarX = panelX + w - 12
        local scrollbarY = innerTop
        local scrollbarH = innerH
        local thumbH = math.max(20, scrollbarH * (innerH / contentHeight))
        local trackRange = scrollbarH - thumbH
        local thumbY = scrollbarY + (trackRange > 0 and (trackRange * (scrollY / (contentHeight - innerH))) or 0)

        if x >= scrollbarX and x <= scrollbarX + 8 then
            if y >= thumbY and y <= thumbY + thumbH then
                draggingSlider = "scrollbar"
                scrollDragOffset = y - thumbY
                return true
            elseif y >= scrollbarY and y <= scrollbarY + scrollbarH then
                local clickY = y - scrollbarY
                local frac = trackRange > 0 and (clickY / trackRange) or 0
                local maxScroll = math.max(0, contentHeight - innerH)
                scrollY = math.max(0, math.min(maxScroll, frac * maxScroll))
                return true
            end
        end
    end

    -- Now handle main content (scrolled): check if click is in content area
    if x < contentX or x > contentX + contentW or y < contentY or y > contentY + contentH - 60 then
        return false -- Not in the scrollable content area
    end

    local scrolledY = y - contentY + scrollY
    local sectionSpacing = 60

    -- yOffset is now relative to the top of the content pane
    local yOffset = 60 -- start of content
    yOffset = yOffset + 30 -- "Graphics Settings" label

    -- VSync dropdown
    if vsyncDropdown:mousepressed(x, y, button) then return true end
    yOffset = yOffset + itemHeight

    -- Max FPS dropdown
    if fpsLimitDropdown:mousepressed(x, y, button) then return true end
    yOffset = yOffset + itemHeight

    -- Reticle button
    if scrolledY >= yOffset - 4 and scrolledY <= yOffset + 22 and x >= valueX and x <= valueX + 140 then
        reticleGalleryOpen = true
        return true
    end
    yOffset = yOffset + itemHeight

    -- Accent Color Theme dropdown
    if accentThemeDropdown:mousepressed(x, y, button) then return true end
    yOffset = yOffset + itemHeight

    -- Helpers toggle
    if scrolledY >= yOffset - 2 and scrolledY <= yOffset + 22 and x >= valueX and x <= valueX + 70 then
        currentGraphicsSettings.helpers_enabled = not currentGraphicsSettings.helpers_enabled
        return true
    end
    yOffset = yOffset + itemHeight + sectionSpacing

    -- === AUDIO SECTION ===
    yOffset = yOffset + 30 -- "Audio Settings" label

    -- Master Volume
    if scrolledY >= yOffset - 5 and scrolledY <= yOffset + 5 and x >= valueX and x <= valueX + 200 then
        draggingSlider = "master_volume"
        return true
    end
    yOffset = yOffset + itemHeight
    -- SFX Volume
    if scrolledY >= yOffset - 5 and scrolledY <= yOffset + 5 and x >= valueX and x <= valueX + 200 then
        draggingSlider = "sfx_volume"
        return true
    end
    yOffset = yOffset + itemHeight
    -- Music Volume
    if scrolledY >= yOffset - 5 and scrolledY <= yOffset + 5 and x >= valueX and x <= valueX + 200 then
        draggingSlider = "music_volume"
        return true
    end
    yOffset = yOffset + itemHeight + sectionSpacing

    -- === CONTROLS SECTION ===
    yOffset = yOffset + 30 -- "Controls" label
    yOffset = yOffset + 30 -- "Keybindings" label

    local keybindOrder = { "toggle_inventory", "toggle_bounty", "toggle_skills", "toggle_map", "dock", "hotbar_1", "hotbar_2", "hotbar_3", "hotbar_4", "hotbar_5" }
    for _, action in ipairs(keybindOrder) do
        if scrolledY >= yOffset - 2 and scrolledY <= yOffset + 22 and x >= contentX + 200 and x <= contentX + 300 then
            bindingAction = action
            return true
        end
        yOffset = yOffset + 30
    end

    return true -- Consume click inside panel
end

function SettingsPanel.mousereleased(x, y, button)
    if not SettingsPanel.window.visible then return false end

    if SettingsPanel.window:mousereleased(x, y, button) then
        return true
    end

    draggingSlider = nil
    return false
end

function SettingsPanel.wheelmoved(x, y, dx, dy)
    if not SettingsPanel.window.visible then return false end

    local win = SettingsPanel.window
    if not win:containsPoint(x, y) then return false end

    local content = win:getContentBounds()
    local innerH = content.h - 60 -- Consistent with drawContent

    SettingsPanel.calculateContentHeight()
    local maxScroll = math.max(0, contentHeight - innerH)

    if maxScroll > 0 then
        scrollY = scrollY - dy * 30
        scrollY = math.max(0, math.min(scrollY, maxScroll))
        return true
    end

    return false
end

function SettingsPanel.mousemoved(raw_x, raw_y, dx, dy)
    if not SettingsPanel.window.visible then return false end

    -- Handle window dragging first
    if SettingsPanel.window:mousemoved(raw_x, raw_y, dx, dy) then
        return true
    end

    local x, y = raw_x, raw_y
    local win = SettingsPanel.window
    local panelX, panelY, w, h = win.x, win.y, win.width, win.height
    local content = win:getContentBounds()
    local contentX, contentY, contentW, contentH = content.x, content.y, content.w, content.h
    local innerH = contentH - 60
    local valueX = contentX + 150
    local itemHeight = 40

    -- Reset hover states
    for k in pairs(hoveredSlider) do hoveredSlider[k] = false end

    local isInsidePanel = x >= panelX and x <= panelX + w and y >= panelY and y <= panelY + h

    if isInsidePanel then
        -- Check dropdown hovers
        local yOffsetUnscrolled = panelY + 60
        local vsyncButtonY = yOffsetUnscrolled
        local fpsButtonY = vsyncButtonY + itemHeight
        local accentButtonY = fpsButtonY + itemHeight * 2
        
        -- Standardized dropdown components handle their own hover detection
        vsyncDropdown:mousemoved(x, y)
        fpsLimitDropdown:mousemoved(x, y)
        accentThemeDropdown:mousemoved(x, y)

        -- Check slider hovers (scrolled content)
        if x >= contentX and x <= contentX + contentW and y >= contentY and y <= contentY + innerH then
            local scrolledY = y - contentY + scrollY
            local yOffset = 60 + 30
            yOffset = yOffset + itemHeight * 4 + 60 -- Graphics section
            yOffset = yOffset + 30 -- Audio label

            if scrolledY >= yOffset - 5 and scrolledY <= yOffset + 5 and x >= valueX and x <= valueX + 200 then
                hoveredSlider.master_volume = true
            end
            yOffset = yOffset + itemHeight
            if scrolledY >= yOffset - 5 and scrolledY <= yOffset + 5 and x >= valueX and x <= valueX + 200 then
                hoveredSlider.sfx_volume = true
            end
            yOffset = yOffset + itemHeight
            if scrolledY >= yOffset - 5 and scrolledY <= yOffset + 5 and x >= valueX and x <= valueX + 200 then
                hoveredSlider.music_volume = true
            end
        end
    end

    if not draggingSlider then return false end

    -- Handle slider dragging
    if draggingSlider == "scrollbar" then
        if contentHeight > innerH then
            local scrollbarY = content.y -- Use content bounds
            local scrollbarH = innerH
            local thumbH = math.max(20, scrollbarH * (innerH / contentHeight))
            local trackRange = scrollbarH - thumbH

            if trackRange > 0 then
                local newThumbY = y - scrollDragOffset
                local frac = (newThumbY - scrollbarY) / trackRange
                local maxScroll = math.max(0, contentHeight - innerH)
                scrollY = math.max(0, math.min(maxScroll, frac * maxScroll))
            end
        end
    elseif draggingSlider == "master_volume" or draggingSlider == "sfx_volume" or draggingSlider == "music_volume" then
        local sliderW = 200
        local pct = (x - valueX) / sliderW
        currentAudioSettings[draggingSlider] = math.max(0, math.min(1, pct))
    elseif draggingSlider:find("reticle_color_") then
        if SettingsPanel._colorSliders then
            local r, g, b, a = unpack(currentGraphicsSettings.reticle_color_rgb or {1,1,1,1})
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
        return true
    end
    
    return true
end

function SettingsPanel.keypressed(key)
    if not SettingsPanel.window.visible then return false end

    if bindingAction then
        Settings.setKeyBinding(bindingAction, key)
        keymap = Settings.getKeymap()
        bindingAction = nil
        return true
    end



    return false
end

function SettingsPanel.toggle()
    -- Initialize settings if not already done
    if not currentGraphicsSettings then
        SettingsPanel.init()
    end

    SettingsPanel.window:toggle()
    SettingsPanel.visible = SettingsPanel.window.visible
end

function SettingsPanel.isBinding()
    return bindingAction ~= nil
end



-- Apply accent theme immediately for preview
function applyAccentTheme(themeName)
    local Theme = require("src.core.theme")

    if themeName == "Cyan/Lavender" then
        -- Current cyan/lavender theme
        Theme.colors.accent = {0.2, 0.8, 0.9, 1.00}          -- Electric cyan (main)
        Theme.colors.accentGold = {0.6, 0.4, 0.9, 1.00}      -- Ethereal lavender (secondary)
        Theme.colors.accentTeal = {0.3, 0.9, 1.0, 1.00}      -- Bright cyan (highlights)
        Theme.colors.accentPink = {0.7, 0.5, 0.9, 1.00}      -- Deep lavender (accents)
        Theme.colors.border = {0.6, 0.4, 0.9, 0.7}           -- Lavender border
        Theme.colors.borderBright = {0.5, 0.7, 0.9, 1.00}    -- Bright cyan border

    elseif themeName == "Blue/Purple" then
        -- Blue/purple theme
        Theme.colors.accent = {0.4, 0.6, 1.0, 1.00}          -- Electric blue (main)
        Theme.colors.accentGold = {0.9, 0.7, 1.0, 1.00}      -- Purple-tinted gold (secondary)
        Theme.colors.accentTeal = {0.3, 0.7, 0.9, 1.00}      -- Deep blue (highlights)
        Theme.colors.accentPink = {0.8, 0.4, 0.9, 1.00}      -- Royal purple (accents)
        Theme.colors.border = {0.8, 0.4, 0.9, 0.7}           -- Purple border
        Theme.colors.borderBright = {0.4, 0.6, 1.0, 1.00}    -- Bright blue border

    elseif themeName == "Green/Emerald" then
        -- Green/emerald theme
        Theme.colors.accent = {0.3, 0.9, 0.4, 1.00}          -- Emerald green (main)
        Theme.colors.accentGold = {0.2, 0.8, 0.3, 1.00}      -- Bright green (secondary)
        Theme.colors.accentTeal = {0.1, 0.7, 0.4, 1.00}      -- Forest green (highlights)
        Theme.colors.accentPink = {0.4, 0.8, 0.2, 1.00}      -- Lime green (accents)
        Theme.colors.border = {0.4, 0.8, 0.2, 0.7}           -- Green border
        Theme.colors.borderBright = {0.3, 0.9, 0.4, 1.00}    -- Bright green border

    elseif themeName == "Red/Orange" then
        -- Red/orange theme
        Theme.colors.accent = {0.9, 0.3, 0.2, 1.00}          -- Crimson red (main)
        Theme.colors.accentGold = {1.0, 0.5, 0.1, 1.00}      -- Bright orange (secondary)
        Theme.colors.accentTeal = {0.8, 0.2, 0.1, 1.00}      -- Dark red (highlights)
        Theme.colors.accentPink = {0.9, 0.4, 0.3, 1.00}      -- Coral red (accents)
        Theme.colors.border = {0.9, 0.4, 0.3, 0.7}           -- Red border
        Theme.colors.borderBright = {0.9, 0.3, 0.2, 1.00}    -- Bright red border

    elseif themeName == "Monochrome" then
        -- Monochrome theme (grayscale)
        Theme.colors.accent = {0.7, 0.7, 0.7, 1.00}          -- Medium gray (main)
        Theme.colors.accentGold = {0.5, 0.5, 0.5, 1.00}      -- Dark gray (secondary)
        Theme.colors.accentTeal = {0.6, 0.6, 0.6, 1.00}      -- Light gray (highlights)
        Theme.colors.accentPink = {0.4, 0.4, 0.4, 1.00}      -- Very dark gray (accents)
        Theme.colors.border = {0.5, 0.5, 0.5, 0.7}           -- Gray border
        Theme.colors.borderBright = {0.7, 0.7, 0.7, 1.00}    -- Light gray border
    end

    -- Update turret slot colors to match the new theme
    if themeName == "Cyan/Lavender" then
        Theme.turretSlotColors = {
            {0.2, 0.8, 0.9, 1.00},    -- Electric cyan
            {0.3, 0.9, 1.0, 1.00},    -- Bright cyan
            {0.6, 0.4, 0.9, 1.00},    -- Ethereal lavender
            {0.7, 0.5, 0.9, 1.00},    -- Deep lavender
        }
    elseif themeName == "Blue/Purple" then
        Theme.turretSlotColors = {
            {0.4, 0.6, 1.0, 1.00},    -- Electric blue
            {0.3, 0.7, 0.9, 1.00},    -- Deep blue
            {0.8, 0.4, 0.9, 1.00},    -- Royal purple
            {0.9, 0.7, 1.0, 1.00},    -- Purple-tinted gold
        }
    elseif themeName == "Green/Emerald" then
        Theme.turretSlotColors = {
            {0.3, 0.9, 0.4, 1.00},    -- Emerald green
            {0.2, 0.8, 0.3, 1.00},    -- Bright green
            {0.1, 0.7, 0.4, 1.00},    -- Forest green
            {0.4, 0.8, 0.2, 1.00},    -- Lime green
        }
    elseif themeName == "Red/Orange" then
        Theme.turretSlotColors = {
            {0.9, 0.3, 0.2, 1.00},    -- Crimson red
            {1.0, 0.5, 0.1, 1.00},    -- Bright orange
            {0.8, 0.2, 0.1, 1.00},    -- Dark red
            {0.9, 0.4, 0.3, 1.00},    -- Coral red
        }
    elseif themeName == "Monochrome" then
        Theme.turretSlotColors = {
            {0.7, 0.7, 0.7, 1.00},    -- Medium gray
            {0.6, 0.6, 0.6, 1.00},    -- Light gray
            {0.5, 0.5, 0.5, 1.00},    -- Dark gray
            {0.4, 0.4, 0.4, 1.00},    -- Very dark gray
        }
    end
end

return SettingsPanel
