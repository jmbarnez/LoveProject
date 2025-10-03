local Theme = require("src.core.theme")
local StateManager = require("src.managers.state_manager")
local UIUtils = require("src.ui.common.utils")
local Viewport = require("src.core.viewport")

local DEFAULT_SLOT_COUNT = 3

local SaveSlots = {}

function SaveSlots:new(options)
    local o = {}
    setmetatable(o, self)
    self.__index = self

    o.slotCount = options and options.slotCount or DEFAULT_SLOT_COUNT
    o.onClose = options and options.onClose
    o.disableSave = options and options.disableSave or false
    o.selectedSlot = nil -- numeric index (1-based)
    o._slotOrder = {}
    for i = 1, o.slotCount do
        o._slotOrder[i] = string.format("slot%d", i)
    end
    o._slotLookup = {}
    o._allSlots = {}
    o._cacheDirty = true

    -- Listen for global save/load/delete events and refresh cache so the UI
    -- reflects changes performed elsewhere in the app (or by this panel).
    local Events = require("src.core.events")
    Events.on("game_saved", function(data)
        if data and data.slotName and data.state and data.state.metadata then
            -- To avoid filesystem race conditions, immediately inject the new save data
            -- into the cache from the event payload. This makes the UI update instantly.
            -- _slotLookup and _allSlots are now initialized as empty tables in constructor

            local newSlotData = {
                name = data.slotName,
                description = data.state.metadata.description,
                timestamp = data.state.timestamp,
                realTime = data.state.realTime,
                playerLevel = data.state.metadata.playerLevel,
                playerCredits = data.state.metadata.playerCredits,
                playTime = data.state.metadata.playTime
            }

            -- Update or insert into the lookup table
            o._slotLookup[data.slotName] = newSlotData
            
            -- Update or insert into the list of all slots
            local found = false
            for i, slot in ipairs(o._allSlots) do
                if slot.name == data.slotName then
                    o._allSlots[i] = newSlotData
                    found = true
                    break
                end
            end
            if not found then
                table.insert(o._allSlots, newSlotData)
            end

            -- Re-sort the list by timestamp to ensure the new save is at the top
            table.sort(o._allSlots, function(a, b) return (a.timestamp or 0) > (b.timestamp or 0) end)

            -- The cache is now clean because we've manually updated it.
            -- This prevents _ensureCache from immediately overwriting our work
            -- with stale data from the filesystem.
            o._cacheDirty = false
        end
    end)
    Events.on("game_save_deleted", function(data)
        if data and data.slotName then
            o._cacheDirty = true
            o._slotLookup = {}
            o._allSlots = {}
            -- Don't call _ensureCache() immediately - let the next draw call handle it
        end
    end)

    return o
end

function SaveSlots:_ensureCache()
    -- If we saved within the last second, don't immediately re-read from disk,
    -- as the filesystem might not have caught up yet. The cache is already fresh.
    if self._lastSaveTimestamp and (love.timer.getTime() - self._lastSaveTimestamp < 1) then
        return
    end

    -- Only skip cache refresh if cache is not dirty AND slotLookup is already initialized
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
            if self._slotLookup and self._slotLookup[slotName] then
                self.selectedSlot = index
                break
            end
        end
        if not self.selectedSlot and slotCount > 0 then
            self.selectedSlot = 1
        end
    end
end

local function drawButtonRect(buttonFont, buttonPaddingX, buttonPaddingY, xPos, yPos, width, height, fillColor, label, enabled, hover)
    -- Enhanced hover effects
    local scaleX, scaleY = 1, 1
    local offsetX, offsetY = 0, 0
    if hover and enabled then
        scaleX = 1.02
        scaleY = 1.02
        offsetX = (width * (scaleX - 1)) * 0.5
        offsetY = (height * (scaleY - 1)) * 0.5
        xPos = xPos - offsetX
        yPos = yPos - offsetY
        width = width * scaleX
        height = height * scaleY
    end

    local color = enabled and fillColor or Theme.withAlpha(fillColor, 0.4)
    Theme.setColor(color)
    love.graphics.rectangle("fill", xPos, yPos, width, height)

    -- Add accent color glow for hover
    if hover and enabled then
        -- Draw accent color inner glow
        local accentGlow = {Theme.colors.accent[1], Theme.colors.accent[2], Theme.colors.accent[3], 0.7}
        Theme.setColor(accentGlow)
        love.graphics.rectangle("fill", xPos + 1, yPos + 1, width - 2, height - 2)
        
        -- Draw accent color border
        Theme.setColor(Theme.colors.accent)
        love.graphics.rectangle("line", xPos + 0.5, yPos + 0.5, width - 1, height - 1)
    end

    local textColor = enabled and Theme.colors.text or Theme.withAlpha(Theme.colors.text, 0.5)
    if hover and enabled then
        textColor = Theme.colors.textHighlight
    end
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
    local mx, my = Viewport.getMousePosition()
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
    local selectedSlotData = hasSelectedSlot and self._slotLookup and self._slotLookup[selectedSlotName] or nil

    local saveButtonEnabled = hasSelectedSlot and not self.disableSave
    local saveButtonColor = self.disableSave and Theme.colors.textSecondary or Theme.colors.success
    local saveButtonHover = mx >= buttonRowX and mx <= buttonRowX + saveButtonW and my >= currentY and my <= currentY + saveButtonH
    drawButtonRect(buttonFont, buttonPaddingX, buttonPaddingY, buttonRowX, currentY, saveButtonW, saveButtonH, saveButtonColor, saveLabel, saveButtonEnabled, saveButtonHover)
    layout.saveButton = { x = buttonRowX, y = currentY, w = saveButtonW, h = saveButtonH }

    local loadButtonEnabled = selectedSlotData ~= nil
    local loadButtonColor = selectedSlotData and Theme.colors.info or Theme.colors.textSecondary
    local loadButtonHover = mx >= buttonRowX + saveButtonW + buttonSpacing and mx <= buttonRowX + saveButtonW + buttonSpacing + loadButtonW and my >= currentY and my <= currentY + loadButtonH
    drawButtonRect(buttonFont, buttonPaddingX, buttonPaddingY, buttonRowX + saveButtonW + buttonSpacing, currentY, loadButtonW, loadButtonH, loadButtonColor, loadLabel, loadButtonEnabled, loadButtonHover)
    layout.loadButton = { x = buttonRowX + saveButtonW + buttonSpacing, y = currentY, w = loadButtonW, h = loadButtonH }
    
    -- Store the selected data in the layout for the mousepressed function
    layout.selectedSlotData = selectedSlotData

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
        local slotData = self._slotLookup and self._slotLookup[slotName] or nil
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
            local deleteButtonHover = mx >= deleteX and mx <= deleteX + deleteButtonW and my >= deleteY and my <= deleteY + deleteButtonH
            drawButtonRect(buttonFont, buttonPaddingX, buttonPaddingY, deleteX, deleteY, deleteButtonW, deleteButtonH, Theme.colors.danger, deleteLabel, true, deleteButtonHover)
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
        local autoLoadButtonHover = mx >= autoLoadButtonX and mx <= autoLoadButtonX + deleteButtonW and my >= buttonY and my <= buttonY + deleteButtonH
        drawButtonRect(buttonFont, buttonPaddingX, buttonPaddingY, autoLoadButtonX, buttonY, deleteButtonW, deleteButtonH, Theme.colors.warning, loadLabel, true, autoLoadButtonHover)
        layout.autosaveLoad = { x = autoLoadButtonX, y = buttonY, w = deleteButtonW, h = deleteButtonH }
    else
        Theme.setColor(Theme.colors.textSecondary)
        love.graphics.print("No auto-save available", x + 10, currentY)
    end
end

function SaveSlots:mousepressed(mx, my, button)
    if button ~= 1 then return false end

    self:_ensureCache()
    local layout = self._layout or {}
    local selectedSlotName = self:getSelectedSlotName()
    local selectedData = selectedSlotName and self._slotLookup and self._slotLookup[selectedSlotName] or nil

    if layout.saveButton and mx and my and UIUtils.pointInRect(mx, my, layout.saveButton) then
        if self.disableSave then
            return "noop"
        end
        if not selectedSlotName then
            return "noop"
        end

        local description = string.format("Manual save - %s", os.date("%Y-%m-%d %H:%M:%S"))
        local savedState = StateManager.saveGame(selectedSlotName, description)
        
        if savedState then
            -- Update the UI cache directly with the returned save data
            local newSlotData = {
                name = selectedSlotName,
                description = savedState.metadata.description,
                timestamp = savedState.timestamp,
                realTime = savedState.realTime,
                playerLevel = savedState.metadata.playerLevel,
                playerCredits = savedState.metadata.playerCredits,
                playTime = savedState.metadata.playTime
            }
            -- _slotLookup and _allSlots are now initialized as empty tables in constructor
            self._slotLookup[selectedSlotName] = newSlotData
            local found = false
            for i, slot in ipairs(self._allSlots) do
                if slot.name == selectedSlotName then
                    self._allSlots[i] = newSlotData
                    found = true
                    break
                end
            end
            if not found then
                table.insert(self._allSlots, newSlotData)
            end
            table.sort(self._allSlots, function(a, b) return (a.timestamp or 0) > (b.timestamp or 0) end)
            
            -- Cache is now clean, and we should not immediately re-read from disk
            self._cacheDirty = false

            -- Add a timestamp to prevent stale data from being loaded if the panel
            -- is quickly closed and reopened before the filesystem write completes.
            self._lastSaveTimestamp = love.timer.getTime()

            local Notifications = require("src.ui.notifications")
            Notifications.add("Game saved to slot " .. selectedSlotName, "action")
            return "saved"
        else
            local Notifications = require("src.ui.notifications")
            Notifications.add("Failed to save game", "error")
            return "saveFailed"
        end
    end

    if layout.loadButton and mx and my and UIUtils.pointInRect(mx, my, layout.loadButton) then
        if not selectedSlotName then
            local Notifications = require("src.ui.notifications")
            Notifications.add("Please select a slot first", "warning")
            return "noop"
        end
        if not layout.selectedSlotData then
            local Notifications = require("src.ui.notifications")
            Notifications.add("No save data in slot " .. selectedSlotName, "warning")
            return "noop"
        end
        local success, error = pcall(StateManager.loadGame, selectedSlotName)
        if success and error then
            self._cacheDirty = true
            -- Mark cache as dirty - it will refresh on next draw call
            self._slotLookup = {}
            self._allSlots = {}
            -- Show success notification
            local Notifications = require("src.ui.notifications")
            Notifications.add("Game loaded from slot " .. selectedSlotName, "info")
            return "loaded"
        end
        -- Show failure notification with better error details
        local Notifications = require("src.ui.notifications")
        if not success then
            Notifications.add("Load failed: " .. tostring(error), "error")
        else
            Notifications.add("Save file corrupted or incompatible", "error")
        end
        return "loadFailed"
    end

    if layout.slots then
        for slotName, rects in pairs(layout.slots) do
            if rects and rects.delete and mx and my and UIUtils.pointInRect(mx, my, rects.delete) then
                local deleted = StateManager.deleteSave(slotName)
                if deleted then
                    if self:getSelectedSlotName() == slotName then
                        -- Keep selection on the slot index so player can immediately save again
                        self._cacheDirty = true
                    else
                        self._cacheDirty = true
                    end
                    -- Mark cache as dirty - it will refresh on next draw call
                    self._slotLookup = {}
                    self._allSlots = {}
                    -- Show success notification
                    local Notifications = require("src.ui.notifications")
                    Notifications.add("Save slot " .. slotName .. " deleted", "info")
                    return "deleted"
                end
                -- Show failure notification
                local Notifications = require("src.ui.notifications")
                Notifications.add("Failed to delete save slot", "error")
                return "deleteFailed"
            end

            if rects and rects.body and mx and my and UIUtils.pointInRect(mx, my, rects.body) then
                if rects.index then
                    self:setSelectedSlot(rects.index)
                    return "selected"
                end
            end
        end
    end

    if layout.autosaveLoad and mx and my and UIUtils.pointInRect(mx, my, layout.autosaveLoad) then
        local success, error = pcall(StateManager.loadGame, "autosave")
        if success and error then
            -- Mark cache as dirty - it will refresh on next draw call
            self._cacheDirty = true
            self._slotLookup = {}
            self._allSlots = {}
            -- Show success notification
            local Notifications = require("src.ui.notifications")
            Notifications.add("Auto-save loaded", "info")
            return "autosaveLoaded"
        end
        -- Show failure notification with better error details
        local Notifications = require("src.ui.notifications")
        if not success then
            Notifications.add("Auto-save load failed: " .. tostring(error), "error")
        else
            Notifications.add("Auto-save file corrupted or missing", "error")
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
