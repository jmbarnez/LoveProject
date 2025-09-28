local Theme = require("src.core.theme")
local StateManager = require("src.managers.state_manager")

local DEFAULT_SLOT_COUNT = 6

local SaveSlots = {}

function SaveSlots:new(options)
    local o = {}
    setmetatable(o, self)
    self.__index = self

    o.slotCount = options and options.slotCount or DEFAULT_SLOT_COUNT
    o.onClose = options and options.onClose
    o.selectedSlot = nil -- numeric index (1-based)
    o._slotOrder = {}
    for i = 1, o.slotCount do
        o._slotOrder[i] = string.format("slot%d", i)
    end
    o._slotLookup = nil
    o._allSlots = nil
    o._cacheDirty = true

    return o
end

function SaveSlots:_ensureCache()
    if not self._cacheDirty and self._slotLookup then
        return
    end

    local slots = StateManager.getSaveSlots()
    self._allSlots = slots
    self._slotLookup = {}
    for _, slot in ipairs(slots) do
        self._slotLookup[slot.name] = slot
    end
    self._cacheDirty = false

    -- Clamp the selection to a valid index and default to first slot if none selected
    local slotCount = #self._slotOrder
    if not self.selectedSlot or self.selectedSlot < 1 or self.selectedSlot > slotCount then
        self.selectedSlot = nil
    end

    if not self.selectedSlot then
        -- Prefer first occupied slot, otherwise default to slot 1
        for index, slotName in ipairs(self._slotOrder) do
            if self._slotLookup[slotName] then
                self.selectedSlot = index
                break
            end
        end
        if not self.selectedSlot and slotCount > 0 then
            self.selectedSlot = 1
        end
    end
end

local function drawButtonRect(buttonFont, buttonPaddingX, buttonPaddingY, xPos, yPos, width, height, fillColor, label, enabled)
    local color = enabled and fillColor or Theme.withAlpha(fillColor, 0.4)
    Theme.setColor(color)
    love.graphics.rectangle("fill", xPos, yPos, width, height)

    local textColor = enabled and Theme.colors.text or Theme.withAlpha(Theme.colors.text, 0.5)
    Theme.setColor(textColor)

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

local function computeButtonSize(buttonFont, paddingX, paddingY, minW, minH, label)
    local prevFont = love.graphics.getFont()
    love.graphics.setFont(buttonFont)
    local textW = buttonFont:getWidth(label)
    local textH = buttonFont:getHeight()
    love.graphics.setFont(prevFont)
    local width = math.max(minW, textW + paddingX * 2)
    local height = math.max(minH, textH + paddingY * 2)
    return width, height, textW, textH
end

function SaveSlots:getSelectedSlotIndex()
    return self.selectedSlot
end

function SaveSlots:getSelectedSlotName()
    if not self.selectedSlot then return nil end
    return self._slotOrder[self.selectedSlot]
end

function SaveSlots:setSelectedSlot(index)
    if index and index >= 1 and index <= #self._slotOrder then
        self.selectedSlot = index
    end
end

function SaveSlots:getPreferredSize()
    local baseFont = Theme.fonts and Theme.fonts.normal or love.graphics.getFont()
    local buttonFont = (Theme.fonts and (Theme.fonts.tiny or Theme.fonts.small)) or baseFont
    local lineHeight = baseFont:getHeight() + 4
    local _, buttonH = computeButtonSize(buttonFont, 18, 8, 105, buttonFont:getHeight() + 16, "Sample")
    local slotHeight = lineHeight * 3 + buttonH + 24
    local headerHeight = lineHeight * 6
    local totalHeight = headerHeight + slotHeight * #self._slotOrder + lineHeight * 5
    local preferredWidth = 380
    return preferredWidth, totalHeight
end

function SaveSlots:draw(x, y, w, h)
    self:_ensureCache()

    local baseFont = Theme.fonts and Theme.fonts.normal or love.graphics.getFont()
    local buttonFont = (Theme.fonts and (Theme.fonts.tiny or Theme.fonts.small)) or baseFont
    local buttonPaddingX, buttonPaddingY = 18, 8
    local buttonMinWidth = 120
    local buttonMinHeight = buttonFont:getHeight() + buttonPaddingY * 2
    local lineHeight = baseFont:getHeight() + 4
    local currentY = y + 10
    local layout = {
        saveButton = nil,
        loadButton = nil,
        slots = {},
        autosaveLoad = nil
    }
    self._layout = layout

    -- Quick actions information
    Theme.setColor(Theme.colors.textSecondary)
    love.graphics.print("F5: Quick Save  |  F9: Quick Load", x + 10, currentY)
    currentY = currentY + lineHeight * 1.5

    local stats = StateManager.getStats() or {}
    local statusText = string.format("Auto-save: %s | Last save: %s",
        stats.autoSaveEnabled and "ON" or "OFF",
        stats.lastSave or "Never")
    love.graphics.print(statusText, x + 10, currentY)
    currentY = currentY + lineHeight * 2

    -- Instructions
    Theme.setColor(Theme.colors.accent)
    love.graphics.print("Select a slot, then choose Save or Load:", x + 10, currentY)
    currentY = currentY + lineHeight * 1.5

    local saveLabel = "Save Game"
    local loadLabel = "Load Game"
    local saveButtonW, saveButtonH = computeButtonSize(buttonFont, buttonPaddingX, buttonPaddingY, buttonMinWidth, buttonMinHeight, saveLabel)
    local loadButtonW, loadButtonH = computeButtonSize(buttonFont, buttonPaddingX, buttonPaddingY, buttonMinWidth, buttonMinHeight, loadLabel)
    local buttonSpacing = 14
    local buttonRowWidth = saveButtonW + loadButtonW + buttonSpacing
    local buttonRowX = x + math.max(10, (w - buttonRowWidth) / 2)

    local selectedSlotName = self:getSelectedSlotName()
    local hasSelectedSlot = selectedSlotName ~= nil
    local selectedSlotData = hasSelectedSlot and self._slotLookup[selectedSlotName] or nil

    drawButtonRect(buttonFont, buttonPaddingX, buttonPaddingY, buttonRowX, currentY, saveButtonW, saveButtonH, Theme.colors.success, saveLabel, hasSelectedSlot)
    layout.saveButton = { x = buttonRowX, y = currentY, w = saveButtonW, h = saveButtonH }

    drawButtonRect(buttonFont, buttonPaddingX, buttonPaddingY, buttonRowX + saveButtonW + buttonSpacing, currentY, loadButtonW, loadButtonH, Theme.colors.info, loadLabel, selectedSlotData ~= nil)
    layout.loadButton = { x = buttonRowX + saveButtonW + buttonSpacing, y = currentY, w = loadButtonW, h = loadButtonH }

    currentY = currentY + math.max(saveButtonH, loadButtonH) + lineHeight * 1.5

    -- Manual slots header
    Theme.setColor(Theme.colors.accent)
    love.graphics.print("Manual Slots:", x + 10, currentY)
    currentY = currentY + lineHeight

    local deleteLabel = "Delete"
    local deleteButtonW, deleteButtonH = computeButtonSize(buttonFont, buttonPaddingX, buttonPaddingY, math.max(105, loadButtonW), buttonMinHeight, deleteLabel)
    local slotPadding = 14
    local slotSpacing = 8
    local slotContentPadding = 12
    local slotHeight = lineHeight * 3 + deleteButtonH + slotPadding

    for index, slotName in ipairs(self._slotOrder) do
        local slotY = currentY
        local slotRect = { x = x + 10, y = slotY, w = w - 20, h = slotHeight }
        local slotData = self._slotLookup[slotName]
        local isSelected = (self.selectedSlot == index)

        local bgColor
        if isSelected then
            bgColor = Theme.colors.bg2
        elseif slotData then
            bgColor = Theme.colors.bg1
        else
            bgColor = Theme.withAlpha(Theme.colors.bg1, 0.6)
        end
        Theme.setColor(bgColor)
        love.graphics.rectangle("fill", slotRect.x, slotRect.y, slotRect.w, slotRect.h)

        local borderColor = isSelected and Theme.colors.accent or Theme.colors.border
        Theme.setColor(borderColor)
        love.graphics.rectangle("line", slotRect.x, slotRect.y, slotRect.w, slotRect.h)

        Theme.setColor(Theme.colors.text)
        love.graphics.print(string.format("Slot %d", index), slotRect.x + slotContentPadding, slotRect.y + 6)

        if slotData then
            Theme.setColor(Theme.colors.textSecondary)
            love.graphics.print(slotData.description or "Manual Save", slotRect.x + slotContentPadding, slotRect.y + lineHeight + 4)
            local infoText = string.format("Level %d | %d GC | %s",
                slotData.playerLevel or 1,
                slotData.playerCredits or 0,
                slotData.realTime or "Unknown")
            love.graphics.print(infoText, slotRect.x + slotContentPadding, slotRect.y + lineHeight * 2 + 4)
        else
            Theme.setColor(Theme.colors.textSecondary)
            love.graphics.print("Empty slot", slotRect.x + slotContentPadding, slotRect.y + lineHeight + 4)
            love.graphics.print("Click to select for saving", slotRect.x + slotContentPadding, slotRect.y + lineHeight * 2 + 4)
        end

        layout.slots[slotName] = {
            body = slotRect,
            index = index,
            delete = nil
        }

        if slotData then
            local deleteX = slotRect.x + slotRect.w - deleteButtonW - slotPadding
            local deleteY = slotRect.y + slotRect.h - deleteButtonH - slotPadding
            drawButtonRect(buttonFont, buttonPaddingX, buttonPaddingY, deleteX, deleteY, deleteButtonW, deleteButtonH, Theme.colors.danger, deleteLabel, true)
            layout.slots[slotName].delete = { x = deleteX, y = deleteY, w = deleteButtonW, h = deleteButtonH }
        end

        currentY = currentY + slotHeight + slotSpacing
    end

    currentY = currentY + lineHeight

    -- Quick save card if available
    local quicksave = self._slotLookup and self._slotLookup["quicksave"] or nil
    if quicksave then
        Theme.setColor(Theme.colors.accent)
        love.graphics.print("Quick Save:", x + 10, currentY)
        currentY = currentY + lineHeight

        local quickHeight = lineHeight * 2 + deleteButtonH + slotPadding
        local quickRect = { x = x + 10, y = currentY, w = w - 20, h = quickHeight }
        Theme.setColor(Theme.colors.bg1)
        love.graphics.rectangle("fill", quickRect.x, quickRect.y, quickRect.w, quickRect.h)
        Theme.setColor(Theme.colors.border)
        love.graphics.rectangle("line", quickRect.x, quickRect.y, quickRect.w, quickRect.h)

        Theme.setColor(Theme.colors.text)
        love.graphics.print(quicksave.description or "Quick Save", quickRect.x + slotContentPadding, quickRect.y + 6)
        Theme.setColor(Theme.colors.textSecondary)
        love.graphics.print(string.format("Level %d | %d GC | %s",
            quicksave.playerLevel or 1,
            quicksave.playerCredits or 0,
            quicksave.realTime or "Unknown"), quickRect.x + slotContentPadding, quickRect.y + lineHeight + 4)

        currentY = currentY + quickHeight + slotSpacing
    end

    -- Auto-save section (at bottom)
    Theme.setColor(Theme.colors.warning)
    love.graphics.print("Auto-Save:", x + 10, currentY)
    currentY = currentY + lineHeight

    local autosave = self._slotLookup and self._slotLookup["autosave"] or nil
    if autosave then
        local autosaveH = math.max(lineHeight * 2, deleteButtonH + slotPadding * 2)
        local autosaveRect = { x = x + 10, y = currentY, w = w - 20, h = autosaveH }

        Theme.setColor(Theme.colors.bg1)
        love.graphics.rectangle("fill", autosaveRect.x, autosaveRect.y, autosaveRect.w, autosaveRect.h)
        Theme.setColor(Theme.colors.border)
        love.graphics.rectangle("line", autosaveRect.x, autosaveRect.y, autosaveRect.w, autosaveRect.h)

        Theme.setColor(Theme.colors.text)
        love.graphics.print("Auto-save " .. (autosave.realTime or "Unknown"), autosaveRect.x + slotContentPadding, autosaveRect.y + 6)

        local autoInfo = string.format("Level %d | %d GC",
            autosave.playerLevel or 1,
            autosave.playerCredits or 0)
        Theme.setColor(Theme.colors.textSecondary)
        love.graphics.print(autoInfo, autosaveRect.x + slotContentPadding, autosaveRect.y + lineHeight + 4)

        local buttonY = autosaveRect.y + autosaveRect.h - deleteButtonH - slotPadding
        local autoLoadButtonX = autosaveRect.x + autosaveRect.w - deleteButtonW - slotPadding
        drawButtonRect(buttonFont, buttonPaddingX, buttonPaddingY, autoLoadButtonX, buttonY, deleteButtonW, deleteButtonH, Theme.colors.warning, loadLabel, true)
        layout.autosaveLoad = { x = autoLoadButtonX, y = buttonY, w = deleteButtonW, h = deleteButtonH }
    else
        Theme.setColor(Theme.colors.textSecondary)
        love.graphics.print("No auto-save available", x + 10, currentY)
    end
end

local function pointInRect(px, py, rect)
    if not rect then return false end
    return px >= rect.x and px <= rect.x + rect.w and py >= rect.y and py <= rect.y + rect.h
end

function SaveSlots:mousepressed(mx, my, button)
    if button ~= 1 then return false end

    self:_ensureCache()
    local layout = self._layout or {}
    local selectedSlotName = self:getSelectedSlotName()
    local selectedData = selectedSlotName and self._slotLookup and self._slotLookup[selectedSlotName] or nil

    if pointInRect(mx, my, layout.saveButton) then
        if not selectedSlotName then
            return "noop"
        end

        local description = string.format("Manual save - %s", os.date("%Y-%m-%d %H:%M:%S"))
        local success = StateManager.saveGame(selectedSlotName, description)
        if success then
            self._cacheDirty = true
            return "saved"
        end
        return "saveFailed"
    end

    if pointInRect(mx, my, layout.loadButton) then
        if not selectedSlotName or not selectedData then
            return "noop"
        end
        local loaded = StateManager.loadGame(selectedSlotName)
        if loaded then
            self._cacheDirty = true
            return "loaded"
        end
        return "loadFailed"
    end

    if layout.slots then
        for slotName, rects in pairs(layout.slots) do
            if pointInRect(mx, my, rects.delete) then
                local deleted = StateManager.deleteSave(slotName)
                if deleted then
                    if self:getSelectedSlotName() == slotName then
                        -- Keep selection on the slot index so player can immediately save again
                        self._cacheDirty = true
                    else
                        self._cacheDirty = true
                    end
                    return "deleted"
                end
                return "deleteFailed"
            end

            if pointInRect(mx, my, rects.body) then
                if rects.index then
                    self:setSelectedSlot(rects.index)
                    return "selected"
                end
            end
        end
    end

    if pointInRect(mx, my, layout.autosaveLoad) then
        local loaded = StateManager.loadGame("autosave")
        if loaded then
            return "autosaveLoaded"
        end
        return "loadFailed"
    end

    return false
end

function SaveSlots:textinput(_)
    return false
end

function SaveSlots:keypressed(_)
    return false
end

return SaveSlots
