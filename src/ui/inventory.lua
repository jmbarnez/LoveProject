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

local Inventory = {}

-- Helper function to get current player safely
local function getCurrentPlayer()
  return PlayerRef.get and PlayerRef.get() or nil
end

-- Helper function to set current player reference
function Inventory.setPlayer(player)
  Inventory.player = player
end

-- Core inventory state
Inventory.visible = false
Inventory.hoveredItem = nil
Inventory.hoverTimer = 0
Inventory.scroll = 0
Inventory._scrollMax = 0
Inventory.contextMenu = {
  visible = false,
  x = 0,
  y = 0,
  item = nil,
  options = {}
}
Inventory.auroraShader = nil

-- Enhanced inventory features
Inventory.searchText = ""
Inventory.sortBy = "name" -- "name", "type", "rarity", "value", "quantity"
Inventory.sortOrder = "asc" -- "asc" or "desc"
Inventory._searchInputActive = false
Inventory._scrollDragging = false
Inventory._scrollDragOffset = 0

function Inventory.init()
    Inventory.window = Window.new({
        title = "Inventory",
        width = 420,
        height = 320,
        minWidth = 300,
        minHeight = 200,
        useLoadPanelTheme = true,
        draggable = true,
        closable = true,
        drawContent = Inventory.drawContent,
        onClose = function()
            Inventory.visible = false
        end
    })
end

function Inventory.getRect()
    if not Inventory.window then return nil end
    return { x = Inventory.window.x, y = Inventory.window.y, w = Inventory.window.width, h = Inventory.window.height }
end

-- Helper functions
local function getPlayerItems(player)
  if not player or not player.inventory then return {} end
  local items = {}
  for id, qty in pairs(player.inventory) do
    if type(qty) == "number" then
      table.insert(items, { id = id, qty = qty })
    elseif type(qty) == "table" and qty.damage then
      table.insert(items, { id = id, qty = 1, turretData = qty })
    end
  end
  table.sort(items, function(a, b)
    local an = a.turretData and a.turretData.name or (Content.getItem(a.id) and Content.getItem(a.id).name) or (Content.getTurret(a.id) and Content.getTurret(a.id).name) or a.id
    local bn = b.turretData and b.turretData.name or (Content.getItem(b.id) and Content.getItem(b.id).name) or (Content.getTurret(b.id) and Content.getTurret(b.id).name) or b.id
    return an < bn
  end)
  return items
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
  Inventory.contextMenu.visible = true
  Inventory.contextMenu.x = x
  Inventory.contextMenu.y = y
  Inventory.contextMenu.item = item
  Inventory.contextMenu.options = {}
  if def.consumable or def.type == "consumable" then
    table.insert(Inventory.contextMenu.options, {name = "Use", action = "use"})
  end
  if def.module or item.turretData then
    table.insert(Inventory.contextMenu.options, {name = "Equip", action = "equip"})
  end
  table.insert(Inventory.contextMenu.options, {name = "Drop", action = "drop"})
  if def.price then
    table.insert(Inventory.contextMenu.options, {name = "Sell", action = "sell"})
  end
end

-- Enhanced sorting and filtering functions
local function getItemDefinition(item)
  return item.turretData or Content.getItem(item.id) or Content.getTurret(item.id)
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
  love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())

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

  love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
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
  local iconSize = size - padding * 2

  -- Enhanced background with better states
  local bgColor = Theme.withAlpha(Theme.colors.bg1, 0.3)
  if isSelected then
    bgColor = Theme.colors.selection
  elseif isHovered then
    bgColor = Theme.colors.hover
  end

  Theme.drawGradientGlowRect(x, y, size, size, 4, bgColor,
    Theme.withAlpha(Theme.colors.bg0, 0.2), Theme.colors.border, 0)

  -- Item icon
  local def = getItemDefinition(item)
  if def then
    if item.turretData then
      IconSystem.drawTurretIcon(item.turretData, x + padding, y + padding, iconSize, 1.0)
    elseif IconSystem.getIcon(def) then
      IconSystem.drawItemIcon(def, x + padding, y + padding, iconSize, 1.0)
    end

    -- Enhanced stack count display
    if not item.turretData and item.qty > 1 then
      local stackCount = Util.formatNumber(item.qty)
      local font = Theme.fonts and Theme.fonts.xsmall or love.graphics.getFont()
      local textW = font:getWidth(stackCount)
      local textH = font:getHeight()

      -- Stack count background
      Theme.setColor(Theme.withAlpha(Theme.colors.bg0, 0.8))
      love.graphics.rectangle("fill", x + size - textW - 8, y + size - textH - 6, textW + 4, textH + 2)

      -- Stack count text
      Theme.setColor(Theme.colors.accent)
      love.graphics.setFont(font)
      love.graphics.print(stackCount, x + size - textW - 6, y + size - textH - 5)
    end

    -- Rarity indicator
    if def.rarity then
      local rarityColors = {
        Common = Theme.colors.textSecondary,
        Uncommon = {0.3, 0.9, 0.3, 1.0},
        Rare = {0.3, 0.6, 0.9, 1.0},
        Epic = {0.8, 0.3, 0.9, 1.0},
        Legendary = {0.9, 0.7, 0.2, 1.0}
      }
      local rarityColor = rarityColors[def.rarity] or Theme.colors.textSecondary
      Theme.setColor(rarityColor)
      love.graphics.setLineWidth(2)
      love.graphics.rectangle("line", x + 1, y + 1, size - 2, size - 2)
    end
  end
end

function Inventory.draw()
    if not Inventory.visible then return end
    if not Inventory.window then Inventory.init() end
    Inventory.window.visible = Inventory.visible
    Inventory.window:draw()
end

function Inventory.drawContent(window, x, y, w, h)
    local player = getCurrentPlayer()
    if not player then return end

    local mx, my = Viewport.getMousePosition()

    -- Get items with sorting and filtering
    local items = getPlayerItems(player)
    items = filterItems(items, Inventory.searchText)
    sortItems(items, Inventory.sortBy, Inventory.sortOrder)

    local iconSize = 64
    local padding = (Theme.ui and Theme.ui.contentPadding) or 8
    local contentY = y
    local contentH = h - 24

    local iconsPerRow = math.floor((w - padding) / (iconSize + padding))
    if iconsPerRow < 1 then iconsPerRow = 1 end

    local totalRows = math.ceil(#items / iconsPerRow)
    local totalContentHeight = totalRows * (iconSize + padding) + padding
    Inventory._scrollMax = math.max(0, totalContentHeight - contentH)
    if Inventory.scroll > Inventory._scrollMax then Inventory.scroll = Inventory._scrollMax end

    -- Draw items with enhanced hover states
    love.graphics.push()
    love.graphics.setScissor(x, contentY, w, contentH)
    Inventory._slotRects = {}

    for i, item in ipairs(items) do
        local row = math.floor((i - 1) / iconsPerRow)
        local col = (i - 1) % iconsPerRow
        local itemX = x + col * (iconSize + padding) + padding
        local itemY = contentY + row * (iconSize + padding) + padding - Inventory.scroll

        if itemY + iconSize > contentY and itemY < contentY + contentH then
            local isHovered = mx >= itemX and mx <= itemX + iconSize and my >= itemY and my <= itemY + iconSize
            local isSelected = false -- Could add selection logic later

            drawEnhancedItemSlot(item, itemX, itemY, iconSize, isHovered, isSelected)

            table.insert(Inventory._slotRects, { x = itemX, y = itemY, w = iconSize, h = iconSize, item = item, index = i })

            if isHovered then
                if not Inventory.hoveredItem or Inventory.hoveredItem.id ~= item.id then
                    Inventory.hoveredItem = item
                    Inventory.hoverTimer = 0
                else
                    Inventory.hoverTimer = Inventory.hoverTimer + love.timer.getDelta()
                end
            end
        end
    end

    -- Advanced scrollbar
    if Inventory._scrollMax > 0 then
        local scrollbarWidth = 12
        local scrollbarX = x + w - scrollbarWidth - 2
        local scrollbarY = contentY
        local scrollbarHeight = contentH

        local scrollbarHover = mx >= scrollbarX and mx <= scrollbarX + scrollbarWidth and my >= scrollbarY and my <= scrollbarY + scrollbarHeight
        local thumbRect = drawAdvancedScrollbar(x, contentY, w, contentH, Inventory.scroll, Inventory._scrollMax, scrollbarHover)

        -- Handle scrollbar dragging
        if Inventory._scrollDragging and thumbRect then
            Inventory._scrollThumbRect = thumbRect
        end
    end

    love.graphics.setScissor()
    love.graphics.pop()

    -- Enhanced info bar
    local infoBarY = y + h - 18
    Theme.drawGradientGlowRect(x, infoBarY, w, 18, 4, Theme.colors.bg2, Theme.colors.bg1, Theme.colors.border, Theme.effects.glowWeak)

    local itemCount = #items
    local totalSlots = 24
    local credits = player.getGC and player:getGC() or 0

    local font = Theme.fonts and Theme.fonts.small or love.graphics.getFont()
    love.graphics.setFont(font)
    Theme.setColor(Theme.colors.textSecondary)
    love.graphics.print("Items: " .. itemCount .. "/" .. totalSlots, x + 8, infoBarY + 3)

    local creditText = Util.formatNumber(credits) .. " GC"
    local creditWidth = font:getWidth(creditText)
    Theme.setColor(Theme.colors.accentGold)
    love.graphics.print(creditText, x + w - creditWidth - 8, infoBarY + 3)

    -- Draw tooltip
    if Inventory.hoveredItem and Inventory.hoverTimer > 0.1 and not Inventory.contextMenu.visible then
        local def = Inventory.hoveredItem.turretData or Content.getItem(Inventory.hoveredItem.id) or Content.getTurret(Inventory.hoveredItem.id)
        if def then
            Tooltip.drawItemTooltip(def, mx, my)
        end
    end

    -- Draw context menu
    if Inventory.contextMenu.visible then
        Inventory.drawContextMenu()
    end
end

function Inventory.mousepressed(x, y, button)
    if not Inventory.visible then return false end
    if not Inventory.window then Inventory.init() end

    if Inventory.window:mousepressed(x, y, button) then
        return true
    end

    local player = getCurrentPlayer()
    if not player then return false end

    local mx, my = Viewport.getMousePosition()

    -- Context menu clicks
    if button == 1 and Inventory.contextMenu.visible then
        local menu = Inventory.contextMenu
        local w = 180
        local optionH = 24
        local h = 8 + (#menu.options * optionH) + 8

        for i, option in ipairs(menu.options) do
            local optY = menu.y + 8 + (i-1) * optionH
            if mx >= menu.x and mx <= menu.x + w and my >= optY and my <= optY + optionH then
                Inventory.handleContextMenuClick(option)
                return true
            end
        end
        Inventory.contextMenu.visible = false
        return true
    end

    -- Item interactions
    if button == 1 then
        local item, index = getItemAtPosition(x, y, Inventory._slotRects)
        if item then
            local def = Content.getItem(item.id) or Content.getTurret(item.id)
            if def and (def.consumable or def.type == "consumable") then
                Inventory.useItem(player, item.id)
                return true
            end
        end
    elseif button == 2 then
        local item, index = getItemAtPosition(x, y, Inventory._slotRects)
        if item then
            createContextMenu(item, x, y)
            return true
        else
            Inventory.contextMenu.visible = false
        end
    end

    return false
end

function Inventory.mousereleased(x, y, button)
    if not Inventory.visible then return false end
    if not Inventory.window then return false end
    return Inventory.window:mousereleased(x, y, button)
end

function Inventory.mousemoved(x, y, dx, dy)
    if not Inventory.visible then return false end
    if not Inventory.window then return false end
    return Inventory.window:mousemoved(x, y, dx, dy)
end

function Inventory.wheelmoved(x, y, dx, dy)
    if not Inventory.visible then return false end
    if not Inventory.window then return false end
    if not Inventory.window:containsPoint(x, y) then return false end

    local scrollSpeed = 40
    Inventory.scroll = Inventory.scroll - dy * scrollSpeed
    Inventory.scroll = math.max(0, math.min(Inventory.scroll, math.max(0, Inventory._scrollMax)))
    if Inventory.scroll ~= Inventory.scroll then Inventory.scroll = 0 end
    return true
end

function Inventory.update(dt)
  if not Inventory.visible then return end
  if Inventory.hoveredItem then
    local mx, my = Viewport.getMousePosition()
    local stillHovering = false
    if Inventory._slotRects then
      for _, slot in ipairs(Inventory._slotRects) do
        if mx >= slot.x and mx <= slot.x + slot.w and my >= slot.y and my <= slot.y + slot.h then
          stillHovering = true
          break
        end
      end
    end
    if not stillHovering then
      Inventory.hoveredItem = nil
      Inventory.hoverTimer = 0
    end
  end
end

function Inventory.drawContextMenu()
  local menu = Inventory.contextMenu
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
    love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
    love.graphics.print(option.name, x + 12, optY + (optionH - 12) * 0.5)
  end
end

function Inventory.keypressed(key)
  if not Inventory.visible then return false end

  -- When search input is active, consume most hotkeys
  if Inventory._searchInputActive then
    if key == "escape" then
      -- Escape deactivates search input and closes inventory
      Inventory._searchInputActive = false
      Inventory.visible = false
      return true
    elseif key == "return" or key == "kpenter" then
      -- Enter confirms search and deactivates input
      Inventory._searchInputActive = false
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
    if Inventory.contextMenu.visible then
      Inventory.contextMenu.visible = false
      return true
    end
    Inventory.visible = false
    return true
  end
  return false
end

function Inventory.textinput(text)
  if not Inventory.visible then return false end

  -- Handle search input
  if Inventory._searchInputActive then
    if text == "backspace" then
      Inventory.searchText = Inventory.searchText:sub(1, -2)
    elseif text == "return" or text == "kpenter" then
      Inventory._searchInputActive = false
    else
      Inventory.searchText = Inventory.searchText .. text
    end
    return true
  end

  return false
end

function Inventory.handleContextMenuClick(option)
  local menu = Inventory.contextMenu
  if not menu.item then return end
  local item = menu.item
  local def = Content.getItem(item.id) or Content.getTurret(item.id)
  if not def then return end
  local player = Inventory.player or getCurrentPlayer()
  if not player then return end
  if option.action == "use" then
    Inventory.useItem(player, item.id)
  elseif option.action == "drop" then
    Inventory.dropItem(player, item.id)
  elseif option.action == "sell" then
    Inventory.sellItem(player, item.id)
  elseif option.action == "equip" then
    local Notifications = require("src.ui.notifications")
    Notifications.add("Equip functionality not yet implemented", "info")
  end
  menu.visible = false
end

function Inventory.dropItem(player, itemId)
  if not player or not player.inventory or not player.inventory[itemId] then return false end
  local def = Content.getItem(itemId) or Content.getTurret(itemId)
  local itemName = def and def.name or itemId
  local currentAmount = player.inventory[itemId]
  if type(currentAmount) == "number" and currentAmount > 1 then
    player.inventory[itemId] = currentAmount - 1
  else
    player.inventory[itemId] = nil
  end
  local mouseX, mouseY = Viewport.getMousePosition()
  for i = 1, 3 do
    Theme.createParticle(mouseX + math.random(-8, 8), mouseY + math.random(-8, 8), {0.6, 0.6, 0.6, 1.0}, (math.random() * 2 - 1) * 20, (math.random() * 2 - 1) * 20, nil, 0.7)
  end
  local Notifications = require("src.ui.notifications")
  Notifications.add("Dropped " .. itemName, "info")
  return true
end

function Inventory.sellItem(player, itemId)
  if not player or not player.inventory or not player.inventory[itemId] then return false end
  local def = Content.getItem(itemId) or Content.getTurret(itemId)
  if not def or not def.price then return false end
  local sellPrice = math.floor(def.price * 0.5)
  local currentAmount = player.inventory[itemId]
  if type(currentAmount) == "number" and currentAmount > 1 then
    player.inventory[itemId] = currentAmount - 1
  else
    player.inventory[itemId] = nil
  end
  if player.addGC then player:addGC(sellPrice) end
  local mouseX, mouseY = Viewport.getMousePosition()
  for i = 1, 5 do
    Theme.createParticle(mouseX + math.random(-10, 10), mouseY + math.random(-10, 10), {0.9, 0.7, 0.2, 1.0}, 0, -30, nil, 0.5)
  end
  if sellPrice > 100 then
    Theme.flashScreen({0.9, 0.7, 0.2, 0.2}, 0.3)
    Theme.shakeScreen(2, 0.1)
  end
  local Notifications = require("src.ui.notifications")
  Notifications.add("Sold " .. (def.name or itemId) .. " for " .. sellPrice .. " GC", "success")
  return true
end

function Inventory.useItem(player, itemId)
  if not player then player = getCurrentPlayer() end
  if not player or not player.inventory or not player.inventory[itemId] or player.inventory[itemId] <= 0 then return false end
  local item = Content.getItem(itemId)
  if not item then return false end
  if not (item.consumable or item.type == "consumable") then return false end

  if itemId == "node_wallet" then
    local PortfolioManager = require("src.managers.portfolio")
    local success, message = PortfolioManager.useNodeWallet()
    if success then
      local currentValue = player.inventory[itemId] or 1
      local currentAmount = (type(currentValue) == "number") and currentValue or 1
      local newAmount = currentAmount - 1
      if newAmount <= 0 then
        player.inventory[itemId] = nil
      else
        player.inventory[itemId] = newAmount
      end
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

return Inventory
