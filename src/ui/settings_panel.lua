local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local Settings = require("src.core.settings")
local Notifications = require("src.ui.notifications")
local Window = require("src.ui.common.window")
local Strings = require("src.core.strings")
local Util = require("src.core.util")
local Log = require("src.core.log")

local GraphicsPanel = require("src.ui.settings.graphics_panel")
local AudioPanel = require("src.ui.settings.audio_panel")
local ControlsPanel = require("src.ui.settings.controls_panel")

local SettingsPanel = {}

SettingsPanel.visible = false
SettingsPanel.auroraShader = nil

local currentGraphicsSettings = {}
local currentAudioSettings = {}
local originalGraphicsSettings
local originalAudioSettings
local keymap = {}

local scrollY = 0
local scrollDragOffset = 0
local contentHeight = 0

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

local function updateModuleData()
    GraphicsPanel.setSettings(currentGraphicsSettings)
    AudioPanel.setSettings(currentAudioSettings)
    ControlsPanel.setKeymap(keymap, function(newMap)
        keymap = newMap
    end)
    GraphicsPanel.refreshDropdowns()
end

function SettingsPanel.refreshFromSettings()
    currentGraphicsSettings = cloneSettings(Settings.getGraphicsSettings())
    currentAudioSettings = cloneSettings(Settings.getAudioSettings())
    keymap = cloneSettings(Settings.getKeymap())
    updateModuleData()
end

function SettingsPanel.calculateContentHeight()
    if not SettingsPanel.window then
        contentHeight = 0
        return
    end

    local content = SettingsPanel.window:getContentBounds()
    local baseY = content.y + 10
    local itemHeight = 40
    local sectionSpacing = 60

    local graphicsEnd = GraphicsPanel.getContentHeight(baseY, itemHeight)
    local audioBase = graphicsEnd + sectionSpacing
    local audioEnd = AudioPanel.getContentHeight(audioBase)
    local controlsBase = audioEnd + sectionSpacing
    local controlsEnd = ControlsPanel.getContentHeight(controlsBase)

    contentHeight = (controlsEnd - content.y) + 20
end

function SettingsPanel.init()
    SettingsPanel.window = Window.new({
        title = Strings.getUI("settings_title"),
        width = 800,
        height = 600,
        minWidth = 600,
        minHeight = 400,
        useLoadPanelTheme = true,
        bottomBarHeight = 60,
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
end

function SettingsPanel.update(dt)
    if not SettingsPanel.visible then return end
end

function SettingsPanel.draw()
    if not SettingsPanel.visible then return end
    SettingsPanel.window:draw()
end

local function drawSections(window, x, y, w, h)
    local settingsFont = Theme.fonts and (Theme.fonts.small or Theme.fonts.normal) or love.graphics.getFont()
    love.graphics.setFont(settingsFont)

    local mx, my = Viewport.getMousePosition()
    local scrolledMouseY = my + scrollY

    local content = window:getContentBounds()
    local innerTop = content.y
    local innerH = content.h

    love.graphics.push()
    love.graphics.setScissor(content.x, innerTop, content.w, innerH)
    love.graphics.translate(0, -scrollY)

    local pad = (Theme.ui and Theme.ui.contentPadding) or 20
    local yOffset = innerTop + 10
    local layout = {
        x = x,
        y = y,
        w = w,
        h = h,
        labelX = x + pad,
        valueX = x + 150,
        itemHeight = 40,
        scrollY = scrollY,
        settingsFont = settingsFont,
        mx = mx,
        my = my,
        scrolledMouseY = scrolledMouseY,
        yOffset = yOffset
    }

    layout.yOffset = GraphicsPanel.draw(layout)
    layout.yOffset = layout.yOffset + 60
    layout.yOffset = AudioPanel.draw(layout)
    layout.yOffset = layout.yOffset + 60
    ControlsPanel.draw(layout)

    love.graphics.pop()
    love.graphics.setScissor()

    SettingsPanel.calculateContentHeight()

    return content, mx, my
end

local function drawScrollbar(content, x, y, w, h)
    local innerTop = content.y
    local innerH = content.h

    local scrollbarWidth = 12
    local scrollbarX = x + w - scrollbarWidth - 4
    local scrollbarY = innerTop
    local scrollbarH = innerH
    if contentHeight > innerH then
        local thumbH = math.max(20, scrollbarH * (innerH / contentHeight))
        local trackRange = scrollbarH - thumbH
        local thumbY = scrollbarY + (trackRange > 0 and (trackRange * (scrollY / (contentHeight - innerH))) or 0)

        Theme.setColor(Theme.colors.bg0)
        love.graphics.rectangle("fill", scrollbarX, scrollbarY, scrollbarWidth, scrollbarH)
        Theme.setColor(Theme.colors.border)
        love.graphics.rectangle("line", scrollbarX, scrollbarY, scrollbarWidth, scrollbarH)

        Theme.setColor(Theme.colors.accent)
        love.graphics.rectangle("fill", scrollbarX + 1, thumbY + 1, scrollbarWidth - 2, thumbH - 2)
        Theme.setColor(Theme.colors.border)
        love.graphics.rectangle("line", scrollbarX + 1, thumbY + 1, scrollbarWidth - 2, thumbH - 2)

        SettingsPanel._scrollbarTrack = { x = scrollbarX, y = scrollbarY, w = scrollbarWidth, h = scrollbarH }
        SettingsPanel._scrollbarThumb = { x = scrollbarX, y = thumbY, w = scrollbarWidth, h = thumbH }
    else
        SettingsPanel._scrollbarTrack = nil
        SettingsPanel._scrollbarThumb = nil
    end
end

function SettingsPanel.drawContent(window, x, y, w, h)
    local content, mx, my = drawSections(window, x, y, w, h)

    local settingsFont = Theme.fonts and (Theme.fonts.small or Theme.fonts.normal) or love.graphics.getFont()
    love.graphics.setFont(settingsFont)

    drawScrollbar(content, x, y, w, h)

    love.graphics.setScissor(x, y, w, h)
    if GraphicsPanel.drawForeground then
        GraphicsPanel.drawForeground(mx, my)
    end
    love.graphics.setScissor()

    if GraphicsPanel.drawOverlays then
        GraphicsPanel.drawOverlays()
    end

    local buttonW, buttonH = 100, 30
    local buttonSpacing = 20
    local totalButtonWidth = buttonW * 2 + buttonSpacing
    local applyButtonX = content.x + (content.w / 2) - totalButtonWidth / 2
    local resetButtonX = applyButtonX + buttonW + buttonSpacing
    local buttonY = content.y + content.h + 15
    local applyHover = mx >= applyButtonX and mx <= applyButtonX + buttonW and my >= buttonY and my <= buttonY + buttonH
    local resetHover = mx >= resetButtonX and mx <= resetButtonX + buttonW and my >= buttonY and my <= buttonY + buttonH

    Theme.drawStyledButton(applyButtonX, buttonY, buttonW, buttonH, Strings.getUI("apply_button"), applyHover, love.timer.getTime(), {0.2, 0.8, 0.2, 1.0})
    SettingsPanel._applyButton = { _rect = { x = applyButtonX, y = buttonY, w = buttonW, h = buttonH } }

    Theme.drawStyledButton(resetButtonX, buttonY, buttonW, buttonH, "Reset", resetHover, love.timer.getTime(), {0.8, 0.2, 0.2, 1.0})
    SettingsPanel._resetButton = { _rect = { x = resetButtonX, y = buttonY, w = buttonW, h = buttonH } }
end

local function applySettings()
    local newGraphicsSettings = cloneSettings(currentGraphicsSettings)
    local newAudioSettings = cloneSettings(currentAudioSettings)
    Settings.applySettings(newGraphicsSettings, newAudioSettings)
    Settings.save()
    Notifications.add(Strings.getNotification("settings_applied"), "success")
    originalGraphicsSettings = cloneSettings(Settings.getGraphicsSettings())
    originalAudioSettings = cloneSettings(Settings.getAudioSettings())
end

function SettingsPanel.mousepressed(raw_x, raw_y, button)
    if not SettingsPanel.window.visible then return false end

    if SettingsPanel.window:mousepressed(raw_x, raw_y, button) then
        return true
    end

    if GraphicsPanel.mousepressed(raw_x, raw_y, button) then return true end
    if AudioPanel.mousepressed(raw_x, raw_y, button) then return true end
    if ControlsPanel.mousepressed(raw_x, raw_y, button) then return true end

    local win = SettingsPanel.window
    local panelX, panelY, w, h = win.x, win.y, win.width, win.height
    local content = win:getContentBounds()
    local contentX, contentY, contentW, contentH = content.x, content.y, content.w, content.h
    local innerH = contentH

    if raw_x < panelX or raw_x > panelX + w or raw_y < panelY or raw_y > panelY + h then
        return false
    end

    if SettingsPanel._applyButton and raw_x >= SettingsPanel._applyButton._rect.x and raw_x <= SettingsPanel._applyButton._rect.x + SettingsPanel._applyButton._rect.w and raw_y >= SettingsPanel._applyButton._rect.y and raw_y <= SettingsPanel._applyButton._rect.y + SettingsPanel._applyButton._rect.h then
        local Sound = require("src.core.sound")
        Sound.playSFX("button_click")
        applySettings()
        return true
    end

    if SettingsPanel._resetButton and raw_x >= SettingsPanel._resetButton._rect.x and raw_x <= SettingsPanel._resetButton._rect.x + SettingsPanel._resetButton._rect.w and raw_y >= SettingsPanel._resetButton._rect.y and raw_y <= SettingsPanel._resetButton._rect.y + SettingsPanel._resetButton._rect.h then
        local Sound = require("src.core.sound")
        Sound.playSFX("button_click")
        SettingsPanel.resetToDefaults()
        return true
    end

    if contentHeight > innerH then
        local scrollbarWidth = 12
        local scrollbarX = panelX + w - scrollbarWidth - 4
        local scrollbarY = contentY
        local scrollbarH = innerH
        local thumbH = math.max(20, scrollbarH * (innerH / contentHeight))
        local trackRange = scrollbarH - thumbH
        local thumbY = scrollbarY + (trackRange > 0 and (trackRange * (scrollY / (contentHeight - innerH))) or 0)

        if raw_x >= scrollbarX and raw_x <= scrollbarX + scrollbarWidth then
            if raw_y >= thumbY and raw_y <= thumbY + thumbH then
                scrollDragOffset = raw_y - thumbY
                SettingsPanel._draggingScrollbar = true
                return true
            elseif raw_y >= scrollbarY and raw_y <= scrollbarY + scrollbarH then
                local clickY = raw_y - scrollbarY
                local frac = trackRange > 0 and (clickY / trackRange) or 0
                local maxScroll = math.max(0, contentHeight - innerH)
                scrollY = math.max(0, math.min(maxScroll, frac * maxScroll))
                return true
            end
        end
    end

    return false
end

function SettingsPanel.mousereleased(raw_x, raw_y, button)
    if not SettingsPanel.window.visible then return false end

    if SettingsPanel.window:mousereleased(raw_x, raw_y, button) then
        return true
    end

    SettingsPanel._draggingScrollbar = false
    AudioPanel.mousereleased(raw_x, raw_y, button)
    GraphicsPanel.mousereleased(raw_x, raw_y, button)
    return false
end

function SettingsPanel.wheelmoved(x, y, dx, dy)
    if not SettingsPanel.window.visible then return false end

    local win = SettingsPanel.window
    if not win:containsPoint(x, y) then return false end

    local content = win:getContentBounds()
    local innerH = content.h
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

    if SettingsPanel.window:mousemoved(raw_x, raw_y, dx, dy) then
        return true
    end

    GraphicsPanel.mousemoved(raw_x, raw_y)
    local audioHandled = AudioPanel.mousemoved(raw_x, raw_y)

    if SettingsPanel._draggingScrollbar and SettingsPanel._scrollbarTrack then
        local content = SettingsPanel.window:getContentBounds()
        local innerH = content.h
        local scrollbar = SettingsPanel._scrollbarTrack
        local thumb = SettingsPanel._scrollbarThumb
        if scrollbar and thumb then
            local trackRange = scrollbar.h - thumb.h
            if trackRange > 0 then
                local newThumbY = raw_y - scrollDragOffset
                local frac = (newThumbY - scrollbar.y) / trackRange
                local maxScroll = math.max(0, contentHeight - innerH)
                scrollY = math.max(0, math.min(maxScroll, frac * maxScroll))
            end
        end
        return true
    end

    return audioHandled
end

function SettingsPanel.keypressed(key)
    if not SettingsPanel.window.visible then return false end

    if ControlsPanel.keypressed(key) then
        keymap = cloneSettings(Settings.getKeymap())
        ControlsPanel.setKeymap(keymap, function(newMap) keymap = newMap end)
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
    return ControlsPanel.isBinding()
end

function SettingsPanel.resetToDefaults()
    local filename = "settings.json"
    if love.filesystem.getInfo(filename) then
        local success = love.filesystem.remove(filename)
        if not success then
            Log.error("SettingsPanel.resetToDefaults - Failed to delete settings file")
            Notifications.add("Failed to reset settings", "error")
            return
        end
    end

    local defaultGraphics = Settings.getDefaultGraphicsSettings()
    local defaultAudio = Settings.getDefaultAudioSettings()
    local defaultKeymap = Settings.getDefaultKeymap()

    currentGraphicsSettings = cloneSettings(defaultGraphics)
    currentAudioSettings = cloneSettings(defaultAudio)
    keymap = cloneSettings(defaultKeymap)

    Settings.applySettings(defaultGraphics, defaultAudio)

    for action, binding in pairs(defaultKeymap) do
        if type(binding) == "table" then
            Settings.setKeyBinding(action, binding.primary, "primary")
        else
            Settings.setKeyBinding(action, binding, "primary")
        end
    end

    Settings.save()

    updateModuleData()

    Notifications.add("Settings reset to defaults (saves preserved)", "success")
end

return SettingsPanel
