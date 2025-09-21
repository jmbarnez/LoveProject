local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local SettingsPanel = require("src.ui.settings_panel")
local SaveSlots = require("src.ui.save_slots")
local StateManager = require("src.managers.state_manager")

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

function EscapeMenu.draw()
    if not EscapeMenu.visible then return end
    
    if SettingsPanel.visible then
        SettingsPanel.draw()
        return
    end

    -- Check if we should show the save slots UI instead
    if EscapeMenu.showSaveSlots then
        -- Draw save slots UI with dynamic sizing
        local contentW, contentH = 600, 500
        if EscapeMenu.saveSlotsUI and EscapeMenu.saveSlotsUI.getPreferredSize then
            contentW, contentH = EscapeMenu.saveSlotsUI:getPreferredSize()
        end
        -- Add chrome/padding
        local framePaddingX, framePaddingY = 20, 60 -- left/right 10 each and top/bottom for title/back
        local saveSlotsW, saveSlotsH = contentW + framePaddingX, contentH + framePaddingY
        local vw, vh = Viewport.getDimensions()
        local saveSlotsX = (vw - saveSlotsW) / 2
        local saveSlotsY = (vh - saveSlotsH) / 2
        
        -- Background
        Theme.drawGradientGlowRect(saveSlotsX, saveSlotsY, saveSlotsW, saveSlotsH, 4, Theme.colors.bg1, Theme.colors.bg2, Theme.colors.primary, Theme.effects.glowWeak * 0.1)
        Theme.drawEVEBorder(saveSlotsX, saveSlotsY, saveSlotsW, saveSlotsH, 4, Theme.colors.border, 2)
        
        -- Back button
        local backButtonW, backButtonH = 80, 30
        local backButtonX, backButtonY = saveSlotsX + 10, saveSlotsY + 10
        local mx, my = Viewport.getMousePosition()
        local backHover = pointIn(mx, my, backButtonX, backButtonY, backButtonW, backButtonH)
        Theme.drawStyledButton(backButtonX, backButtonY, backButtonW, backButtonH, "← Back", backHover, love.timer.getTime(), nil, false)
        
        -- Save slots content
        if EscapeMenu.saveSlotsUI then
            EscapeMenu.saveSlotsUI:draw(saveSlotsX + 10, saveSlotsY + 50, saveSlotsW - 20, saveSlotsH - 60)
        end
        
        return
    end

    local x, y, w, h, buttonX, resumeButtonY, saveButtonY, settingsButtonY, exitButtonY, buttonW, buttonH = getLayout()

    -- Draw menu background
    Theme.drawGradientGlowRect(x, y, w, h, 4, Theme.colors.bg1, Theme.colors.bg2, Theme.colors.primary, Theme.effects.glowWeak * 0.1)
    Theme.drawEVEBorder(x, y, w, h, 4, Theme.colors.border, 2)

    -- No title text

    -- Draw buttons with smaller text
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
    
    if SettingsPanel.visible then
        return SettingsPanel.mousepressed(x, y, button)
    end
    
    -- Handle save slots UI
    if EscapeMenu.showSaveSlots then
        local contentW, contentH = 600, 500
        if EscapeMenu.saveSlotsUI and EscapeMenu.saveSlotsUI.getPreferredSize then
            contentW, contentH = EscapeMenu.saveSlotsUI:getPreferredSize()
        end
        local framePaddingX, framePaddingY = 20, 60
        local saveSlotsW, saveSlotsH = contentW + framePaddingX, contentH + framePaddingY
        local vw, vh = Viewport.getDimensions()
        local saveSlotsX = (vw - saveSlotsW) / 2
        local saveSlotsY = (vh - saveSlotsH) / 2
        
        -- Check back button
        local backButtonW, backButtonH = 80, 30
        local backButtonX, backButtonY = saveSlotsX + 10, saveSlotsY + 10

        -- Convert mouse coordinates to virtual coordinates for proper click detection
        local vx, vy = Viewport.toVirtual(x, y)

        -- Create a back button object for Theme.handleButtonClick
        local backButton = {_rect = {x = backButtonX, y = backButtonY, w = backButtonW, h = backButtonH}}
        if Theme.handleButtonClick(backButton, vx, vy, function()
            EscapeMenu.showSaveSlots = false
            -- Notify UIManager that we're no longer showing save slots
            if _G.UIManager and _G.UIManager.state and _G.UIManager.state.escape then
                _G.UIManager.state.escape.showingSaveSlots = false
            end
        end) then
            return true, false
        end
        
        -- Handle save slots UI clicks
        if EscapeMenu.saveSlotsUI then
            local result = EscapeMenu.saveSlotsUI:mousepressed(x, y, button, saveSlotsX + 10, saveSlotsY + 50, saveSlotsW - 20, saveSlotsH - 60)
            if result == "saved" then
                -- Save completed, close interface
                EscapeMenu.showSaveSlots = false
                -- Notify UIManager that we're no longer showing save slots
                if _G.UIManager and _G.UIManager.state and _G.UIManager.state.escape then
                    _G.UIManager.state.escape.showingSaveSlots = false
                end
                EscapeMenu.hide()
                return true, false
            elseif result == "loaded" then
                -- Load completed, close interface
                EscapeMenu.showSaveSlots = false
                -- Notify UIManager that we're no longer showing save slots
                if _G.UIManager and _G.UIManager.state and _G.UIManager.state.escape then
                    _G.UIManager.state.escape.showingSaveSlots = false
                end
                EscapeMenu.hide()
                return true, false
            elseif result == "deleted" then
                -- File was deleted, just refresh the interface
                return true, false
            elseif result then
                return true, false
            end
        end
        
        -- Consume clicks inside save slots area
        if pointIn(x, y, saveSlotsX, saveSlotsY, saveSlotsW, saveSlotsH) then
            return true, false
        end
        
        -- Click outside - close save slots UI
        EscapeMenu.showSaveSlots = false
        -- Notify UIManager that we're no longer showing save slots
        if _G.UIManager and _G.UIManager.state and _G.UIManager.state.escape then
            _G.UIManager.state.escape.showingSaveSlots = false
        end
        return false, false
    end

    local menuX, menuY, menuW, menuH, buttonX, resumeButtonY, saveButtonY, settingsButtonY, exitButtonY, buttonW, buttonH = getLayout()

    -- Create button objects for Theme.handleButtonClick
    local buttons = {
        {name = "resume", y = resumeButtonY, action = function() EscapeMenu.resumeButtonDown = true end},
        {name = "save", y = saveButtonY, action = function() EscapeMenu.saveButtonDown = true end},
        {name = "settings", y = settingsButtonY, action = function() EscapeMenu.settingsButtonDown = true end},
        {name = "exit", y = exitButtonY, action = function() EscapeMenu.exitButtonDown = true end}
    }
    
    -- Check all buttons
    for _, btn in ipairs(buttons) do
        local button = {_rect = {x = buttonX, y = btn.y, w = buttonW, h = buttonH}}
        if Theme.handleButtonClick(button, x, y, btn.action) then
            return true, false
        end
    end
    
    -- Check if click is inside menu area (consume click)
    if pointIn(x, y, menuX, menuY, menuW, menuH) then
        return true, false
    end
    
    -- Click outside menu - close it
    return false, true
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
