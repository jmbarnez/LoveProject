local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local SettingsPanel = require("src.ui.settings_panel")
local SaveSlots = require("src.ui.save_slots")
local StateManager = require("src.managers.state_manager")
local Window = require("src.ui.common.window")

local EscapeMenu = {
    visible = false,
    exitButtonDown = false,
    settingsButtonDown = false,
    saveButtonDown = false,
    resumeButtonDown = false,
    showSaveSlots = false,
    saveSlotMode = "save",
    saveSlotsUI = nil
}

local function pointIn(px, py, rx, ry, rw, rh)
    -- Handle nil values gracefully
    if px == nil or py == nil or rx == nil or ry == nil or rw == nil or rh == nil then
        return false
    end
    return px >= rx and py >= ry and px <= rx + rw and py <= ry + rh
end

-- Calculate preferred layout size based on content
local function getLayoutSize()
    local font = love.graphics.getFont() or Theme.fonts.normal
    local buttonH = 28
    local buttonSpacing = 4
    local totalButtons = 4
    local topPadding = 15
    local bottomPadding = 10
    local sidePadding = 15

    -- Calculate width based on longest button text
    local buttonTexts = {"Resume Game", "Save", "Settings", "Exit to Menu"}
    local maxTextWidth = 0
    for _, text in ipairs(buttonTexts) do
        local textW = font:getWidth(text)
        if textW > maxTextWidth then
            maxTextWidth = textW
        end
    end

    -- Add padding for button content and spacing
    local buttonW = maxTextWidth + 20 -- 10px padding on each side
    local w = buttonW + sidePadding * 2

    -- Calculate height
    local totalHeight = topPadding + (buttonH * totalButtons) + (buttonSpacing * (totalButtons - 1)) + bottomPadding
    local h = totalHeight

    return w, h
end

local function getLayout()
    local sw, sh = Viewport.getDimensions()
    local buttonH = 28
    local buttonSpacing = 4
    local totalButtons = 4
    local topPadding = 15
    local bottomPadding = 10

    -- Get preferred size
    local w, h = getLayoutSize()
    local x = (sw - w) / 2
    local y = (sh - h) / 2

    local buttonW = w - 30 -- Account for side padding
    local buttonX = x + (w - buttonW) / 2
    local startY = y + topPadding
    local resumeButtonY = startY
    local saveButtonY = resumeButtonY + buttonH + buttonSpacing
    local settingsButtonY = saveButtonY + buttonH + buttonSpacing
    local exitButtonY = settingsButtonY + buttonH + buttonSpacing

    return x, y, w, h, buttonX, resumeButtonY, saveButtonY, settingsButtonY, exitButtonY, buttonW, buttonH
end

function EscapeMenu.show()
    EscapeMenu.visible = true
    if not EscapeMenu.saveSlotsUI then
        EscapeMenu.saveSlotsUI = SaveSlots:new()
    end

    -- Pause the game when escape menu is opened
    local Game = require("src.game")
    Game.pause()
end

function EscapeMenu.hide()
    EscapeMenu.visible = false

    -- Unpause the game when escape menu is closed
    local Game = require("src.game")
    Game.unpause()
end

function EscapeMenu.isVisible()
    return EscapeMenu.visible
end

function EscapeMenu.toggle()
    EscapeMenu.visible = not EscapeMenu.visible
end

function EscapeMenu.init()
    local w, h = getLayoutSize()
    EscapeMenu.window = Window.new({
        title = "Game Paused",
        width = w,
        height = h,
        closable = false,
        draggable = true,
        resizable = false,
        drawContent = EscapeMenu.drawContent
    })
end

function EscapeMenu.draw()
    if not EscapeMenu.visible then return end
    if not EscapeMenu.window then EscapeMenu.init() end
    EscapeMenu.window.visible = EscapeMenu.visible
    EscapeMenu.window:draw()
end

function EscapeMenu.drawContent(window, x, y, w, h)
    local buttonX, resumeButtonY, saveButtonY, settingsButtonY, exitButtonY, buttonW, buttonH = x + 15, y + 15, y + 15 + 32, y + 15 + 64, y + 15 + 96, w - 30, 28
    local mx, my = Viewport.getMousePosition()
    local t = love.timer.getTime()

    -- Save current font and set to small
    local oldFont = love.graphics.getFont()
    love.graphics.setFont(Theme.fonts and (Theme.fonts.small or Theme.fonts.normal) or oldFont)

    -- Resume Game button
    local resumeHover = pointIn(mx, my, buttonX, resumeButtonY, buttonW, buttonH)
    Theme.drawStyledButton(buttonX, resumeButtonY, buttonW, buttonH, "Resume Game", resumeHover, t, Theme.colors.success, EscapeMenu.resumeButtonDown, {compact=true})

    -- Save Game button
    local saveHover = pointIn(mx, my, buttonX, saveButtonY, buttonW, buttonH)
    Theme.drawStyledButton(buttonX, saveButtonY, buttonW, buttonH, "Save", saveHover, t, nil, EscapeMenu.saveButtonDown, {compact=true})

    -- Settings button
    local settingsHover = pointIn(mx, my, buttonX, settingsButtonY, buttonW, buttonH)
    Theme.drawStyledButton(buttonX, settingsButtonY, buttonW, buttonH, "Settings", settingsHover, t, nil, EscapeMenu.settingsButtonDown, {compact=true})

    -- Exit to Main Menu button
    local exitHover = pointIn(mx, my, buttonX, exitButtonY, buttonW, buttonH)
    Theme.drawStyledButton(buttonX, exitButtonY, buttonW, buttonH, "Exit to Menu", exitHover, t, Theme.colors.danger, EscapeMenu.exitButtonDown, {compact=true})

    -- Restore original font
    love.graphics.setFont(oldFont)
end

function EscapeMenu.mousepressed(x, y, button)
    if not EscapeMenu.visible or button ~= 1 then return false, false end
    if not EscapeMenu.window then return false, false end

    if EscapeMenu.window:mousepressed(x, y, button) then
        return true, false
    end

    -- Handle save slots UI
    if EscapeMenu.showSaveSlots then
        -- ... (save slots logic remains the same)
        return true, false
    end

    local _, _, _, _, buttonX, resumeButtonY, saveButtonY, settingsButtonY, exitButtonY, buttonW, buttonH = getLayout()

    -- Create button objects for Theme.handleButtonClick
    local buttons = {
        {name = "resume", y = resumeButtonY, action = function() EscapeMenu.resumeButtonDown = true end},
        {name = "save", y = saveButtonY, action = function() EscapeMenu.saveButtonDown = true end},
        {name = "settings", y = settingsButtonY, action = function() EscapeMenu.settingsButtonDown = true end},
        {name = "exit", y = exitButtonY, action = function() EscapeMenu.exitButtonDown = true end}
    }
    
    -- Check all buttons
    for _, btn in ipairs(buttons) do
        local buttonRect = {x = buttonX, y = btn.y, w = buttonW, h = buttonH}
        if pointIn(x, y, buttonRect.x, buttonRect.y, buttonRect.w, buttonRect.h) then
            btn.action()
            return true, false
        end
    end
    
    return false, false
end

function EscapeMenu.mousereleased(x, y, button)
    if not EscapeMenu.visible then return false, false end

    if SettingsPanel.visible then
        return SettingsPanel.mousereleased(x, y, button)
    end
    
    -- Don't handle releases when in save slots mode
    if EscapeMenu.showSaveSlots then
        return true, false
    end

    local menuX, menuY, menuW, menuH, buttonX, resumeButtonY, saveButtonY, settingsButtonY, exitButtonY, buttonW, buttonH = getLayout()

    if button == 1 then
        -- Resume Game button
        if EscapeMenu.resumeButtonDown then
            EscapeMenu.resumeButtonDown = false
            if pointIn(x, y, buttonX, resumeButtonY, buttonW, buttonH) then
                EscapeMenu.hide()
                return true, false
            end
        end

        -- Save Game button
        if EscapeMenu.saveButtonDown then
            EscapeMenu.saveButtonDown = false
            if pointIn(x, y, buttonX, saveButtonY, buttonW, buttonH) then
                EscapeMenu.saveSlotMode = "save"
                if EscapeMenu.saveSlotsUI then
                    EscapeMenu.saveSlotsUI:setMode("save")
                end
                EscapeMenu.showSaveSlots = true
                -- Notify UIManager that we're showing save slots
                if _G.UIManager and _G.UIManager.state and _G.UIManager.state.escape then
                    _G.UIManager.state.escape.showingSaveSlots = true
                end
                return true, false
            end
        end


        -- Settings button
        if EscapeMenu.settingsButtonDown then
            EscapeMenu.settingsButtonDown = false
            if pointIn(x, y, buttonX, settingsButtonY, buttonW, buttonH) then
                SettingsPanel.toggle()
                return true, false
            end
        end

        -- Exit to Main Menu button
        if EscapeMenu.exitButtonDown then
            EscapeMenu.exitButtonDown = false
            if pointIn(x, y, buttonX, exitButtonY, buttonW, buttonH) then
                love.setScreen("start")
                return true, false
            end
        end
    end
    
    -- Consume all clicks when menu is visible
    return true, false
end

function EscapeMenu.keypressed(key)
    if not EscapeMenu.visible then return false end
    
    if SettingsPanel.visible then
        if key == "escape" then
            SettingsPanel.toggle()
            -- Prevent the escape menu from closing immediately
            return true
        end
        return SettingsPanel.keypressed(key)
    end
    
    -- Handle save slots UI
    if EscapeMenu.showSaveSlots then
        if key == "escape" then
            EscapeMenu.showSaveSlots = false
            -- Notify UIManager that we're no longer showing save slots
            if _G.UIManager and _G.UIManager.state and _G.UIManager.state.escape then
                _G.UIManager.state.escape.showingSaveSlots = false
            end
            return true
        end
        -- Don't consume other keys when save slots are open
        return false
    end

    if key == "escape" then
        EscapeMenu.hide()
        return true
    end
    
    return true -- Consume all keypresses when menu is visible
end

function EscapeMenu.textinput(text)
    if not EscapeMenu.visible then return false end
    
    if SettingsPanel.visible then
        return false -- Let settings panel handle its own text input
    end
    
    -- Save slots UI doesn't need text input
    if EscapeMenu.showSaveSlots then
        return true
    end
    
    return true -- Consume all text input when menu is visible
end

return EscapeMenu
