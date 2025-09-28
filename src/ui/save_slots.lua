local Theme = require("src.core.theme")
local StateManager = require("src.managers.state_manager")

local SaveSlots = {}

function SaveSlots:new(options)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.selectedSlot = nil
    o.newSaveName = ""
    o.showNewSave = false
    o.onClose = options and options.onClose
    return o
end

function SaveSlots:draw(x, y, w, h)
    local baseFont = Theme.fonts and Theme.fonts.normal or love.graphics.getFont()
    local buttonFont = (Theme.fonts and (Theme.fonts.tiny or Theme.fonts.small)) or baseFont
    local buttonPaddingX, buttonPaddingY = 18, 8
    local buttonMinWidth = 105
    local buttonMinHeight = buttonFont:getHeight() + buttonPaddingY * 2
    local lineHeight = baseFont:getHeight() + 4
    local currentY = y + 10
    local layout = {
        saveButton = nil,
        slots = {},
        autosaveLoad = nil
    }
    self._layout = layout

    local function computeButtonSize(label)
        local prevFont = love.graphics.getFont()
        love.graphics.setFont(buttonFont)
        local textW = buttonFont:getWidth(label)
        local textH = buttonFont:getHeight()
        love.graphics.setFont(prevFont)
        local width = math.max(buttonMinWidth, textW + buttonPaddingX * 2)
        local height = math.max(buttonMinHeight, textH + buttonPaddingY * 2)
        return width, height, textW, textH
    end

    local function drawButtonRect(xPos, yPos, width, height, fillColor, label)
        Theme.setColor(fillColor)
        love.graphics.rectangle("fill", xPos, yPos, width, height)
        Theme.setColor(Theme.colors.text)
        local prevFont = love.graphics.getFont()
        love.graphics.setFont(buttonFont)
        local textW = buttonFont:getWidth(label)
        local textH = buttonFont:getHeight()
        local availableW = width - buttonPaddingX * 2
        local availableH = height - buttonPaddingY * 2
        if textW <= 0 or textH <= 0 then
            love.graphics.print(label, xPos + buttonPaddingX, yPos + buttonPaddingY)
            love.graphics.setFont(prevFont)
            return
        end
        local scale = math.min(1, availableW / textW, availableH / textH)
        if scale <= 0 then scale = availableH / textH end
        local drawW = textW * scale
        local drawH = textH * scale
        local drawX = xPos + (width - drawW) / 2
        local drawY = yPos + (height - drawH) / 2
        love.graphics.print(label, drawX, drawY, 0, scale, scale)
        love.graphics.setFont(prevFont)
    end

    -- Quick actions
    Theme.setColor(Theme.colors.textSecondary)
    love.graphics.print("F5: Quick Save  |  F9: Quick Load", x + 10, currentY)
    currentY = currentY + lineHeight * 1.5

    -- Auto-save status
    local stats = StateManager.getStats()
    local statusText = string.format("Auto-save: %s | Last save: %s",
        stats.autoSaveEnabled and "ON" or "OFF",
        stats.lastSave)
    love.graphics.print(statusText, x + 10, currentY)
    currentY = currentY + lineHeight * 2

    -- New save section
    Theme.setColor(Theme.colors.accent)
    love.graphics.print("Create New Save:", x + 10, currentY)
    currentY = currentY + lineHeight

    -- New save input (placeholder for now - would need proper text input)
    Theme.setColor(Theme.colors.bg1)
    love.graphics.rectangle("fill", x + 10, currentY, w - 20, lineHeight * 1.2)
    Theme.setColor(Theme.colors.border)
    love.graphics.rectangle("line", x + 10, currentY, w - 20, lineHeight * 1.2)

    Theme.setColor(Theme.colors.textSecondary)
    local saveName = self.newSaveName ~= "" and self.newSaveName or "Enter save name..."
    local inputFont = buttonFont
    local prevFont = love.graphics.getFont()
    love.graphics.setFont(inputFont)
    love.graphics.print(saveName, x + 15, currentY + (lineHeight * 1.2 - inputFont:getHeight()) / 2)
    love.graphics.setFont(prevFont)
    currentY = currentY + lineHeight * 2

    -- Save button
    local saveLabel = "Save"
    local saveButtonW, saveButtonH = computeButtonSize(saveLabel)
    drawButtonRect(x + 10, currentY, saveButtonW, saveButtonH, Theme.colors.success, saveLabel)
    layout.saveButton = { x = x + 10, y = currentY, w = saveButtonW, h = saveButtonH }

    currentY = currentY + saveButtonH + lineHeight

    -- Existing saves
    Theme.setColor(Theme.colors.accent)
    love.graphics.print("Existing Saves:", x + 10, currentY)
    currentY = currentY + lineHeight

    -- List save slots
    local slots = StateManager.getSaveSlots()

    local loadLabel = "Load"
    local deleteLabel = "Delete"
    local loadButtonW, loadButtonH = computeButtonSize(loadLabel)
    local deleteButtonW, deleteButtonH = computeButtonSize(deleteLabel)
    local slotButtonWidth = math.max(loadButtonW, deleteButtonW)
    local slotButtonHeight = math.max(loadButtonH, deleteButtonH)
    local slotPadding = math.max(12, buttonPaddingY + 2)
    local buttonSpacing = math.max(10, buttonPaddingX * 0.5)

    if #slots == 0 then
        Theme.setColor(Theme.colors.textSecondary)
        love.graphics.print("No save files found", x + 10, currentY)
    else
        for i, slot in ipairs(slots) do
            -- Skip auto-saves in main list (show them separately)
            if slot.name ~= "autosave" then
                local slotY = currentY
                local slotH = lineHeight * 2.5

                -- Background
                local bgColor = (self.selectedSlot == slot.name) and Theme.colors.bg2 or Theme.colors.bg1
                Theme.setColor(bgColor)
                love.graphics.rectangle("fill", x + 10, slotY, w - 20, slotH)

                -- Border
                Theme.setColor(Theme.colors.border)
                love.graphics.rectangle("line", x + 10, slotY, w - 20, slotH)

                -- Slot info
                Theme.setColor(Theme.colors.text)
                love.graphics.print(slot.description or slot.name, x + 15, slotY + 4)

                local infoText = string.format("Level %d | %d GC | %s",
                    slot.playerLevel or 1,
                    slot.playerCredits or 0,
                    slot.realTime or "Unknown time")
                Theme.setColor(Theme.colors.textSecondary)
                love.graphics.print(infoText, x + 15, slotY + lineHeight + 2)

                -- Load button
                local buttonY = slotY + slotH - slotButtonHeight - slotPadding

                local loadButtonX = x + w - slotPadding - slotButtonWidth
                drawButtonRect(loadButtonX, buttonY, slotButtonWidth, slotButtonHeight, Theme.colors.info, loadLabel)

                -- Delete button
                local deleteButtonX = loadButtonX - buttonSpacing - slotButtonWidth
                drawButtonRect(deleteButtonX, buttonY, slotButtonWidth, slotButtonHeight, Theme.colors.danger, deleteLabel)

                layout.slots[slot.name] = {
                    load = { x = loadButtonX, y = buttonY, w = slotButtonWidth, h = slotButtonHeight },
                    delete = { x = deleteButtonX, y = buttonY, w = slotButtonWidth, h = slotButtonHeight }
                }

                currentY = currentY + slotH + 4
            end
        end
    end

    -- Auto-save section (at bottom)
    currentY = currentY + lineHeight
    Theme.setColor(Theme.colors.warning)
    love.graphics.print("Auto-Save:", x + 10, currentY)
    currentY = currentY + lineHeight

    -- Find autosave slot
    local autosave = nil
    for _, slot in ipairs(slots) do
        if slot.name == "autosave" then
            autosave = slot
            break
        end
    end

    if autosave then
        local autosaveY = currentY
        local autosaveH = math.max(lineHeight * 2, slotButtonHeight + slotPadding * 2)

        Theme.setColor(Theme.colors.bg1)
        love.graphics.rectangle("fill", x + 10, autosaveY, w - 20, autosaveH)
        Theme.setColor(Theme.colors.border)
        love.graphics.rectangle("line", x + 10, autosaveY, w - 20, autosaveH)

        Theme.setColor(Theme.colors.text)
        love.graphics.print("Auto-save " .. (autosave.realTime or "Unknown"), x + 15, autosaveY + 4)

        local autoInfo = string.format("Level %d | %d GC",
            autosave.playerLevel or 1,
            autosave.playerCredits or 0)
        Theme.setColor(Theme.colors.textSecondary)
        love.graphics.print(autoInfo, x + 15, autosaveY + lineHeight + 2)

        -- Auto-save load button
        local buttonY = autosaveY + autosaveH - slotButtonHeight - slotPadding
        local autoLoadButtonX = x + w - slotPadding - slotButtonWidth
        drawButtonRect(autoLoadButtonX, buttonY, slotButtonWidth, slotButtonHeight, Theme.colors.warning, loadLabel)
        layout.autosaveLoad = { x = autoLoadButtonX, y = buttonY, w = slotButtonWidth, h = slotButtonHeight }
    else
        Theme.setColor(Theme.colors.textSecondary)
        love.graphics.print("No auto-save available", x + 10, currentY)
    end
end

function SaveSlots:mousepressed(mx, my, button)
    if button ~= 1 then return false end

    local layout = self._layout or {}

    local function pointInRect(px, py, rect)
        if not rect then return false end
        return px >= rect.x and px <= rect.x + rect.w and py >= rect.y and py <= rect.y + rect.h
    end

    -- Save button
    if pointInRect(mx, my, layout.saveButton) then
        -- Create new save with current timestamp as name
        local saveName = self.newSaveName ~= "" and self.newSaveName or ("Save " .. os.date("%H%M%S"))
        StateManager.saveGame(saveName, "Manual save - " .. os.date("%Y-%m-%d %H:%M:%S"))
        return true
    end

    -- Check save slots for load/delete buttons
    if layout.slots then
        for slotName, rects in pairs(layout.slots) do
            if pointInRect(mx, my, rects.load) then
                StateManager.loadGame(slotName)
                return true
            end
            if pointInRect(mx, my, rects.delete) then
                StateManager.deleteSave(slotName)
                return true
            end
        end
    end

    if pointInRect(mx, my, layout.autosaveLoad) then
        StateManager.loadGame("autosave")
        return true
    end

    return false
end

function SaveSlots:textinput(text)
    -- Simple text input for save name
    if text and text:match("[%w%s%-_]") then
        if #self.newSaveName < 30 then
            self.newSaveName = self.newSaveName .. text
        end
        return true
    end
    return false
end

function SaveSlots:keypressed(key)
    if key == "backspace" and #self.newSaveName > 0 then
        self.newSaveName = self.newSaveName:sub(1, -2)
        return true
    end
    return false
end

return SaveSlots
