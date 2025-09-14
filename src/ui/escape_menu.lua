local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local SettingsPanel = require("src.ui.settings_panel")
local SaveSlots = require("src.ui.save_slots")
local StateManager = require("src.managers.state_manager")

local EscapeMenu = {
    visible = false,
    exitButtonDown = false,
    settingsButtonDown = false,
    resumeButtonDown = false,
    saveButtonDown = false,
    loadButtonDown = false,
    showSaveSlots = false,
    saveSlotMode = "save", -- "save" or "load"
    saveSlotsUI = nil
}

local function pointIn(px, py, rx, ry, rw, rh)
    return px >= rx and py >= ry and px <= rx + rw and py <= ry + rh
end

local function getLayout()
    local sw, sh = Viewport.getDimensions()
    local w, h = 320, 280 -- Decreased height to fit buttons tighter
    local x = (sw - w) / 2
    local y = (sh - h) / 2

    local buttonW, buttonH = w - 40, 40 -- Wider buttons, taller buttons
    local buttonX = x + (w - buttonW) / 2
    local resumeButtonY = y + 30
    local saveButtonY = y + 75
    local loadButtonY = y + 120
    local settingsButtonY = y + 165
    local exitButtonY = y + 210

    return x, y, w, h, buttonX, resumeButtonY, saveButtonY, loadButtonY, settingsButtonY, exitButtonY, buttonW, buttonH
end

function EscapeMenu.show()
    EscapeMenu.visible = true
    if not EscapeMenu.saveSlotsUI then
        EscapeMenu.saveSlotsUI = SaveSlots:new()
    end
end

function EscapeMenu.hide()
    EscapeMenu.visible = false
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
        -- Draw save slots UI
        local saveSlotsW, saveSlotsH = 700, 600
        local saveSlotsX = (Viewport.getDimensions() - saveSlotsW) / 2
        local saveSlotsY = (select(2, Viewport.getDimensions()) - saveSlotsH) / 2
        
        -- Background
        Theme.drawGradientGlowRect(saveSlotsX, saveSlotsY, saveSlotsW, saveSlotsH, 4, Theme.colors.bg1, Theme.colors.bg2, Theme.colors.primary, Theme.effects.glowWeak * 0.3)
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

    local x, y, w, h, buttonX, resumeButtonY, saveButtonY, loadButtonY, settingsButtonY, exitButtonY, buttonW, buttonH = getLayout()
    
    -- Draw menu background
    Theme.drawGradientGlowRect(x, y, w, h, 4, Theme.colors.bg1, Theme.colors.bg2, Theme.colors.primary, Theme.effects.glowWeak * 0.3)
    Theme.drawEVEBorder(x, y, w, h, 4, Theme.colors.border, 2)
    
    -- No title text
    
    -- Draw buttons
    local mx, my = Viewport.getMousePosition()
    local t = love.timer.getTime()
    
    -- Resume button
    local resumeHover = pointIn(mx, my, buttonX, resumeButtonY, buttonW, buttonH)
    Theme.drawStyledButton(buttonX, resumeButtonY, buttonW, buttonH, "Resume Game", resumeHover, t, nil, EscapeMenu.resumeButtonDown, {compact=true})

    -- Save Game button
    local saveHover = pointIn(mx, my, buttonX, saveButtonY, buttonW, buttonH)
    Theme.drawStyledButton(buttonX, saveButtonY, buttonW, buttonH, "Save Game", saveHover, t, nil, EscapeMenu.saveButtonDown, {compact=true})

    -- Load Game button
    local loadHover = pointIn(mx, my, buttonX, loadButtonY, buttonW, buttonH)
    Theme.drawStyledButton(buttonX, loadButtonY, buttonW, buttonH, "Load Game", loadHover, t, nil, EscapeMenu.loadButtonDown, {compact=true})

    -- Settings button
    local settingsHover = pointIn(mx, my, buttonX, settingsButtonY, buttonW, buttonH)
    Theme.drawStyledButton(buttonX, settingsButtonY, buttonW, buttonH, "Settings", settingsHover, t, nil, EscapeMenu.settingsButtonDown, {compact=true})

    -- Exit button
    local exitHover = pointIn(mx, my, buttonX, exitButtonY, buttonW, buttonH)
    Theme.drawStyledButton(buttonX, exitButtonY, buttonW, buttonH, "Exit to Main Menu", exitHover, t, Theme.colors.danger, EscapeMenu.exitButtonDown, {compact=true})
end

function EscapeMenu.mousepressed(x, y, button)
    if not EscapeMenu.visible then return false, false end
    
    if SettingsPanel.visible then
        return SettingsPanel.mousepressed(x, y, button)
    end
    
    -- Handle save slots UI
    if EscapeMenu.showSaveSlots then
        local saveSlotsW, saveSlotsH = 700, 600
        local saveSlotsX = (Viewport.getDimensions() - saveSlotsW) / 2
        local saveSlotsY = (select(2, Viewport.getDimensions()) - saveSlotsH) / 2
        
        -- Check back button
        local backButtonW, backButtonH = 80, 30
        local backButtonX, backButtonY = saveSlotsX + 10, saveSlotsY + 10
        if pointIn(x, y, backButtonX, backButtonY, backButtonW, backButtonH) and button == 1 then
            EscapeMenu.showSaveSlots = false
            return true, false
        end
        
        -- Handle save slots UI clicks
        if EscapeMenu.saveSlotsUI then
            local result = EscapeMenu.saveSlotsUI:mousepressed(x, y, button, saveSlotsX + 10, saveSlotsY + 50, saveSlotsW - 20, saveSlotsH - 60)
            if result == "saved" then
                -- Save completed, close interface
                EscapeMenu.showSaveSlots = false
                EscapeMenu.hide()
                return true, false
            elseif result == "loaded" then
                -- Load completed, close interface
                EscapeMenu.showSaveSlots = false
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
        return false, false
    end

    local menuX, menuY, menuW, menuH, buttonX, resumeButtonY, saveButtonY, loadButtonY, settingsButtonY, exitButtonY, buttonW, buttonH = getLayout()
    
    if button == 1 then
        -- Check resume button
        if pointIn(x, y, buttonX, resumeButtonY, buttonW, buttonH) then
            EscapeMenu.resumeButtonDown = true
            return true, false
        end
        
        -- Check save game button
        if pointIn(x, y, buttonX, saveButtonY, buttonW, buttonH) then
            EscapeMenu.saveButtonDown = true
            return true, false
        end
        
        -- Check load game button
        if pointIn(x, y, buttonX, loadButtonY, buttonW, buttonH) then
            EscapeMenu.loadButtonDown = true
            return true, false
        end

        -- Check settings button
        if pointIn(x, y, buttonX, settingsButtonY, buttonW, buttonH) then
            EscapeMenu.settingsButtonDown = true
            return true, false
        end

        -- Check exit button
        if pointIn(x, y, buttonX, exitButtonY, buttonW, buttonH) then
            EscapeMenu.exitButtonDown = true
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
    
    local menuX, menuY, menuW, menuH, buttonX, resumeButtonY, saveButtonY, loadButtonY, settingsButtonY, exitButtonY, buttonW, buttonH = getLayout()
    
    if button == 1 then
        -- Resume button
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
                return true, false
            end
        end
        
        -- Load Game button
        if EscapeMenu.loadButtonDown then
            EscapeMenu.loadButtonDown = false
            if pointIn(x, y, buttonX, loadButtonY, buttonW, buttonH) then
                EscapeMenu.saveSlotMode = "load"
                if EscapeMenu.saveSlotsUI then
                    EscapeMenu.saveSlotsUI:setMode("load")
                end
                EscapeMenu.showSaveSlots = true
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

        -- Exit button
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
            return true
        end
        return true
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