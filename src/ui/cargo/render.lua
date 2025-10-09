local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local Util = require("src.core.util")
local Content = require("src.content.content")
local IconSystem = require("src.core.icon_system")
local TooltipManager = require("src.ui.tooltip_manager")
local Items = require("src.ui.cargo.items")

local Render = {}
local CARGO_SLOT_SIZE = 48

local function drawSearchBar(x, y, w, h, searchText, isActive)
    local padding = 4
    local searchW = w - h - padding
    local searchH = h - padding * 2

    local bgColor = isActive and Theme.colors.bg3 or Theme.colors.bg2
    Theme.drawGradientGlowRect(x, y, searchW, h, 4, bgColor, Theme.withAlpha(Theme.colors.bg0, 0.2), Theme.colors.border, 0)

    local iconSize = h - 8
    local iconX = x + 4
    local iconY = y + 4
    Theme.setColor(Theme.colors.textSecondary)
    Theme.setFont("small")

    if not isActive then
        love.graphics.print("Search", iconX, iconY)
    end

    local textX = iconX + iconSize + 4
    local textY = y + (h - searchH) / 2
    local displayText = searchText
    if isActive and math.floor(love.timer.getTime() * 2) % 2 == 0 then
        displayText = displayText .. "_"
    end

    Theme.setColor(Theme.colors.text)
    love.graphics.print(displayText, textX, textY)

    return { x = x, y = y, w = searchW, h = h }
end

local function drawSortButton(x, y, w, h, sortBy, sortOrder)
    Theme.drawGradientGlowRect(x, y, w, h, 4, Theme.colors.bg2, Theme.withAlpha(Theme.colors.bg0, 0.2), Theme.colors.border, 0)

    local icon = sortOrder == "asc" and "↑" or "↓"
    local sortNames = {name = "Name", type = "Type", rarity = "Rarity", value = "Value", quantity = "Qty"}

    Theme.setFont("small")
    Theme.setColor(Theme.colors.text)

    local text = sortNames[sortBy] or "Name"
    local iconWidth = love.graphics.getFont():getWidth(icon)

    love.graphics.print(text, x + 4, y + (h - 12) / 2)
    love.graphics.print(icon, x + w - iconWidth - 4, y + (h - 12) / 2)

    return { x = x, y = y, w = w, h = h }
end

local function drawAdvancedScrollbar(x, y, w, h, scroll, maxScroll, isHovered)
    local scrollbarWidth = 12
    local scrollbarX = x + w - scrollbarWidth - 2

    Theme.setColor(Theme.withAlpha(Theme.colors.bg0, 0.5))
    love.graphics.rectangle("fill", scrollbarX, y, scrollbarWidth, h)

    if maxScroll > 0 then
        local thumbHeight = math.max(20, h * (h / (h + maxScroll)))
        local thumbY = y + (h - thumbHeight) * (scroll / maxScroll)

        local thumbGradientStart = isHovered and Theme.withAlpha(Theme.colors.bg3, 0.8) or Theme.withAlpha(Theme.colors.bg2, 0.8)
        local thumbGradientEnd = isHovered and Theme.withAlpha(Theme.colors.bg4, 0.6) or Theme.withAlpha(Theme.colors.bg3, 0.6)

        Theme.drawVerticalGradient(scrollbarX + 2, thumbY, scrollbarWidth - 4, thumbHeight, thumbGradientStart, thumbGradientEnd)

        Theme.setColor(Theme.colors.border)
        love.graphics.rectangle("line", scrollbarX + 2, thumbY, scrollbarWidth - 4, thumbHeight)

        return { x = scrollbarX, y = thumbY, w = scrollbarWidth, h = thumbHeight }
    end

    return nil
end

local function drawEnhancedItemSlot(item, x, y, size, isHovered, isSelected)
    local padding = 4
    local baseIconSize = size - padding * 2
    local scale = isHovered and 1.08 or 1.0
    local iconSize = math.min(size - 2, baseIconSize * scale)
    local iconInset = (size - iconSize) * 0.5
    local iconX = x + iconInset
    local iconY = y + iconInset

    local bgColor = Theme.withAlpha(Theme.colors.bg1, 0.3)
    if isSelected then
        bgColor = Theme.colors.selection
    end

    Theme.drawGradientGlowRect(x, y, size, size, 4, bgColor, Theme.withAlpha(Theme.colors.bg0, 0.2), Theme.colors.border, 0, false)

    local def = Items.getItemDefinition(item)
    local canonicalItem = Content.getItem(item.id)
    local canonicalTurret = Content.getTurret(item.id)

    local iconCandidates = {
        item.turretData,
        item.meta,
        def ~= item.turretData and def or nil,
        def and def.module or nil,
        def and def._sourceData or nil,
        canonicalItem ~= def and canonicalItem or nil,
        canonicalItem and canonicalItem.def or nil,
        canonicalTurret ~= def and canonicalTurret or nil,
        canonicalTurret and canonicalTurret.module or nil,
        canonicalTurret and canonicalTurret._sourceData or nil,
        item.id,
    }

    local iconDrawn = IconSystem.drawIconAny(iconCandidates, iconX, iconY, iconSize, 1.0)

    if not iconDrawn then
        local fallbackIcon = IconSystem.getIcon(def)
        if fallbackIcon then
            IconSystem.drawIcon(def, iconX, iconY, iconSize, 1.0)
            iconDrawn = true
        end
    end

    if not iconDrawn then
        local prevColor = { love.graphics.getColor() }
        Theme.setColor(Theme.colors.textSecondary)
        Theme.setFont("small")
        love.graphics.printf(def and def.name or item.id, iconX, iconY + iconSize * 0.4, iconSize, "center")
        love.graphics.setColor(prevColor[1] or 1, prevColor[2] or 1, prevColor[3] or 1, prevColor[4] or 1)
    end

    if not item.turretData and item.qty > 1 then
        local stackCount = Util.formatNumber(item.qty)
        local font = Theme.getFont("small")
        Theme.setFont("small")
        local textW = font:getWidth(stackCount)
        local textH = font:getHeight()

        Theme.setColor(Theme.withAlpha(Theme.colors.bg0, 0.8))
        love.graphics.rectangle("fill", iconX + iconSize - textW - 6, iconY + iconSize - textH - 4, textW + 4, textH + 2)

        Theme.setColor(Theme.colors.accent)
        love.graphics.print(stackCount, iconX + iconSize - textW - 4, iconY + iconSize - textH - 3)
    end

    if def and def.rarity then
        local rarityColor = Theme.colors.rarity and Theme.colors.rarity[def.rarity] or Theme.colors.accent
        local prevColor = { love.graphics.getColor() }
        local dotSize = math.max(3, math.floor(size * 0.12))

        Theme.setColor(rarityColor)
        love.graphics.circle("fill", x + 2 + dotSize / 2, y + 2 + dotSize / 2, dotSize / 2)

        Theme.setColor(Theme.withAlpha(Theme.colors.bg0, 0.8))
        love.graphics.setLineWidth(1)
        love.graphics.circle("line", x + 2 + dotSize / 2, y + 2 + dotSize / 2, dotSize / 2)
        love.graphics.setLineWidth(1)
        love.graphics.setColor(prevColor[1] or 1, prevColor[2] or 1, prevColor[3] or 1, prevColor[4] or 1)
    end
end

function Render.drawPanel(state, player, x, y, w, h)
    local mx, my = Viewport.getMousePosition()

    local headerHeight = 36
    local headerPadding = 8
    local sortWidth = 108
    local searchHeight = math.max(20, headerHeight - headerPadding * 2)

    Theme.drawGradientGlowRect(x, y, w, headerHeight, 4, Theme.colors.bg2, Theme.colors.bg1, Theme.colors.border, Theme.effects.glowWeak)

    local searchWidth = w - sortWidth - (headerPadding * 3)
    if searchWidth < 120 then
        searchWidth = w - headerPadding * 2
        sortWidth = 0
    end

    state._searchRect = drawSearchBar(x + headerPadding, y + headerPadding, searchWidth, searchHeight, state.searchText, state._searchInputActive)
    if sortWidth > 0 then
        state._sortRect = drawSortButton(x + w - sortWidth - headerPadding, y + headerPadding, sortWidth, searchHeight, state.sortBy, state.sortOrder)
    else
        state._sortRect = nil
    end

    local items = Items.getPlayerItems(player)
    items = Items.filter(items, state.searchText)
    Items.sort(items, state.sortBy, state.sortOrder)

    local iconSize = CARGO_SLOT_SIZE
    local padding = (Theme.ui and Theme.ui.contentPadding) or 8
    local contentY = y + headerHeight + padding * 0.5
    local footerHeight = 24
    local contentH = h - headerHeight - footerHeight

    local iconsPerRow = math.floor((w - padding) / (iconSize + padding))
    if iconsPerRow < 1 then iconsPerRow = 1 end

    local totalRows = math.ceil(#items / iconsPerRow)
    local totalContentHeight = totalRows * (iconSize + padding) + padding
    state._scrollMax = math.max(0, totalContentHeight - contentH)
    if state.scroll > state._scrollMax then state.scroll = state._scrollMax end

    love.graphics.push()
    love.graphics.setScissor(x, contentY, w, contentH)
    state._slotRects = {}

    for index, item in ipairs(items) do
        local row = math.floor((index - 1) / iconsPerRow)
        local col = (index - 1) % iconsPerRow
        local itemX = x + col * (iconSize + padding) + padding
        local itemY = contentY + row * (iconSize + padding) + padding - state.scroll

        if itemY + iconSize > contentY and itemY < contentY + contentH then
            local isHovered = mx >= itemX and mx <= itemX + iconSize and my >= itemY and my <= itemY + iconSize
            drawEnhancedItemSlot(item, itemX, itemY, iconSize, isHovered, false)

            state._slotRects[#state._slotRects + 1] = { x = itemX, y = itemY, w = iconSize, h = iconSize, item = item, index = index }

            if isHovered then
                if not state.hoveredItem or state.hoveredItem.id ~= item.id then
                    state.hoveredItem = item
                    state.hoverTimer = 0
                else
                    state.hoverTimer = state.hoverTimer + love.timer.getDelta()
                end
            end
        end
    end

    if state._scrollMax > 0 then
        local scrollbarWidth = 12
        local scrollbarX = x + w - scrollbarWidth - 2
        local scrollbarY = contentY
        local scrollbarHeight = contentH

        local scrollbarHover = mx >= scrollbarX and mx <= scrollbarX + scrollbarWidth and my >= scrollbarY and my <= scrollbarY + scrollbarHeight
        local thumbRect = drawAdvancedScrollbar(x, contentY, w, contentH, state.scroll, state._scrollMax, scrollbarHover)
        if state._scrollDragging and thumbRect then
            state._scrollThumbRect = thumbRect
        end
    end

    love.graphics.setScissor()
    love.graphics.pop()

    local infoBarHeight = footerHeight - 6
    local infoBarY = y + h - infoBarHeight
    Theme.drawGradientGlowRect(x, infoBarY, w, infoBarHeight, 4, Theme.colors.bg2, Theme.colors.bg1, Theme.colors.border, Theme.effects.glowWeak)

    local cargoComponent = player.components and player.components.cargo
    local currentVolume = cargoComponent and cargoComponent:getCurrentVolume() or 0
    local volumeLimit = cargoComponent and cargoComponent:getVolumeLimit() or math.huge
    local volumeText
    if volumeLimit == math.huge then
        volumeText = string.format("Volume: %.1f m³", currentVolume)
    else
        volumeText = string.format("Volume: %.1f/%.1f m³", currentVolume, volumeLimit)
    end

    Theme.setFont("small")
    Theme.setColor(Theme.colors.textSecondary)
    love.graphics.print(volumeText, x + 8, infoBarY + 3)

    local credits = player.getGC and player:getGC() or 0
    local creditText = Util.formatNumber(credits)
    local font = Theme.getFont("small")
    local creditWidth = font:getWidth(creditText)
    local currencyIconSize = 12
    local iconSpacing = 4
    local totalWidth = creditWidth + currencyIconSize + iconSpacing

    Theme.setColor(Theme.colors.accentGold)
    love.graphics.print(creditText, x + w - totalWidth - 8, infoBarY + 3)

    local iconX = x + w - currencyIconSize - 8
    local iconY = infoBarY + (infoBarHeight - currencyIconSize) / 2
    Theme.drawCurrencyToken(iconX, iconY, currencyIconSize)

    if state.hoveredItem and state.hoverTimer > 0.1 and not state.contextMenu.visible then
        local def = state.hoveredItem.turretData or Items.getItemDefinition(state.hoveredItem)
        if not def then
            def = Content.getItem(state.hoveredItem.id) or Content.getTurret(state.hoveredItem.id)
        end
        if def then
            TooltipManager.setTooltip(def, mx, my)
        end
    else
        TooltipManager.clearTooltip()
    end
end

function Render.getItemAtPosition(slotRects, x, y)
    if not slotRects then return nil, nil end
    for _, slot in ipairs(slotRects) do
        if x >= slot.x and x <= slot.x + slot.w and y >= slot.y and y <= slot.y + slot.h then
            return slot.item, slot.index
        end
    end
    return nil, nil
end

return Render
