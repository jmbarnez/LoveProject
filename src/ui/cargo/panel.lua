local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local Content = require("src.content.content")
local Input = require("src.core.input")
local Util = require("src.core.util")
local Tooltip = require("src.ui.tooltip")
local IconSystem = require("src.core.icon_system")
local AuroraTitle = require("src.shaders.aurora_title")
local PlayerRef = require("src.core.player_ref")
local Window = require("src.ui.common.window")
local CargoState = require("src.ui.cargo.state")

local CARGO_SLOT_SIZE = 48
local Cargo = CargoState.get()

local function hasEmptyEquipmentSlot(player)
  local grid = player.components and player.components.equipment and player.components.equipment.grid
  if not grid then return false end
  for _, slot in ipairs(grid) do
    if not slot.id then
      return true
    end
  end
  return false
end

local function pickCrateReward()
    local candidates = {}
    for _, item in ipairs(Content.items or {}) do
        if item.id ~= "reward_crate_key" then
            table.insert(candidates, item)
        end
    end
    if #candidates == 0 then
        return nil, 0
    end
    local choice = candidates[math.random(1, #candidates)]
    local maxStack = (choice.stack and choice.stack > 0) and choice.stack or 1
    local qty = 1
    if maxStack > 1 then
        qty = math.random(1, math.min(maxStack, 3))
    end
    return choice, qty
end

local snapshotCargoState
local cargoStateChanged

-- Helper function to get current player safely
local function getCurrentPlayer()
  return PlayerRef.get and PlayerRef.get() or nil
end

local function setSearchActive(active)
  CargoState.setSearchActive(active)
end

function Cargo.clearSearchFocus()
  CargoState.clearSearchFocus()
end

function Cargo.isSearchInputActive()
  return CargoState.isSearchInputActive()
end

function Cargo.init()
    Cargo.window = Window.new({
        title = "Cargo",
        width = 520,
        height = 400,
        minWidth = 300,
        minHeight = 200,
        useLoadPanelTheme = true,
        draggable = true,
        closable = true,
        drawContent = Cargo.drawContent,
        onClose = function()
            Cargo.visible = false
            setSearchActive(false)
            -- Play close sound
            local Sound = require("src.core.sound")
            Sound.triggerEvent('ui_button_click')
        end
    })
end

function Cargo.getRect()
    if not Cargo.window then return nil end
    return { x = Cargo.window.x, y = Cargo.window.y, w = Cargo.window.width, h = Cargo.window.height }
end

function Cargo.refresh()
    -- Reset transient state so the next draw reflects latest cargo data
    Cargo.hoveredItem = nil
    Cargo.hoverTimer = 0
    Cargo.contextMenu.visible = false
    -- Clear any active tooltips when cargo refreshes
    local TooltipManager = require("src.ui.tooltip_manager")
    TooltipManager.clearTooltip()
    local player = getCurrentPlayer()
    Cargo._cargoSnapshot = snapshotCargoState(player)
end

-- Helper functions
local function getPlayerItems(player)
  if not player or not player.components or not player.components.cargo then
    return {}
  end
  local cargo = player.components.cargo
  local items = {}
  cargo:iterate(function(slot, entry)
    local data = entry.meta and Util.deepCopy(entry.meta) or nil
    table.insert(items, {
      id = entry.id,
      qty = entry.qty,
      meta = data,
      slot = slot,
    })
  end)
  table.sort(items, function(a, b)
    local defA = a.meta or Content.getItem(a.id) or Content.getTurret(a.id)
    local defB = b.meta or Content.getItem(b.id) or Content.getTurret(b.id)
    local nameA = (defA and defA.name) or a.id
    local nameB = (defB and defB.name) or b.id
    return nameA < nameB
  end)
  return items
end

snapshotCargoState = function(player)
  if not player or not player.components or not player.components.cargo then
    return nil
  end
  local cargo = player.components.cargo
  local snapshot = {}
  cargo:iterate(function(slot, entry)
    local metaSnapshot = nil
    if entry.meta then
      metaSnapshot = {
        instanceId = entry.meta.instanceId,
        baseId = entry.meta.baseId
      }
    end
    snapshot[#snapshot + 1] = {
      slot = slot,
      id = entry.id,
      qty = entry.qty,
      meta = metaSnapshot
    }
  end)
  table.sort(snapshot, function(a, b)
    if a.id == b.id then
      return a.slot < b.slot
    end
    return a.id < b.id
  end)
  return snapshot
end

cargoStateChanged = function(prev, current)
  if prev == nil and current == nil then
    return false
  end
  if prev == nil or current == nil then
    return true
  end
  if #prev ~= #current then
    return true
  end
  for i = 1, #prev do
    local a = prev[i]
    local b = current[i]
    if not a or not b then
      return true
    end
    if a.id ~= b.id or a.qty ~= b.qty then
      return true
    end
    local metaA = a.meta
    local metaB = b.meta
    if (metaA and not metaB) or (metaB and not metaA) then
      return true
    end
    if metaA and metaB then
      if metaA.instanceId ~= metaB.instanceId or metaA.baseId ~= metaB.baseId then
        return true
      end
    end
  end
  return false
end

local function getItemAtPosition(x, y, slots)
  for _, slot in ipairs(slots) do
    if x >= slot.x and x <= slot.x + slot.w and y >= slot.y and y <= slot.y + slot.h then
      return slot.item, slot.index
    end
  end
  return nil, nil
end

local function createContextMenu(item, x, y)
  if not item then return end
  local def = Content.getItem(item.id) or Content.getTurret(item.id)
  if not def then return end
  Cargo.contextMenu.visible = true
  Cargo.contextMenu.x = x
  Cargo.contextMenu.y = y
  Cargo.contextMenu.item = item
  Cargo.contextMenu.options = {}
  if def.consumable or def.type == "consumable" then
    table.insert(Cargo.contextMenu.options, {name = "Use", action = "use"})
  end
  table.insert(Cargo.contextMenu.options, {name = "Drop", action = "drop"})
end

-- Enhanced sorting and filtering functions
local function getItemDefinition(item)
  return item.turretData or Content.getItem(item.id) or Content.getTurret(item.id)
end

local function buildInsertOptions(player)
  local emptySlots = {}
  local occupiedSlots = {}
  local grid = player.components and player.components.equipment and player.components.equipment.grid
  if not grid then return emptySlots, occupiedSlots end

  for index, slotData in ipairs(grid) do
    local occupied = slotData.id ~= nil
    local label
    if occupied then
      local module = slotData.module
      local moduleId = module and (module.baseId or module.id) or slotData.id
      local moduleDef = moduleId and (Content.getTurret(moduleId) or Content.getItem(moduleId))
      if moduleDef and moduleDef.name then
        label = string.format("Slot %d: %s", index, moduleDef.name)
      else
        label = string.format("Slot %d: %s", index, moduleId or "Unknown")
      end
    else
      label = string.format("Slot %d: Empty", index)
    end

    local option = {
      index = index,
      label = label,
      occupied = occupied
    }

    if occupied then
      occupiedSlots[#occupiedSlots + 1] = option
    else
      emptySlots[#emptySlots + 1] = option
    end
  end

  return emptySlots, occupiedSlots
end

local function getSortValue(item, sortBy)
  local def = getItemDefinition(item)
  if not def then return "" end

  if sortBy == "name" then
    return def.name or item.id
  elseif sortBy == "type" then
    return def.type or "unknown"
  elseif sortBy == "rarity" then
    local rarityOrder = {Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5}
    return rarityOrder[def.rarity] or 0
  elseif sortBy == "value" then
    return def.price or def.value or 0
  elseif sortBy == "quantity" then
    return item.qty or 1
  end
  return ""
end

local function sortItems(items, sortBy, sortOrder)
  table.sort(items, function(a, b)
    local aVal = getSortValue(a, sortBy)
    local bVal = getSortValue(b, sortBy)

    local result = aVal < bVal
    if sortOrder == "desc" then
      result = aVal > bVal
    end
    return result
  end)
end

local function filterItems(items, searchText)
  if not searchText or searchText == "" then
    return items
  end

  local filtered = {}
  local search = searchText:lower()

  for _, item in ipairs(items) do
    local def = getItemDefinition(item)
    if def then
      local name = (def.name or item.id):lower()
      local type = (def.type or ""):lower()
      local description = (def.description or ""):lower()

      if name:find(search, 1, true) or type:find(search, 1, true) or description:find(search, 1, true) then
        table.insert(filtered, item)
      end
    end
  end

  return filtered
end

-- Enhanced drawing functions
local function drawSearchBar(x, y, w, h, searchText, isActive)
  local padding = 4
  local searchW = w - h - padding
  local searchH = h - padding * 2

  -- Search bar background
  local bgColor = isActive and Theme.colors.bg3 or Theme.colors.bg2
  Theme.drawGradientGlowRect(x, y, searchW, h, 4, bgColor, Theme.withAlpha(Theme.colors.bg0, 0.2), Theme.colors.border, 0)

  -- Search icon (using text instead of emoji for better compatibility)
  local iconSize = h - 8
  local iconX = x + 4
  local iconY = y + 4
  Theme.setColor(Theme.colors.textSecondary)
  Theme.setFont("small")

  -- Only show "Search" label when not actively inputting
  if not isActive then
    love.graphics.print("Search", iconX, iconY)
  end

  -- Search text
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
  local bgColor = Theme.colors.bg2
  Theme.drawGradientGlowRect(x, y, w, h, 4, bgColor, Theme.withAlpha(Theme.colors.bg0, 0.2), Theme.colors.border, 0)

  -- Sort icon
  local icon = sortOrder == "asc" and "↑" or "↓"
  local sortNames = {name = "Name", type = "Type", rarity = "Rarity", value = "Value", quantity = "Qty"}

  Theme.setFont("small")
  local text = sortNames[sortBy] or "Name"
  local iconWidth = love.graphics.getFont():getWidth(icon)
  local textWidth = love.graphics.getFont():getWidth(text)

  Theme.setColor(Theme.colors.text)
  love.graphics.print(text, x + 4, y + (h - 12) / 2)
  love.graphics.print(icon, x + w - iconWidth - 4, y + (h - 12) / 2)

  return { x = x, y = y, w = w, h = h }
end

local function drawAdvancedScrollbar(x, y, w, h, scroll, maxScroll, isHovered)
  local scrollbarWidth = 12
  local scrollbarX = x + w - scrollbarWidth - 2

  -- Background track
  Theme.setColor(Theme.withAlpha(Theme.colors.bg0, 0.5))
  love.graphics.rectangle("fill", scrollbarX, y, scrollbarWidth, h)

  if maxScroll > 0 then
    -- Thumb calculation
    local thumbHeight = math.max(20, h * (h / (h + maxScroll)))
    local thumbY = y + (h - thumbHeight) * (scroll / maxScroll)

    -- Thumb with gradient
    local thumbGradient = {
      isHovered and Theme.withAlpha(Theme.colors.bg3, 0.8) or Theme.withAlpha(Theme.colors.bg2, 0.8),
      isHovered and Theme.withAlpha(Theme.colors.bg4, 0.6) or Theme.withAlpha(Theme.colors.bg3, 0.6)
    }
    Theme.drawVerticalGradient(scrollbarX + 2, thumbY, scrollbarWidth - 4,
      thumbHeight, thumbGradient[1], thumbGradient[2])

    -- Thumb border
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

  Theme.drawGradientGlowRect(x, y, size, size, 4, bgColor,
    Theme.withAlpha(Theme.colors.bg0, 0.2), Theme.colors.border, 0, false)

  local def = getItemDefinition(item)
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
    item.id
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
    local dotSize = math.max(3, math.floor(size * 0.12)) -- Small dot, 12% of slot size
    
    -- Draw small colored dot in top left corner
    Theme.setColor(rarityColor)
    love.graphics.circle("fill", x + 2 + dotSize/2, y + 2 + dotSize/2, dotSize/2)
    
    -- Add subtle border for better visibility
    Theme.setColor(Theme.withAlpha(Theme.colors.bg0, 0.8))
    love.graphics.setLineWidth(1)
    love.graphics.circle("line", x + 2 + dotSize/2, y + 2 + dotSize/2, dotSize/2)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(prevColor[1] or 1, prevColor[2] or 1, prevColor[3] or 1, prevColor[4] or 1)
  end
end

function Cargo.draw()
    if not Cargo.visible then return end
    if not Cargo.window then Cargo.init() end
    -- Keep UIManager state in sync when cargo is shown/hidden directly
    local ok, UIManager = pcall(require, "src.core.ui_manager")
    if ok and UIManager and UIManager.state and UIManager.state.cargo then
        UIManager.state.cargo.open = Cargo.visible
    end
    Cargo.window.visible = Cargo.visible
    Cargo.window:draw()

end

function Cargo.drawContent(window, x, y, w, h)
    local player = getCurrentPlayer()
    if not player then return end

    local currentSnapshot = snapshotCargoState(player)
    if cargoStateChanged(Cargo._cargoSnapshot, currentSnapshot) then
        Cargo._cargoSnapshot = currentSnapshot
        Cargo.hoveredItem = nil
        Cargo.hoverTimer = 0
        Cargo.contextMenu.visible = false
    end

    local mx, my = Viewport.getMousePosition()

    local headerHeight = 36
    local headerPadding = 8
    local sortWidth = 108
    local searchHeight = headerHeight - headerPadding * 2
    if searchHeight < 20 then searchHeight = 20 end

    Theme.drawGradientGlowRect(x, y, w, headerHeight, 4, Theme.colors.bg2, Theme.colors.bg1, Theme.colors.border, Theme.effects.glowWeak)

    local searchWidth = w - sortWidth - (headerPadding * 3)
    if searchWidth < 120 then
        searchWidth = w - headerPadding * 2
        sortWidth = 0
    end

    Cargo._searchRect = drawSearchBar(x + headerPadding, y + headerPadding, searchWidth, searchHeight, Cargo.searchText, Cargo._searchInputActive)
    if sortWidth > 0 then
        Cargo._sortRect = drawSortButton(x + w - sortWidth - headerPadding, y + headerPadding, sortWidth, searchHeight, Cargo.sortBy, Cargo.sortOrder)
    else
        Cargo._sortRect = nil
    end

    -- Get items with sorting and filtering
    local items = getPlayerItems(player)
    items = filterItems(items, Cargo.searchText)
    sortItems(items, Cargo.sortBy, Cargo.sortOrder)

    local iconSize = CARGO_SLOT_SIZE
    local padding = (Theme.ui and Theme.ui.contentPadding) or 8
    local contentY = y + headerHeight + padding * 0.5
    local footerHeight = 24
    local contentH = h - headerHeight - footerHeight
    
    local iconsPerRow = math.floor((w - padding) / (iconSize + padding))
    if iconsPerRow < 1 then iconsPerRow = 1 end

    local totalRows = math.ceil(#items / iconsPerRow)
    local totalContentHeight = totalRows * (iconSize + padding) + padding
    Cargo._scrollMax = math.max(0, totalContentHeight - contentH)
    if Cargo.scroll > Cargo._scrollMax then Cargo.scroll = Cargo._scrollMax end

    -- Draw items with enhanced hover states
    love.graphics.push()
    love.graphics.setScissor(x, contentY, w, contentH)
    Cargo._slotRects = {}

    for i, item in ipairs(items) do
        local row = math.floor((i - 1) / iconsPerRow)
        local col = (i - 1) % iconsPerRow
        local itemX = x + col * (iconSize + padding) + padding
        local itemY = contentY + row * (iconSize + padding) + padding - Cargo.scroll

        if itemY + iconSize > contentY and itemY < contentY + contentH then
            local isHovered = mx >= itemX and mx <= itemX + iconSize and my >= itemY and my <= itemY + iconSize
            local isSelected = false -- Could add selection logic later

            drawEnhancedItemSlot(item, itemX, itemY, iconSize, isHovered, isSelected)

            table.insert(Cargo._slotRects, { x = itemX, y = itemY, w = iconSize, h = iconSize, item = item, index = i })

            if isHovered then
                if not Cargo.hoveredItem or Cargo.hoveredItem.id ~= item.id then
                    Cargo.hoveredItem = item
                    Cargo.hoverTimer = 0
                else
                    Cargo.hoverTimer = Cargo.hoverTimer + love.timer.getDelta()
                end
            end
        end
    end

    -- Advanced scrollbar
    if Cargo._scrollMax > 0 then
        local scrollbarWidth = 12
        local scrollbarX = x + w - scrollbarWidth - 2
        local scrollbarY = contentY
        local scrollbarHeight = contentH

        local scrollbarHover = mx >= scrollbarX and mx <= scrollbarX + scrollbarWidth and my >= scrollbarY and my <= scrollbarY + scrollbarHeight
        local thumbRect = drawAdvancedScrollbar(x, contentY, w, contentH, Cargo.scroll, Cargo._scrollMax, scrollbarHover)

        -- Handle scrollbar dragging
        if Cargo._scrollDragging and thumbRect then
            Cargo._scrollThumbRect = thumbRect
        end
    end

    love.graphics.setScissor()
    love.graphics.pop()

    -- Enhanced info bar
    local infoBarHeight = footerHeight - 6
    local infoBarY = y + h - infoBarHeight
    Theme.drawGradientGlowRect(x, infoBarY, w, infoBarHeight, 4, Theme.colors.bg2, Theme.colors.bg1, Theme.colors.border, Theme.effects.glowWeak)

    local itemCount = #items
    local credits = player.getGC and player:getGC() or 0
    
    -- Get cargo volume information
    local cargo = player.components and player.components.cargo
    local currentVolume = cargo and cargo:getCurrentVolume() or 0
    local volumeLimit = cargo and cargo:getVolumeLimit() or math.huge
    local volumeText = ""
    if volumeLimit == math.huge then
        volumeText = string.format("Volume: %.1f m³", currentVolume)
    else
        volumeText = string.format("Volume: %.1f/%.1f m³", currentVolume, volumeLimit)
    end

    Theme.setFont("small")
    Theme.setColor(Theme.colors.textSecondary)
    love.graphics.print(volumeText, x + 8, infoBarY + 3)

    local creditText = Util.formatNumber(credits)
    local font = Theme.getFont("small")
    local creditWidth = font:getWidth(creditText)
    local iconSize = 12
    local iconSpacing = 4
    local totalWidth = creditWidth + iconSize + iconSpacing
    
    Theme.setColor(Theme.colors.accentGold)
    love.graphics.print(creditText, x + w - totalWidth - 8, infoBarY + 3)
    
    -- Draw GC icon next to the credit amount
    local iconX = x + w - iconSize - 8
    local iconY = infoBarY + (infoBarHeight - iconSize) / 2
    Theme.drawCurrencyToken(iconX, iconY, iconSize)

    -- Register tooltip with tooltip manager
    local TooltipManager = require("src.ui.tooltip_manager")
    if Cargo.hoveredItem and Cargo.hoverTimer > 0.1 and not Cargo.contextMenu.visible then
        local def = Cargo.hoveredItem.turretData or Content.getItem(Cargo.hoveredItem.id) or Content.getTurret(Cargo.hoveredItem.id)
        if def then
            TooltipManager.setTooltip(def, mx, my)
        end
    else
        -- Clear tooltip if not hovering or context menu is visible
        TooltipManager.clearTooltip()
    end

    -- Draw context menu
    if Cargo.contextMenu.visible then
        Cargo.drawContextMenu()
    end
end

function Cargo.mousepressed(x, y, button)
    if not Cargo.visible then return false end
    if not Cargo.window then Cargo.init() end

    if Cargo.window:mousepressed(x, y, button) then
        return true
    end

    local player = getCurrentPlayer()
    if not player then return false end

    local mx, my = Viewport.getMousePosition()

    if button == 1 then
        local searchRect = Cargo._searchRect
        if searchRect and mx >= searchRect.x and mx <= searchRect.x + searchRect.w and my >= searchRect.y and my <= searchRect.y + searchRect.h then
            setSearchActive(true)
            Cargo.contextMenu.visible = false
            return true
        end

        local sortRect = Cargo._sortRect
        if sortRect and mx >= sortRect.x and mx <= sortRect.x + sortRect.w and my >= sortRect.y and my <= sortRect.y + sortRect.h then
            if love.keyboard and (love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")) then
                Cargo.sortOrder = (Cargo.sortOrder == "asc") and "desc" or "asc"
            else
                local sortFields = {"name", "type", "rarity", "value", "quantity"}
                local currentIndex = 1
                for i, field in ipairs(sortFields) do
                    if field == Cargo.sortBy then
                        currentIndex = i
                        break
                    end
                end
                Cargo.sortBy = sortFields[(currentIndex % #sortFields) + 1]
            end
            Cargo.contextMenu.visible = false
            return true
        end
    end

  if button ~= 1 then
        setSearchActive(false)
    end

    -- Context menu clicks
    if (button == 1 or button == 2) and Cargo.contextMenu.visible then
        local menu = Cargo.contextMenu
        local w = 180
        local optionH = 24
        local h = 8 + (#menu.options * optionH) + 8

        for i, option in ipairs(menu.options) do
            local optY = menu.y + 8 + (i-1) * optionH
            if mx >= menu.x and mx <= menu.x + w and my >= optY and my <= optY + optionH then
                Cargo.handleContextMenuClick(option)
                return true
            end
        end
        Cargo.contextMenu.visible = false
        return true
    end

    -- Item interactions
    if button == 2 then
        setSearchActive(false)
        local item, index = getItemAtPosition(x, y, Cargo._slotRects)
        if item then
            Cargo.contextMenu = {
                visible = true,
                x = mx,
                y = my,
                item = item,
                index = index,
                options = {}
            }

            local def = getItemDefinition(item)
            if def then
                if def.consumable or def.type == "consumable" then
                    table.insert(Cargo.contextMenu.options, { name = "Use", action = "use" })
                end
                table.insert(Cargo.contextMenu.options, { name = "Drop", action = "drop" })
            end

            if #Cargo.contextMenu.options > 0 then
                return true
            else
                Cargo.contextMenu.visible = false
            end
        end
    end

    if button == 1 then
        setSearchActive(false)
        local item, index = getItemAtPosition(x, y, Cargo._slotRects)
        if item then
            local def = getItemDefinition(item)
            if def and (def.consumable or def.type == "consumable") then
                -- Consumable item - use it
                Cargo.useItem(player, item.id)
                return true
            else
                -- Non-consumable item - play click sound and show notification
                local Sound = require("src.core.sound")
                Sound.playSFX("button_click")
                
                local Notifications = require("src.ui.notifications")
                Notifications.add("Nothing happens", "info")
                return true
            end
        end
    elseif button == 2 then
        setSearchActive(false)
        local item, index = getItemAtPosition(x, y, Cargo._slotRects)
        if item then
            createContextMenu(item, x, y)
            return true
        else
            Cargo.contextMenu.visible = false
        end
    end

    return false
end

function Cargo.mousereleased(x, y, button)
    if not Cargo.visible then return false end
    if not Cargo.window then return false end
    return Cargo.window:mousereleased(x, y, button)
end

function Cargo.mousemoved(x, y, dx, dy)
    if not Cargo.visible then return false end
    if not Cargo.window then return false end
    return Cargo.window:mousemoved(x, y, dx, dy)
end

function Cargo.wheelmoved(x, y, dx, dy)
    if not Cargo.visible then return false end
    if not Cargo.window then return false end
    if not Cargo.window:containsPoint(x, y) then return false end

    local scrollSpeed = 40
    Cargo.scroll = Cargo.scroll - dy * scrollSpeed
    Cargo.scroll = math.max(0, math.min(Cargo.scroll, math.max(0, Cargo._scrollMax)))
    if Cargo.scroll ~= Cargo.scroll then Cargo.scroll = 0 end
    return true
end

function Cargo.update(dt)
  if not Cargo.visible then
    setSearchActive(false)
    -- Clear any active tooltips when cargo is not visible
    local TooltipManager = require("src.ui.tooltip_manager")
    TooltipManager.clearTooltip()
    return
  end
  if Cargo.hoveredItem then
    local mx, my = Viewport.getMousePosition()
    local stillHovering = false
    if Cargo._slotRects then
      for _, slot in ipairs(Cargo._slotRects) do
        if mx >= slot.x and mx <= slot.x + slot.w and my >= slot.y and my <= slot.y + slot.h then
          stillHovering = true
          break
        end
      end
    end
    if not stillHovering then
      Cargo.hoveredItem = nil
      Cargo.hoverTimer = 0
    end
  end
end

function Cargo.drawContextMenu()
  local menu = Cargo.contextMenu
  local x, y = menu.x, menu.y
  local w = 180
  local options = menu.options
  local optionH = 24
  local h = 8 + (#options * optionH) + 8
  local sw, sh = Viewport.getDimensions()
  if x + w > sw then x = sw - w end
  if y + h > sh then y = sh - h end
  Theme.drawGradientGlowRect(x, y, w, h, 6, Theme.colors.bg2, Theme.colors.bg1, Theme.colors.border, Theme.effects.glowWeak)
  local mx, my = Viewport.getMousePosition()
  for i, option in ipairs(options) do
    local optY = y + 8 + (i-1) * optionH
    local hover = mx >= x and mx <= x + w and my >= optY and my <= optY + optionH
    if hover then
      Theme.setColor(Theme.colors.bg3)
      love.graphics.rectangle('fill', x + 4, optY, w - 8, optionH)
    end
    Theme.setColor(hover and Theme.colors.textHighlight or Theme.colors.text)
    Theme.setFont("small")
    love.graphics.print(option.name, x + 12, optY + (optionH - 12) * 0.5)
  end
end

function Cargo.keypressed(key)
  if not Cargo.visible then return false end

  -- When search input is active, consume most hotkeys
  if Cargo._searchInputActive then
    if key == "escape" then
      setSearchActive(false)
      return true
    elseif key == "return" or key == "kpenter" then
      setSearchActive(false)
      return true
    elseif key == "backspace" then
      Cargo.searchText = Cargo.searchText:sub(1, -2)
      return true
    elseif key == "tab" then
      -- Tab could cycle between controls, but for now just consume it
      return true
    end
    -- All other keys are consumed by the search input
    return true
  end

  -- Normal hotkey handling when search is not active
  if key == "escape" then
    if Cargo.contextMenu.visible then
      Cargo.contextMenu.visible = false
      return true
    end
    setSearchActive(false)
    Cargo.visible = false
    return true
  end
  return false
end

function Cargo.textinput(text)
  if not Cargo.visible then return false end

  -- Handle search input
  if Cargo._searchInputActive then
    Cargo.searchText = Cargo.searchText .. text
    return true
  end

  return false
end

function Cargo.handleContextMenuClick(option)
  local menu = Cargo.contextMenu
  if not menu.item then return end
  local item = menu.item
  local def = Content.getItem(item.id) or Content.getTurret(item.id)
  if not def then return end
  local player = getCurrentPlayer()
  if not player then return end
  if option.action == "use" then
    Cargo.useItem(player, item.id)
  elseif option.action == "drop" then
    Cargo.dropItem(player, item.id)
  end
  menu.visible = false
end

function Cargo.dropItem(player, itemId)
  if not player or not player.components or not player.components.cargo then return false end
  local cargo = player.components.cargo
  if not cargo:has(itemId, 1) then return false end
  local def = Content.getItem(itemId) or Content.getTurret(itemId)
  local itemName = def and def.name or itemId
  cargo:remove(itemId, 1)
  
  -- Drop item around player just outside magnet range
  local playerX, playerY = player.components.position.x, player.components.position.y
  local ATTRACT_RADIUS = 600  -- Magnet range from pickups.lua
  local dropDistance = ATTRACT_RADIUS + 50  -- Just outside magnet range
  
  -- Random angle around player
  local angle = math.random() * math.pi * 2
  local dropX = playerX + math.cos(angle) * dropDistance
  local dropY = playerY + math.sin(angle) * dropDistance
  
  -- Create item pickup entity
  local ItemPickup = require("src.entities.item_pickup")
  local pickup = ItemPickup.new(
    dropX, 
    dropY, 
    itemId, 
    1, 
    0.3,  -- Smaller size scale
    math.random(-50, 50),  -- Small random velocity
    math.random(-50, 50)
  )
  
  -- Add to world directly
  local Game = require("src.game")
  if Game.world and pickup then
    Game.world:addEntity(pickup)
  end
  
  -- Visual effect at drop location
  for i = 1, 3 do
    Theme.createParticle(dropX + math.random(-8, 8), dropY + math.random(-8, 8), {0.6, 0.6, 0.6, 1.0}, (math.random() * 2 - 1) * 20, (math.random() * 2 - 1) * 20, nil, 0.7)
  end
  
  local Notifications = require("src.ui.notifications")
  Notifications.add("Dropped " .. itemName, "info")
  return true
end

function Cargo.useItem(player, itemId)
  if not player then player = getCurrentPlayer() end
  if not player or not player.components or not player.components.cargo then return false end
  local cargo = player.components.cargo
  if not cargo:has(itemId, 1) then return false end
  local item = Content.getItem(itemId)
  if not item then return false end
  if not (item.consumable or item.type == "consumable") then return false end


  if itemId == "node_wallet" then
    local PortfolioManager = require("src.managers.portfolio")
    local success, message = PortfolioManager.useNodeWallet()
    if success then
      cargo:remove(itemId, 1)
      local Notifications = require("src.ui.notifications")
      Notifications.add("🔓 WALLET DECRYPTED • NODES ADDED", "success")
    else
      local Notifications = require("src.ui.notifications")
      Notifications.add("⚠️ " .. (message or "FAILED TO PROCESS NODE WALLET"), "error")
    end
    return true
  end
  return false
end

return Cargo

