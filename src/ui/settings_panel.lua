local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local Settings = require("src.core.settings")
local IconRenderer = require("src.content.icon_renderer")
local AuroraTitle = require("src.shaders.aurora_title")
local Notifications = require("src.ui.notifications")
local Window = require("src.ui.common.window")
local Dropdown = require("src.ui.common.dropdown")
local Strings = require("src.core.strings")
local Util = require("src.core.util")

local SettingsPanel = {}

SettingsPanel.visible = false
-- Aurora shader for title effect (initialized on first use)
SettingsPanel.auroraShader = nil

local currentGraphicsSettings
local currentAudioSettings
local originalGraphicsSettings
local originalAudioSettings
local keymap
local bindingAction
local draggingSlider = nil

local vsyncTypes = {Strings.getUI("off"), Strings.getUI("on")}
local fpsLimitTypes = {Strings.getUI("unlimited"), "30", "60", "120", "144", "240"}
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
    -- If window/content bounds are available, compute contentHeight relative
    -- to the current window so scrolling stays correct when the window is moved.
    local contentX, contentY, contentW, contentH
    if SettingsPanel.window then
        local cb = SettingsPanel.window:getContentBounds()
        contentX, contentY, contentW, contentH = cb.x, cb.y, cb.w, cb.h
    else
        contentX, contentY, contentW, contentH = Viewport.getDimensions(), 0, Viewport.getDimensions(), 0
    end

    local yOffset = contentY + 10 + 60 -- start padding + initial offset
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
        "toggle_inventory", "toggle_ship", "toggle_bounty", "toggle_skills",
        "toggle_map", "dock",
        "hotbar_1", "hotbar_2", "hotbar_3", "hotbar_4", "hotbar_5", "hotbar_6", "hotbar_7"
    }
    yOffset = yOffset + 30 * #keybindOrder -- Each keybinding takes 30 pixels

    -- Update scrollable content height based on last yOffset
    -- The content height should be the total height of all content within the scissor area
    contentHeight = (yOffset - contentY) + 20

    -- Allow content to be taller than panel height for scrolling
    -- The scrollbar will handle showing content that extends beyond the panel
end

local function cloneSettings(src)
    return Util.deepCopy(src or {})
end

local function settingsEqual(a, b)
    if a == b then return true end
    if type(a) ~= "table" or type(b) ~= "table" then
        return false
    end

    for k, v in pairs(a) do
        if not settingsEqual(v, b[k]) then
            return false
        end
    end

    for k in pairs(b) do
        if a[k] == nil then
            return false
        end
    end

    return true
end

local function refreshGraphicsDropdowns()
    if vsyncDropdown then
        vsyncDropdown:setSelectedIndex(currentGraphicsSettings and currentGraphicsSettings.vsync and 2 or 1)
    end
    if fpsLimitDropdown and currentGraphicsSettings then
        local fpsToIndex = {
            [0] = 1,
            [30] = 2,
            [60] = 3,
            [120] = 4,
            [144] = 5,
            [240] = 6
        }
        local idx = fpsToIndex[currentGraphicsSettings.max_fps or 60] or 3
        currentGraphicsSettings.max_fps_index = idx
        fpsLimitDropdown:setSelectedIndex(idx)
    end
    if accentThemeDropdown and currentGraphicsSettings then
        local accentThemes = {
            Strings.getTheme("cyan_lavender"),
            Strings.getTheme("blue_purple"),
            Strings.getTheme("green_emerald"),
            Strings.getTheme("red_orange"),
            Strings.getTheme("monochrome")
        }
        local themeIndex = 1
        for i, theme in ipairs(accentThemes) do
            if theme == (currentGraphicsSettings.accent_theme or Strings.getTheme("cyan_lavender")) then
                themeIndex = i
                break
            end
        end
        accentThemeDropdown:setSelectedIndex(themeIndex)
    end
end

function SettingsPanel.refreshFromSettings()
    currentGraphicsSettings = cloneSettings(Settings.getGraphicsSettings())
    currentAudioSettings = cloneSettings(Settings.getAudioSettings())
    refreshGraphicsDropdowns()
    keymap = cloneSettings(Settings.getKeymap() or {})
end

function SettingsPanel.init()
    SettingsPanel.window = Window.new({
        title = Strings.getUI("settings_title"),
        width = 800,
        height = 600,
        minWidth = 600,
        minHeight = 400,
        useLoadPanelTheme = true,
        draggable = true,
        resizable = false,
        drawContent = SettingsPanel.drawContent,
        onClose = function()
            SettingsPanel.visible = false
        end
    })

    SettingsPanel.refreshFromSettings()
    originalGraphicsSettings = cloneSettings(Settings.getGraphicsSettings())
    originalAudioSettings = cloneSettings(Settings.getAudioSettings())
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

    -- Debug logging removed for production cleanliness

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
        onSelect = function(index)
            currentGraphicsSettings.vsync = (index == 2)
        end
    })

    -- FPS Limit dropdown
    fpsLimitDropdown = Dropdown.new({
        x = valueX,
        y = 60 + itemHeight,
        options = fpsLimitTypes,
        selectedIndex = currentGraphicsSettings.max_fps_index or 3,
        onSelect = function(index)
            currentGraphicsSettings.max_fps_index = index
            local fpsMap = {
                [1] = 0,
                [2] = 30,
                [3] = 60,
                [4] = 120,
                [5] = 144,
                [6] = 240
            }
            currentGraphicsSettings.max_fps = fpsMap[index] or 60
        end
    })

    -- Accent Theme dropdown
    local accentThemes = {
        Strings.getTheme("cyan_lavender"),
        Strings.getTheme("blue_purple"),
        Strings.getTheme("green_emerald"),
        Strings.getTheme("red_orange"),
        Strings.getTheme("monochrome")
    }
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
            Notifications.add(Strings.getNotification("accent_color_changed") .. " " .. option, "info")
            accentThemeLastChanged = love.timer.getTime()
            refreshGraphicsDropdowns()
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
    local scrolledMouseY = my + scrollY

    love.graphics.push()
    -- Get the actual title bar height from the window
    local innerTop = y  -- Start below the title bar
    local innerH = h - 60   -- Leave room for title bar and bottom bar (60px)
    love.graphics.setScissor(x, innerTop, w, innerH)
    love.graphics.translate(0, -scrollY)

    -- Settings content with organized sections
    local pad = (Theme.ui and Theme.ui.contentPadding) or 20
    local yOffset = innerTop + 10  -- Start from the scissor area top with small padding
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
    local btnHover = mx >= btnX and mx <= btnX + btnW and scrolledMouseY >= btnY and scrolledMouseY <= btnY + btnH
    -- Show full text without truncation
    Theme.drawStyledButton(btnX, btnY, btnW, btnH, "Select Reticle", btnHover, love.timer.getTime())
    SettingsPanel._reticleButtonRect = { x = btnX, y = btnY - scrollY, w = btnW, h = btnH }
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
        "toggle_inventory", "toggle_ship", "toggle_bounty", "toggle_skills",
        "toggle_map", "dock",
        "hotbar_1", "hotbar_2", "hotbar_3", "hotbar_4", "hotbar_5", "hotbar_6", "hotbar_7"
    }
    
    for _, action in ipairs(keybindOrder) do
        local key = keymap[action]
        -- Debug: Always show the action name, even if key is missing
        Theme.setColor(Theme.colors.text)
        love.graphics.print(action, x + 20, yOffset)
        
        if key then
            -- Draw keybinding as a button
            local btnX, btnY, btnW, btnH = x + 200, yOffset - 2, 100, 24
            local keyText = bindingAction == action and Strings.getControl("press_key") or key
            local hover = mx >= btnX and mx <= btnX + btnW and scrolledMouseY >= btnY and scrolledMouseY <= btnY + btnH
            
            -- Use themed button drawing
            Theme.drawStyledButton(btnX, btnY, btnW, btnH, keyText, hover, love.timer.getTime(), nil, bindingAction == action)
        else
            -- Show "Not Set" if no key is configured
            Theme.setColor(Theme.colors.textDisabled)
            love.graphics.print("Not Set", x + 200, yOffset)
        end
        
        yOffset = yOffset + 30
    end

    -- Calculate content height
    SettingsPanel.calculateContentHeight()
    -- Debug logging removed for production cleanliness

    love.graphics.pop() -- End of scrollable content translation

    -- Disable scissor for UI elements below the scrollable area
    love.graphics.setScissor()

    -- Draw separation lines between sections
    Theme.setColor(Theme.colors.border)
    love.graphics.setLineWidth(1)
    
    -- Bottom separation line (between content and bottom bar)
    love.graphics.line(x, y + h - 60, x + w, y + h - 60)

    -- Set scissor to full panel bounds for dropdowns and apply button
    love.graphics.setScissor(x, y, w, h)

    -- Scrollbar (inside scissor, but not translated)
    local scrollbarWidth = 12
    local scrollbarX = x + w - scrollbarWidth - 4  -- 4px margin from right edge
    local scrollbarY = innerTop
    local scrollbarH = innerH
    if contentHeight > innerH then
        local thumbH = math.max(20, scrollbarH * (innerH / contentHeight))
        local trackRange = scrollbarH - thumbH
        local thumbY = scrollbarY + (trackRange > 0 and (trackRange * (scrollY / (contentHeight - innerH))) or 0)

        -- Draw scrollbar track (background) - solid black with border
        Theme.setColor(Theme.colors.bg0)
        love.graphics.rectangle("fill", scrollbarX, scrollbarY, scrollbarWidth, scrollbarH)
        Theme.setColor(Theme.colors.border)
        love.graphics.rectangle("line", scrollbarX, scrollbarY, scrollbarWidth, scrollbarH)
        
        -- Draw scrollbar thumb (handle) - accent color with border
        Theme.setColor(Theme.colors.accent)
        love.graphics.rectangle("fill", scrollbarX + 1, thumbY + 1, scrollbarWidth - 2, thumbH - 2)
        Theme.setColor(Theme.colors.border)
        love.graphics.rectangle("line", scrollbarX + 1, thumbY + 1, scrollbarWidth - 2, thumbH - 2)

        -- Store scrollbar bounds for mouse interaction (convert to screen coordinates)
        local windowX, windowY = 0, 0
        if SettingsPanel.window then
            windowX, windowY = SettingsPanel.window.x, SettingsPanel.window.y
        end
        SettingsPanel._scrollbarTrack = { x = scrollbarX + windowX, y = scrollbarY + windowY, w = scrollbarWidth, h = scrollbarH }
        SettingsPanel._scrollbarThumb = { x = scrollbarX + windowX, y = thumbY + windowY, w = scrollbarWidth, h = thumbH }
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

    -- Apply and Reset buttons
    local buttonW, buttonH = 100, 30
    local buttonSpacing = 20
    local totalButtonWidth = buttonW * 2 + buttonSpacing
    local applyButtonX = x + (w / 2) - totalButtonWidth / 2
    local resetButtonX = applyButtonX + buttonW + buttonSpacing
    local buttonAreaY = y + h - 60
    local buttonY = buttonAreaY + 15
    local applyBtnHover = mx >= applyButtonX and mx <= applyButtonX + buttonW and my >= buttonY and my <= buttonY + buttonH
    local resetBtnHover = mx >= resetButtonX and mx <= resetButtonX + buttonW and my >= buttonY and my <= buttonY + buttonH

    -- Draw Apply button using themed button renderer and store its rect
    local applyText = Strings.getUI("apply_button")
    Theme.drawStyledButton(applyButtonX, buttonY, buttonW, buttonH, applyText, applyBtnHover, love.timer.getTime())
    SettingsPanel._applyButton = { _rect = { x = applyButtonX, y = buttonY, w = buttonW, h = buttonH } }

    -- Draw Reset button
    local resetText = "Reset"
    Theme.drawStyledButton(resetButtonX, buttonY, buttonW, buttonH, resetText, resetBtnHover, love.timer.getTime())
    SettingsPanel._resetButton = { _rect = { x = resetButtonX, y = buttonY, w = buttonW, h = buttonH } }

    -- Reticle Gallery Popup
    if reticleGalleryOpen then
        local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
        local gw, gh = 560, 420
        local gx, gy = (sw - gw) / 2, (sh - gh) / 2
        Theme.drawGradientGlowRect(gx, gy, gw, gh, 6, Theme.colors.bg1, Theme.colors.bg0, Theme.colors.accent, Theme.effects.glowWeak)
        Theme.drawEVEBorder(gx, gy, gw, gh, 6, Theme.colors.border, 8)
        Theme.setColor(Theme.colors.textHighlight)
        love.graphics.print(Strings.getUI("choose_reticle"), gx + 16, gy + 12)
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
    Theme.drawStyledButton(doneX, doneY, doneW, doneH, Strings.getUI("done_button"), hover, love.timer.getTime())
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
    local innerTop = contentY or panelY  -- Fallback to panelY if contentY is nil
    local innerH = (contentH or h) - 60
    local valueX = contentX + 150
    local dropdownW = 150
    local itemHeight = 40
    -- Also have screen coords for popups drawn in screen space
    local screenX, screenY = Viewport.toScreen(x, y)

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
    
    -- Handle apply and reset buttons (use content bounds like drawContent does)
    local buttonW, buttonH = 100, 30
    local buttonSpacing = 20
    local totalButtonWidth = buttonW * 2 + buttonSpacing
    local applyButtonX = contentX + (contentW / 2) - totalButtonWidth / 2
    local resetButtonX = applyButtonX + buttonW + buttonSpacing
    local buttonAreaY = contentY + contentH - 60
    local buttonY = buttonAreaY + 15
    
    -- Apply button
    if x >= applyButtonX and x <= applyButtonX + buttonW and y >= buttonY and y <= buttonY + buttonH then
        local newGraphicsSettings = {}
        for k, v in pairs(currentGraphicsSettings) do newGraphicsSettings[k] = v end
        local newAudioSettings = {}
        for k, v in pairs(currentAudioSettings) do newAudioSettings[k] = v end
        Settings.applySettings(newGraphicsSettings, newAudioSettings)
        Settings.save()
        Notifications.add(Strings.getNotification("settings_applied"), "success")
        originalGraphicsSettings = cloneSettings(Settings.getGraphicsSettings())
        originalAudioSettings = cloneSettings(Settings.getAudioSettings())
        return true
    end
    
    -- Reset button
    if x >= resetButtonX and x <= resetButtonX + buttonW and y >= buttonY and y <= buttonY + buttonH then
        SettingsPanel.resetToDefaults()
        return true
    end

    -- Handle reticle gallery pop-up interactions (popup is drawn in screen coords)
    if reticleGalleryOpen then
        if SettingsPanel._reticleDone and screenX >= SettingsPanel._reticleDone._rect.x and screenX <= SettingsPanel._reticleDone._rect.x + SettingsPanel._reticleDone._rect.w and
           screenY >= SettingsPanel._reticleDone._rect.y and screenY <= SettingsPanel._reticleDone._rect.y + SettingsPanel._reticleDone._rect.h then
            reticleGalleryOpen = false
            return true
        end
        if SettingsPanel._reticlePopup and screenX >= SettingsPanel._reticlePopup.x and screenY >= SettingsPanel._reticlePopup.y then
            local col = math.floor((screenX - SettingsPanel._reticlePopup.x) / (SettingsPanel._reticlePopup.cell + SettingsPanel._reticlePopup.gap))
            local row = math.floor((screenY - SettingsPanel._reticlePopup.y) / (SettingsPanel._reticlePopup.cell + SettingsPanel._reticlePopup.gap))
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
                if screenX >= slider.x and screenX <= slider.x + slider.w and screenY >= slider.y - 10 and screenY <= slider.y + slider.h + 10 then
                    draggingSlider = 'reticle_color_' .. slider.key
                    return true
                end
            end
        end
        -- If in reticle popup, consume the click so it doesn't affect underlying UI
        local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
        local gw, gh = 560, 420
        local gx, gy = (sw - gw) / 2, (sh - gh) / 2
        if screenX >= gx and screenX <= gx + gw and screenY >= gy and screenY <= gy + gh then
            return true
        end
    end

    -- Handle scrollbar clicking and dragging
    if contentHeight > innerH then
        local scrollbarWidth = 12
        local scrollbarX = panelX + w - scrollbarWidth - 4
        local scrollbarY = contentY -- Use contentY, which is the true top of the content area
        local scrollbarH = innerH
        local thumbH = math.max(20, scrollbarH * (innerH / contentHeight))
        local trackRange = scrollbarH - thumbH
        local thumbY = scrollbarY + (trackRange > 0 and (trackRange * (scrollY / (contentHeight - innerH))) or 0)

        if x >= scrollbarX and x <= scrollbarX + scrollbarWidth then
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

    -- Now handle main content (scrolled): check if click is in the visible content area
    if x < contentX or x > contentX + contentW or y < contentY or y > contentY + contentH then
        return false -- Not in the scrollable content area
    end

    -- Correctly calculate mouse Y position in the virtual, scrolled content space
    -- Mouse `y` is in virtual screen space; elements are drawn translated by -scrollY,
    -- so compare mouseY + scrollY against absolute element Y positions.
    local scrolledY = y + scrollY
    local sectionSpacing = 60

    -- Replicate the yOffset logic from drawContent EXACTLY for perfect alignment
    local yOffset = contentY + 10 -- Start relative to the content area's top + padding

    -- === GRAPHICS SECTION ===
    yOffset = yOffset + 30 -- "Graphics Settings" label

    -- VSync Dropdown
    -- Dropdown handles its own mousepress, so we just increment yOffset
    yOffset = yOffset + itemHeight

    -- Max FPS Dropdown
    -- Dropdown handles its own mousepress
    yOffset = yOffset + itemHeight

    -- Reticle button
    local btnX, btnW, btnH = valueX, 140, 26
    local btnY = yOffset - 4
    if scrolledY >= btnY and scrolledY <= btnY + btnH and x >= btnX and x <= btnX + btnW then
        reticleGalleryOpen = true
        return true
    end
    yOffset = yOffset + itemHeight

    -- Accent Color Theme Dropdown
    -- Dropdown handles its own mousepress
    yOffset = yOffset + itemHeight


    -- === AUDIO SECTION ===
    yOffset = yOffset + 30 -- "Audio Settings" label

    -- Master Volume
    local sliderX, sliderW, sliderH = valueX, 200, 10
    local sliderY = yOffset - 5
    if scrolledY >= sliderY and scrolledY <= sliderY + sliderH and x >= sliderX and x <= sliderX + sliderW then
        draggingSlider = "master_volume"
        local pct = (x - sliderX) / sliderW -- Set initial value on click
        currentAudioSettings.master_volume = math.max(0, math.min(1, pct))
        return true
    end
    yOffset = yOffset + itemHeight
    -- SFX Volume
    sliderY = yOffset - 5
    if scrolledY >= sliderY and scrolledY <= sliderY + sliderH and x >= sliderX and x <= sliderX + sliderW then
        draggingSlider = "sfx_volume"
        local pct = (x - sliderX) / sliderW -- Set initial value on click
        currentAudioSettings.sfx_volume = math.max(0, math.min(1, pct))
        return true
    end
    yOffset = yOffset + itemHeight
    -- Music Volume
    sliderY = yOffset - 5
    if scrolledY >= sliderY and scrolledY <= sliderY + sliderH and x >= sliderX and x <= sliderX + sliderW then
        draggingSlider = "music_volume"
        local pct = (x - sliderX) / sliderW -- Set initial value on click
        currentAudioSettings.music_volume = math.max(0, math.min(1, pct))
        return true
    end
    yOffset = yOffset + itemHeight + sectionSpacing

    -- === CONTROLS SECTION ===
    yOffset = yOffset + 30 -- "Controls" label
    yOffset = yOffset + 30 -- "Keybindings" label

    local keybindOrder = { "toggle_inventory", "toggle_ship", "toggle_bounty", "toggle_skills", "toggle_map", "dock", "hotbar_1", "hotbar_2", "hotbar_3", "hotbar_4", "hotbar_5", "hotbar_6", "hotbar_7" }
    for _, action in ipairs(keybindOrder) do
        local btnX, btnW, btnH = contentX + 200, 100, 24
        local btnY = yOffset - 2
        if scrolledY >= btnY and scrolledY <= btnY + btnH and x >= btnX and x <= btnX + btnW then
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
        -- Dropdowns handle their own hover detection, no changes needed here
        vsyncDropdown:mousemoved(x, y)
        fpsLimitDropdown:mousemoved(x, y)
        accentThemeDropdown:mousemoved(x, y)

        -- Check slider hovers (scrolled content)
        -- Use the exact same logic as mousepressed to find the elements
        if x >= contentX and x <= contentX + contentW and y >= contentY and y <= contentY + innerH then
            -- Mouse `y` is virtual; elements are drawn translated by -scrollY.
            -- So compare mouseY + scrollY against absolute element Y positions.
            local scrolledY = y + scrollY
            local sectionSpacing = 60
            local yOffset = contentY + 10 -- Start relative to the content area's top + padding

            -- === GRAPHICS SECTION ===
            yOffset = yOffset + 30 -- "Graphics Settings" label
            yOffset = yOffset + itemHeight -- VSync
            yOffset = yOffset + itemHeight -- Max FPS
            yOffset = yOffset + itemHeight -- Reticle
            yOffset = yOffset + itemHeight -- Accent Color
            yOffset = yOffset + itemHeight + sectionSpacing -- Helpers + spacing

            -- === AUDIO SECTION ===
            yOffset = yOffset + 30 -- "Audio Settings" label

            -- Master Volume
            local sliderY = yOffset - 5
            if scrolledY >= sliderY and scrolledY <= sliderY + 10 and x >= valueX and x <= valueX + 200 then
                hoveredSlider.master_volume = true
            end
            yOffset = yOffset + itemHeight
            -- SFX Volume
            sliderY = yOffset - 5
            if scrolledY >= sliderY and scrolledY <= sliderY + 10 and x >= valueX and x <= valueX + 200 then
                hoveredSlider.sfx_volume = true
            end
            yOffset = yOffset + itemHeight
            -- Music Volume
            sliderY = yOffset - 5
            if scrolledY >= sliderY and scrolledY <= sliderY + 10 and x >= valueX and x <= valueX + 200 then
                hoveredSlider.music_volume = true
            end
        end
    end

    if not draggingSlider then return false end

    -- Handle slider dragging
    if draggingSlider == "scrollbar" then
        if contentHeight > innerH and innerTop then
            local scrollbarWidth = 12
            local scrollbarX = panelX + w - scrollbarWidth - 4
            local scrollbarY = innerTop
            local scrollbarH = innerH
            local thumbH = math.max(20, scrollbarH * (innerH / contentHeight))
            local trackRange = scrollbarH - thumbH

            if trackRange > 0 and scrollbarY then
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
    local wasVisible = SettingsPanel.window and SettingsPanel.window.visible
    if not SettingsPanel.window then
        SettingsPanel.init()
    end

    SettingsPanel.window:toggle()
    SettingsPanel.visible = SettingsPanel.window.visible

    if SettingsPanel.visible then
        SettingsPanel.refreshFromSettings()
        originalGraphicsSettings = cloneSettings(Settings.getGraphicsSettings())
        originalAudioSettings = cloneSettings(Settings.getAudioSettings())
    else
        local graphicsSettings = Settings.getGraphicsSettings()
        local audioSettings = Settings.getAudioSettings()

        if originalGraphicsSettings and not settingsEqual(graphicsSettings, originalGraphicsSettings) then
            Settings.applyGraphicsSettings(cloneSettings(originalGraphicsSettings))
        end

        if originalAudioSettings and not settingsEqual(audioSettings, originalAudioSettings) then
            Settings.applyAudioSettings(cloneSettings(originalAudioSettings))
        end
    end
end

function SettingsPanel.isBinding()
    return bindingAction ~= nil
end

function SettingsPanel.resetToDefaults()
    -- Delete the settings.json file to force a complete reset
    local filename = "settings.json"
    if love.filesystem.getInfo(filename) then
        local success = love.filesystem.remove(filename)
        if not success then
            Log.error("SettingsPanel.resetToDefaults - Failed to delete settings file")
            Notifications.add("Failed to reset settings", "error")
            return
        end
    end
    
    -- Reset to default settings
    local defaultGraphics = Settings.getDefaultGraphicsSettings()
    local defaultAudio = Settings.getDefaultAudioSettings()
    local defaultKeymap = Settings.getDefaultKeymap()
    
    -- Update current settings
    currentGraphicsSettings = cloneSettings(defaultGraphics)
    currentAudioSettings = cloneSettings(defaultAudio)
    keymap = cloneSettings(defaultKeymap)
    
    -- Apply the default settings immediately
    Settings.applySettings(defaultGraphics, defaultAudio)
    
    -- Reset keymap to defaults
    for action, binding in pairs(defaultKeymap) do
        if type(binding) == "table" then
            Settings.setKeyBinding(action, binding.primary, "primary")
        else
            Settings.setKeyBinding(action, binding, "primary")
        end
    end
    
    -- Save the reset settings
    Settings.save()
    
    -- Update dropdowns to reflect default values
    SettingsPanel.refreshFromSettings()
    
    -- Update resolution dropdown
    selectedResolutionIndex = 1
    for i, res in ipairs(resolutions) do
        if res.width == currentGraphicsSettings.resolution.width and res.height == currentGraphicsSettings.resolution.height then
            selectedResolutionIndex = i
            break
        end
    end
    
    -- Update fullscreen dropdown
    if currentGraphicsSettings.fullscreen then
        selectedFullscreenTypeIndex = 2
    else
        selectedFullscreenTypeIndex = 1
    end
    
    -- Update accent theme
    applyAccentTheme(currentGraphicsSettings.accent_theme or "Cyan/Lavender")
    
    -- Show notification
    Notifications.add("Settings reset to defaults (saves preserved)", "success")
end



-- Apply accent theme immediately for preview
function applyAccentTheme(themeName)
    local Theme = require("src.core.theme")

    if themeName == "Cyan/Lavender" then
        -- Single cyan theme
        Theme.colors.accent = {0.2, 0.8, 0.9, 1.00}          -- Electric cyan (single)
        Theme.colors.accentGold = {0.2, 0.8, 0.9, 1.00}      -- Same as accent
        Theme.colors.accentTeal = {0.2, 0.8, 0.9, 1.00}      -- Same as accent
        Theme.colors.accentPink = {0.2, 0.8, 0.9, 1.00}      -- Same as accent
        Theme.colors.border = {0.5, 0.7, 0.9, 0.8}           -- Unified cyan border
        Theme.colors.borderBright = {0.5, 0.7, 0.9, 0.8}     -- Same as border
        Theme.colors.bg0 = {0.00, 0.00, 0.00, 1.00}          -- Pure black
        Theme.colors.bg1 = {0.00, 0.00, 0.00, 1.00}          -- Pure black
        Theme.colors.windowBg = {0.00, 0.00, 0.00, 1.00}     -- Pure black

    elseif themeName == "Blue/Purple" then
        -- Single blue theme
        Theme.colors.accent = {0.4, 0.6, 1.0, 1.00}          -- Electric blue (single)
        Theme.colors.accentGold = {0.4, 0.6, 1.0, 1.00}      -- Same as accent
        Theme.colors.accentTeal = {0.4, 0.6, 1.0, 1.00}      -- Same as accent
        Theme.colors.accentPink = {0.4, 0.6, 1.0, 1.00}      -- Same as accent
        Theme.colors.border = {0.4, 0.6, 1.0, 0.8}           -- Unified blue border
        Theme.colors.borderBright = {0.4, 0.6, 1.0, 0.8}     -- Same as border
        Theme.colors.bg0 = {0.00, 0.00, 0.00, 1.00}          -- Pure black
        Theme.colors.bg1 = {0.00, 0.00, 0.00, 1.00}          -- Pure black
        Theme.colors.windowBg = {0.00, 0.00, 0.00, 1.00}     -- Pure black

    elseif themeName == "Green/Emerald" then
        -- Single green theme
        Theme.colors.accent = {0.3, 0.9, 0.4, 1.00}          -- Emerald green (single)
        Theme.colors.accentGold = {0.3, 0.9, 0.4, 1.00}      -- Same as accent
        Theme.colors.accentTeal = {0.3, 0.9, 0.4, 1.00}      -- Same as accent
        Theme.colors.accentPink = {0.3, 0.9, 0.4, 1.00}      -- Same as accent
        Theme.colors.border = {0.3, 0.9, 0.4, 0.8}           -- Unified green border
        Theme.colors.borderBright = {0.3, 0.9, 0.4, 0.8}     -- Same as border
        Theme.colors.bg0 = {0.00, 0.00, 0.00, 1.00}          -- Pure black
        Theme.colors.bg1 = {0.00, 0.00, 0.00, 1.00}          -- Pure black
        Theme.colors.windowBg = {0.00, 0.00, 0.00, 1.00}     -- Pure black

    elseif themeName == "Red/Orange" then
        -- Single red theme
        Theme.colors.accent = {0.9, 0.3, 0.2, 1.00}          -- Crimson red (single)
        Theme.colors.accentGold = {0.9, 0.3, 0.2, 1.00}      -- Same as accent
        Theme.colors.accentTeal = {0.9, 0.3, 0.2, 1.00}      -- Same as accent
        Theme.colors.accentPink = {0.9, 0.3, 0.2, 1.00}      -- Same as accent
        Theme.colors.border = {0.9, 0.3, 0.2, 0.8}           -- Unified red border
        Theme.colors.borderBright = {0.9, 0.3, 0.2, 0.8}     -- Same as border
        Theme.colors.bg0 = {0.00, 0.00, 0.00, 1.00}          -- Pure black
        Theme.colors.bg1 = {0.00, 0.00, 0.00, 1.00}          -- Pure black
        Theme.colors.windowBg = {0.00, 0.00, 0.00, 1.00}     -- Pure black

    elseif themeName == "Monochrome" then
        -- Single gray theme
        Theme.colors.accent = {0.7, 0.7, 0.7, 1.00}          -- Medium gray (single)
        Theme.colors.accentGold = {0.7, 0.7, 0.7, 1.00}      -- Same as accent
        Theme.colors.accentTeal = {0.7, 0.7, 0.7, 1.00}      -- Same as accent
        Theme.colors.accentPink = {0.7, 0.7, 0.7, 1.00}      -- Same as accent
        Theme.colors.border = {0.7, 0.7, 0.7, 0.8}           -- Unified gray border
        Theme.colors.borderBright = {0.7, 0.7, 0.7, 0.8}     -- Same as border
        Theme.colors.bg0 = {0.00, 0.00, 0.00, 1.00}          -- Pure black
        Theme.colors.bg1 = {0.00, 0.00, 0.00, 1.00}          -- Pure black
        Theme.colors.windowBg = {0.00, 0.00, 0.00, 1.00}     -- Pure black
    end

    -- Update turret slot colors to match the new single-color theme
    if themeName == "Cyan/Lavender" then
        Theme.turretSlotColors = {
            {0.2, 0.8, 0.9, 1.00},    -- Electric cyan
            {0.2, 0.8, 0.9, 1.00},    -- Electric cyan
            {0.2, 0.8, 0.9, 1.00},    -- Electric cyan
            {0.2, 0.8, 0.9, 1.00},    -- Electric cyan
        }
    elseif themeName == "Blue/Purple" then
        Theme.turretSlotColors = {
            {0.4, 0.6, 1.0, 1.00},    -- Electric blue
            {0.4, 0.6, 1.0, 1.00},    -- Electric blue
            {0.4, 0.6, 1.0, 1.00},    -- Electric blue
            {0.4, 0.6, 1.0, 1.00},    -- Electric blue
        }
    elseif themeName == "Green/Emerald" then
        Theme.turretSlotColors = {
            {0.3, 0.9, 0.4, 1.00},    -- Emerald green
            {0.3, 0.9, 0.4, 1.00},    -- Emerald green
            {0.3, 0.9, 0.4, 1.00},    -- Emerald green
            {0.3, 0.9, 0.4, 1.00},    -- Emerald green
        }
    elseif themeName == "Red/Orange" then
        Theme.turretSlotColors = {
            {0.9, 0.3, 0.2, 1.00},    -- Crimson red
            {0.9, 0.3, 0.2, 1.00},    -- Crimson red
            {0.9, 0.3, 0.2, 1.00},    -- Crimson red
            {0.9, 0.3, 0.2, 1.00},    -- Crimson red
        }
    elseif themeName == "Monochrome" then
        Theme.turretSlotColors = {
            {0.7, 0.7, 0.7, 1.00},    -- Medium gray
            {0.7, 0.7, 0.7, 1.00},    -- Medium gray
            {0.7, 0.7, 0.7, 1.00},    -- Medium gray
            {0.7, 0.7, 0.7, 1.00},    -- Medium gray
        }
    end
end

return SettingsPanel
