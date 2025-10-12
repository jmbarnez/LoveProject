local Theme = require("src.core.theme")
local UIUtils = require("src.ui.common.utils")
local Util = require("src.core.util")
local Viewport = require("src.core.viewport")
local HotbarSystem = require("src.systems.hotbar")
local HotbarUI = require("src.ui.hud.hotbar")
local ShipUtils = require("src.ui.ship.utils")

local DrawShip = {}

function DrawShip.render(state, player, x, y, w, h)
    if not player then
        state.activeContentBounds = nil
        return
    end

    if not x or not y or not w or not h then
        state.activeContentBounds = nil
        return
    end

    state.activeContentBounds = {
        x = x,
        y = y,
        w = w,
        h = h
    }

    local pad = (Theme.ui and Theme.ui.contentPadding) or 16
    local cx, cy = x + pad, y + pad
    local headerHeight = 60

    Theme.drawGradientGlowRect(cx, cy, w - pad * 2, headerHeight, 6,
        Theme.colors.bg2, Theme.colors.bg1, Theme.colors.accent, Theme.effects.glowWeak)

    local iconSize = 48
    local iconX, iconY = cx + 8, cy + 6

    Theme.setColor(Theme.colors.accent)
    love.graphics.circle("line", iconX + iconSize / 2, iconY + iconSize / 2, iconSize / 2 - 2)
    Theme.setColor(Theme.colors.textSecondary)
    love.graphics.printf("SHIP", iconX, iconY + iconSize / 2 - 6, iconSize, "center")

    local infoX = iconX + iconSize + 12
    Theme.setColor(Theme.colors.textHighlight)
    Theme.setFont("medium")
    local shipName = player.name or (player.ship and player.ship.name) or "Unknown Ship"
    love.graphics.print(shipName, infoX, iconY + 2)

    Theme.setColor(Theme.colors.text)
    Theme.setFont("small")
    local shipClass = player.class or (player.ship and player.ship.class) or "Unknown Class"
    love.graphics.print("Class: " .. shipClass, infoX, iconY + 22)

    local docking = player.components and player.components.docking_status
    local isDocked = docking and docking.docked
    local statusColor = isDocked and Theme.colors.success or Theme.colors.warning
    local statusText = isDocked and "DOCKED - Fitting Available" or "UNDOCKED - Fitting Locked"
    Theme.setColor(statusColor)
    love.graphics.print(statusText, infoX, iconY + 36)

    cy = cy + headerHeight + 20

    local gridSlots = (player.components and player.components.equipment and player.components.equipment.grid) or {}
    local availableWidth = w - pad * 2
    local statsWidth = math.min(320, math.floor(availableWidth * 0.4))
    local spacing = 24
    local gridWidth = availableWidth - statsWidth - spacing
    if gridWidth < 480 then
        gridWidth = 480
        statsWidth = availableWidth - gridWidth - spacing
    end

    local gridHeight = h - headerHeight - 40

    Theme.drawGradientGlowRect(cx, cy, w - pad * 2, gridHeight, 6,
        Theme.colors.bg1, Theme.colors.bg0, Theme.colors.border, Theme.effects.glowWeak)

    local statsX = cx + 8
    local statsY = cy + 12
    local statsInnerWidth = statsWidth - 16
    local statsViewHeight = gridHeight - 24

    Theme.setColor(Theme.colors.bg2)
    love.graphics.rectangle("fill", statsX, statsY, statsInnerWidth, statsViewHeight, 4, 4)

    local hComp = player.components and player.components.health or {}
    local statsList = {}
    if hComp.maxHP and hComp.maxHP > 0 then
        table.insert(statsList, { label = "Hull HP", value = hComp.maxHP, color = Theme.colors.statusHull })
    end
    if hComp.maxShield and hComp.maxShield > 0 then
        table.insert(statsList, { label = "Shield HP", value = hComp.maxShield, color = Theme.colors.statusShield })
    end
    if hComp.maxEnergy and hComp.maxEnergy > 0 then
        table.insert(statsList, { label = "Capacitor", value = hComp.maxEnergy, color = Theme.colors.statusCapacitor })
    end

    local lineHeight = 22
    local statsContentHeight = 26 + (#statsList * lineHeight) + 16
    local statsClipX, statsClipY, statsClipW, statsClipH = statsX, statsY, statsInnerWidth, statsViewHeight
    local statsViewInnerHeight = math.max(0, statsClipH - 24)
    local statsMinScroll = math.min(0, statsViewInnerHeight - statsContentHeight)
    state.statsScroll = Util.clamp(state.statsScroll or 0, statsMinScroll, 0)
    local statsScroll = state.statsScroll

    love.graphics.setScissor(statsClipX, statsClipY, statsClipW, statsClipH)
    love.graphics.push()
    love.graphics.translate(0, statsScroll)

    local contentX = statsX + 12
    local contentY = statsY + 12

    Theme.setColor(Theme.colors.textHighlight)
    Theme.setFont("medium")
    love.graphics.print("Ship Stats", contentX, contentY)

    contentY = contentY + 26
    Theme.setFont("small")

    for _, statData in ipairs(statsList) do
        Theme.setColor(Theme.colors.textSecondary)
        love.graphics.print(statData.label .. ":", contentX, contentY)
        Theme.setColor(statData.color or Theme.colors.text)
        local valueStr = statData.value
        if type(statData.value) == "number" and statData.value >= 1000 then
            valueStr = string.format("%.1fk", statData.value / 1000)
        end
        love.graphics.print(tostring(valueStr), contentX + 110, contentY)
        contentY = contentY + lineHeight
    end

    love.graphics.pop()
    love.graphics.setScissor()
    state.statsViewRect = {
        x = statsClipX,
        y = statsClipY,
        w = statsClipW,
        h = statsClipH,
        minScroll = statsMinScroll
    }

    local gridX = statsX + statsWidth + spacing
    local gridY = cy + 12

    local hotbarPreviewHeight = 80
    local hotbarPreviewWidth = gridWidth - 16
    Theme.setColor(Theme.colors.bg2)
    love.graphics.rectangle("fill", gridX, gridY, hotbarPreviewWidth, hotbarPreviewHeight, 4, 4)

    local slotSize = 40
    local slotGap = 14
    local slotsY = gridY + 32
    local slotsX = gridX + 12
    local hotbarPreview = ShipUtils.buildHotbarPreview(player)
    for slotIndex = 1, #HotbarSystem.slots do
        local sx = slotsX + (slotIndex - 1) * (slotSize + slotGap)
        Theme.setColor(Theme.colors.bg1)
        love.graphics.rectangle("fill", sx, slotsY, slotSize, slotSize, 4, 4)

        local keyLabel = UIUtils.formatKeyLabel(HotbarSystem.getSlotKey and HotbarSystem.getSlotKey(slotIndex), "Unbound")
        Theme.setColor(Theme.colors.textSecondary)
        Theme.setFont("small")
        love.graphics.printf(keyLabel, sx, slotsY - 18, slotSize, "center")

        local previewEntry = hotbarPreview[slotIndex]
        if previewEntry and previewEntry.item then
            local entryLabel = previewEntry.label or previewEntry.item
            if previewEntry.origin == "preferred" then
                Theme.setColor(Theme.colors.textHighlight)
            elseif previewEntry.origin == "auto" then
                Theme.setColor(Theme.colors.text)
            else
                Theme.setColor(Theme.colors.textSecondary)
            end

            if previewEntry.gridIndex and player.components and player.components.equipment and player.components.equipment.grid[previewEntry.gridIndex] then
                local gridEntry = player.components.equipment.grid[previewEntry.gridIndex]
                Theme.setColor(Theme.colors.text)
                local iconSize = slotSize - 6
                HotbarUI.drawTurretIcon(gridEntry.module or ShipUtils.resolveModuleDisplayName(gridEntry), sx + 3, slotsY + 3, iconSize)
            elseif entryLabel then
                love.graphics.printf(entryLabel, sx - 30, slotsY + slotSize * 0.5 - 6, slotSize + 60, "center")
            end
        end
    end

    local infoY = gridY + hotbarPreviewHeight + 8
    gridY = infoY + 20
    local gridPanelWidth = gridWidth - 16
    local slotPanelHeight = gridHeight - (gridY - (cy + 12)) - 24
    Theme.setColor(Theme.colors.bg2)
    love.graphics.rectangle("fill", gridX, gridY, gridPanelWidth, slotPanelHeight, 4, 4)

    Theme.setColor(Theme.colors.textHighlight)
    Theme.setFont("medium")
    love.graphics.print("Fitting Slots", gridX + 12, gridY + 12)

    Theme.setFont("small")
    local labelFont = Theme.getFont("small")
    local labelHeights = {}
    local slotClipX = gridX + 4
    local slotClipY = gridY + 40
    local slotClipW = gridPanelWidth - 8
    local slotClipH = math.max(40, slotPanelHeight - 40)
    local maxLabelWidthAvailable = math.max(1, slotClipW - 24)

    local slotBaseY = gridY + 44
    local slotCursor = slotBaseY
    local lastSlotType = nil
    local rowSpacing = 20
    for i, slotData in ipairs(gridSlots) do
        local slotType = ShipUtils.resolveSlotType(slotData) or "module"
        if lastSlotType ~= slotType then
            slotCursor = slotCursor + 30
            lastSlotType = slotType
        end
        local dropdown = state.slotDropdowns and state.slotDropdowns[i]
        local optionHeight = (dropdown and dropdown.optionHeight) or 24
        local labelText = ""
        if slotType ~= "turret" then
            labelText = ((slotData and slotData.label) or ("Slot " .. i)) .. ":"
        end
        -- No label height needed since we removed the labels
        -- No extra height needed since buttons are now inline
        slotCursor = slotCursor + optionHeight + rowSpacing
    end
    local slotContentHeight = slotCursor - slotBaseY + 16
    local slotViewInnerHeight = math.max(0, slotClipH - 16)
    local slotMinScroll = math.min(0, slotViewInnerHeight - slotContentHeight)
    state.slotScroll = Util.clamp(state.slotScroll or 0, slotMinScroll, 0)
    local slotScroll = state.slotScroll

    love.graphics.setScissor(slotClipX, slotClipY, slotClipW, slotClipH)
    local slotY = slotBaseY
    local currentSlotHeader = nil
    local mx, my = Viewport.getMousePosition()

    for i, slotData in ipairs(gridSlots) do
        local slotType = ShipUtils.resolveSlotType(slotData) or "module"
        if currentSlotHeader ~= slotType then
            Theme.setColor(Theme.colors.textHighlight)
            Theme.setFont("medium")
            love.graphics.print(ShipUtils.resolveSlotHeaderLabel(slotType), gridX + 12, slotY + slotScroll)
            slotY = slotY + 30
            currentSlotHeader = slotType
        end

            local dropdown = state.slotDropdowns and state.slotDropdowns[i]
            if dropdown then
                local drawY = slotY + slotScroll
                
                -- Calculate layout with slot number on the left
                local slotNumberWidth = 40 -- Space for slot number
                local availableWidth = slotClipW - 24 - slotNumberWidth
                local controlsY = drawY

            -- Draw slot number on the left
            Theme.setColor(Theme.colors.textSecondary)
            Theme.setFont("small")
            local slotNumberText = tostring(i)
            love.graphics.printf(slotNumberText, gridX + 12, controlsY + 6, slotNumberWidth, "center")

            -- Calculate button sizes - all buttons same height as dropdown
            local buttonHeight = dropdown.optionHeight
            local buttonWidth = buttonHeight -- Square buttons for A and remove
            local totalButtonWidth = (buttonWidth * 2) + 16 -- 2 buttons + spacing
            local dropdownWidth = math.max(200, availableWidth - totalButtonWidth) -- Ensure minimum dropdown width

            -- Position dropdown to the right of slot number
            local dropdownX = gridX + 12 + slotNumberWidth + 8
            dropdown:setPosition(dropdownX, controlsY)
            dropdown.width = dropdownWidth

            local dropdownHover = dropdown:isPointInButton(mx, my)
            local optionsHover = false

            if dropdown.open then
                dropdown:mousemoved(mx, my)
                for j = 1, #dropdown.options do
                    if dropdown:isPointInOption(mx, my, j) then
                        optionsHover = true
                        break
                    end
                end

                if not optionsHover then
                    local dropdownY = dropdown._dropdownY or (dropdown.y + dropdown.optionHeight + 2)
                    local dropdownX = dropdown.x
                    local dropdownW = dropdown.width
                    local dropdownH = dropdown.dropdownHeight

                    if mx >= dropdownX and mx <= dropdownX + dropdownW and
                       my >= dropdownY and my <= dropdownY + dropdownH then
                        optionsHover = true
                    end
                end
            end

            -- Only close dropdowns on mouse movement, don't open them on hover
            if dropdown.open and not dropdownHover and not optionsHover then
                local dropdownY = dropdown._dropdownY or (dropdown.y + dropdown.optionHeight + 2)
                local totalDropdownHeight = dropdown.optionHeight + dropdown.dropdownHeight + 2
                local isOutsideDropdown = not (mx >= dropdown.x and mx <= dropdown.x + dropdown.width and
                    my >= dropdown.y and my <= dropdown.y + totalDropdownHeight)

                if isOutsideDropdown then
                    dropdown.open = false
                end
            end

            dropdown:drawButtonOnly(mx, my)

            -- Position buttons inline with dropdown
            local autoButtonX = dropdownX + dropdownWidth + 8
            local removeButtonX = autoButtonX + buttonWidth + 8

            -- Draw Auto button (A) for turrets
            local hotbarButton = state.hotbarButtons and state.hotbarButtons[i]
            if slotType == "turret" and hotbarButton then
                local autoRect = { x = autoButtonX, y = controlsY, w = buttonWidth, h = buttonHeight }
                local autoHover = mx and my and UIUtils.pointInRect(mx, my, autoRect)

                hotbarButton.rect = autoRect
                hotbarButton.hover = autoHover
                Theme.setColor(autoHover and Theme.colors.hover or Theme.colors.bg1)
                love.graphics.rectangle("fill", autoRect.x, autoRect.y, autoRect.w, autoRect.h, 4, 4)
                Theme.setColor(Theme.colors.textSecondary)
                love.graphics.printf("A", autoRect.x, autoRect.y + 6, autoRect.w, "center")
            end

            -- Draw Remove button (-) for all slots
            local removeButton = state.removeButtons and state.removeButtons[i]
            if removeButton then
                local removeRect = { x = removeButtonX, y = controlsY, w = buttonWidth, h = buttonHeight }
                local removeHover = mx and my and UIUtils.pointInRect(mx, my, removeRect)

                removeButton.rect = removeRect
                removeButton.hover = removeHover
                Theme.setColor(removeHover and Theme.colors.error or Theme.colors.bg1)
                love.graphics.rectangle("fill", removeRect.x, removeRect.y, removeRect.w, removeRect.h, 4, 4)
                Theme.setColor(Theme.colors.text)
                love.graphics.printf("-", removeRect.x, removeRect.y + 4, removeRect.w, "center")
            end

            slotY = slotY + dropdown.optionHeight + rowSpacing
        end
    end

    love.graphics.setScissor()
    state.slotViewRect = {
        x = slotClipX,
        y = slotClipY,
        w = slotClipW,
        h = slotClipH,
        minScroll = slotMinScroll
    }
end

function DrawShip.drawDropdownOptions(state)
    local mx, my = Viewport.getMousePosition()
    if not state.slotDropdowns then return end
    for _, dropdown in ipairs(state.slotDropdowns) do
        if dropdown.open then
            dropdown:drawOptionsOnly(mx, my)
        end
    end
end

return DrawShip
