local Theme = require("src.core.theme")
local Util = require("src.core.util")
local Content = require("src.content.content")
local Viewport = require("src.core.viewport")
local Tooltip = require("src.ui.tooltip")
local IconSystem = require("src.core.icon_system")

local Shop = {}

local function buildPlayerInventory(player)
  local items = {}
  if not player or not player.components or not player.components.cargo then
    return items
  end

  player.components.cargo:iterate(function(slot, entry)
    local def = entry.meta or Content.getItem(entry.id) or Content.getTurret(entry.id)
    if def then
      def.icon = def.icon or IconSystem.getIcon(def)
    end
    table.insert(items, {
      id = entry.id,
      qty = entry.qty,
      meta = entry.meta,
      slot = slot,
      def = def
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

function Shop.drawBuybackItems(DockedUI, x, y, w, h, player)
  if not player then return end
  local items = DockedUI.buybackItems or {}
  local rowH = 40
  local padding = 8
  local startX = x
  local startY = y
  local mx, my = Viewport.getMousePosition()
  DockedUI._buybackButtons = {}
  local currentHoveredItem = nil
  love.graphics.push()
  love.graphics.setScissor(x, y, w, h)
  for i, item in ipairs(items) do
    local sx = startX
    local sy = startY + (i - 1) * (rowH + padding)
    local dx, dy = math.floor(sx + 0.5), math.floor(sy + 0.5)
    if sy + rowH >= startY and sy <= startY + h then
      IconSystem.drawIconAny({ item.def, item.id }, dx + 4, dy + 4, rowH - 8, 1.0)
      Theme.setColor(Theme.colors.text)
      love.graphics.setFont(Theme.fonts and Theme.fonts.medium or love.graphics.getFont())
      love.graphics.print(item.name, dx + rowH + 8, dy + (rowH - 16)/2)
      Theme.setColor(Theme.colors.accentGold)
      local priceText = Util.formatNumber(item.price)
      local priceWidth = love.graphics.getFont():getWidth(priceText)
      love.graphics.print(priceText, dx + w - 200 - priceWidth - 14, dy + (rowH - 10)/2)
      Theme.drawCurrencyToken(dx + w - 200 - 12, dy + (rowH - 10)/2, 10)
      local btnW, btnH = 80, 28
      local btnX, btnY = dx + w - btnW - 8, dy + (rowH - btnH)/2
      if mx >= dx and my >= dy and mx <= dx + w - btnW - 16 and my <= dy + rowH then
        currentHoveredItem = { item = item }
      end
      local hover = mx >= btnX and my <= btnX + btnW and my >= btnY and my <= btnY + btnH
      local canAfford = player:getGC() >= item.price
      local btnColor = canAfford and (hover and Theme.colors.success or Theme.colors.bg3) or Theme.colors.bg1
      Theme.drawGradientGlowRect(btnX, btnY, btnW, btnH, 4, btnColor, Theme.colors.bg1, Theme.colors.border, Theme.effects.glowWeak)
      Theme.setColor(canAfford and Theme.colors.textHighlight or Theme.colors.textSecondary)
      love.graphics.printf("Buy", btnX, btnY + 8, btnW, "center")
      table.insert(DockedUI._buybackButtons, { x = btnX, y = btnY, w = btnW, h = btnH, item = item, index = i })
    end
  end
  love.graphics.setScissor()
  love.graphics.pop()
  if currentHoveredItem then
    if DockedUI.hoveredItem and DockedUI.hoveredItem.item.id == currentHoveredItem.item.id then
      DockedUI.hoverTimer = DockedUI.hoverTimer + love.timer.getDelta()
    else
      DockedUI.hoveredItem = currentHoveredItem
      DockedUI.hoverTimer = 0
    end
    if DockedUI.hoverTimer > 0.5 then
      local mx, my = Viewport.getMousePosition()
      Tooltip.drawItemTooltip(currentHoveredItem.item, mx, my)
    end
  else
    if not DockedUI.hoveredItem or (DockedUI.hoveredItem and not DockedUI.hoveredItem.x) then
      -- keep
    else
      DockedUI.hoveredItem = nil
      DockedUI.hoverTimer = 0
    end
  end
end

function Shop.drawPlayerInventoryForSale(DockedUI, x, y, w, h, player)
  if not player or not player.components or not player.components.cargo then return end
  local items = buildPlayerInventory(player)
  local slotSize = 64
  local padding = 6
  local cols = math.floor(w / (slotSize + padding))
  if cols < 1 then cols = 1 end
  local startX = x + (w - cols * (slotSize + padding) + padding) / 2
  local startY = y
  local mx, my = Viewport.getMousePosition()
  DockedUI._sellItems = {}
  local currentHoveredItem = nil
  love.graphics.push()
  love.graphics.setScissor(x, y, w, h)
  for i, item in ipairs(items) do
    local index = i - 1
    local row = math.floor(index / cols)
    local col = index % cols
    local sx = startX + col * (slotSize + padding)
    local sy = startY + row * (slotSize + padding)
    local dx, dy = math.floor(sx + 0.5), math.floor(sy + 0.5)
    if sy + slotSize >= startY and sy <= startY + h then
      local hover = mx >= sx and my >= sy and mx <= sx + slotSize and my <= sy + slotSize
      if hover then currentHoveredItem = { x = dx, y = dy, w = slotSize, h = slotSize, item = item } end
      Theme.drawGradientGlowRect(dx, dy, slotSize, slotSize, 4, hover and Theme.colors.bg2 or Theme.colors.bg1, Theme.colors.bg0, Theme.colors.border, Theme.effects.glowWeak)
      IconSystem.drawIconAny({ item.def, item.id }, dx + 4, dy + 4, slotSize - 8, 1.0)
      Theme.setColor(Theme.colors.accent)
      love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
      love.graphics.printf(Util.formatNumber(item.qty), dx + 4, dy + 2, slotSize - 4, "left")
      Theme.setColor(Theme.colors.textDisabled)
      love.graphics.printf("In Cargo: " .. Util.formatNumber(item.qty), dx, dy + slotSize - 14, slotSize, "center")
      Theme.setColor(Theme.colors.accentGold)
      love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
      local priceText = Util.formatNumber(item.price)
      local priceWidth = love.graphics.getFont():getWidth(priceText)
      love.graphics.print(priceText, dx + slotSize - priceWidth - 12, dy + 2)
      Theme.drawCurrencyToken(dx + slotSize - 10, dy + 2, 8)
      table.insert(DockedUI._sellItems, { x = dx, y = dy, w = slotSize, h = slotSize, item = item })
    end
  end
  if currentHoveredItem then
    if DockedUI.hoveredItem and DockedUI.hoveredItem.item.id == currentHoveredItem.item.id then
      DockedUI.hoverTimer = DockedUI.hoverTimer + love.timer.getDelta()
    else
      DockedUI.hoveredItem = currentHoveredItem
      DockedUI.hoverTimer = 0
    end
    if DockedUI.hoverTimer > 0.5 then
      local mx, my = Viewport.getMousePosition()
      Tooltip.drawItemTooltip(currentHoveredItem.item, mx, my)
    end
  else
    DockedUI.hoveredItem = nil
    DockedUI.hoverTimer = 0
  end
  love.graphics.setScissor()
  love.graphics.pop()
end

function Shop.drawShopItems(DockedUI, x, y, w, h, player)
  if not player then return end
  local allShopItems = {}
  local seenIds = {}
  local function addItem(entry)
    if entry and entry.id and not seenIds[entry.id] then
      table.insert(allShopItems, entry)
      seenIds[entry.id] = true
    end
  end
  for _, turret in ipairs(Content.turrets or {}) do
    if turret.price then
      addItem({ type = "turret", data = turret, price = turret.price, name = turret.name, description = turret.description, id = turret.id, category = "Weapons" })
    end
  end
  for _, item in ipairs(Content.items) do
    if item.price then
      addItem({ type = "item", data = item, price = item.price, name = item.name, description = item.description, id = item.id, category = item.type == "consumable" and "Consumables" or "Materials" })
    end
  end
  local shopItems = {}
  for _, item in ipairs(allShopItems) do
    local matchesCategory = DockedUI.selectedCategory == "All" or item.category == DockedUI.selectedCategory
    local matchesSearch = DockedUI.searchText == "" or string.lower(item.name):find(string.lower(DockedUI.searchText), 1, true)
    if matchesCategory and matchesSearch then table.insert(shopItems, item) end
  end
  table.sort(shopItems, function(a, b) return a.price < b.price end)
  local slotSize = 64
  local slotW = slotSize
  local slotH = slotSize
  local padding = 6
  local cols = math.floor(w / (slotW + padding))
  if cols < 1 then cols = 1 end
  local startX = x + (w - cols * (slotW + padding) + padding) / 2
  local startY = y
  local mx, my = Viewport.getMousePosition()
  DockedUI._shopItems = {}
  local currentHoveredItem = nil
  local itemFullH = slotH + padding
  
  love.graphics.push()

  for i, item in ipairs(shopItems) do
    local index = i - 1
    local row = math.floor(index / cols)
    local col = index % cols
    local sx = startX + col * (slotW + padding)
    local sy = startY + row * (slotH + padding)
    local dx = math.floor(sx + 0.5)
    local dy = math.floor(sy + 0.5)

    local hover = mx >= sx and my >= sy and mx <= sx + slotW and my <= sy + slotH
    if hover then currentHoveredItem = { x = dx, y = dy, w = slotW, h = slotH, item = item } end

    if hover then
      Theme.drawGradientGlowRect(dx, dy, slotW, slotH, 4, Theme.colors.bg2, Theme.colors.bg1, Theme.colors.border, Theme.effects.glowWeak)
    else
      Theme.drawGradientGlowRect(dx, dy, slotW, slotH, 4, Theme.colors.bg1, Theme.colors.bg0, Theme.colors.border, Theme.effects.glowWeak)
    end
    local iconSize = 48
    local iconPad = (slotW - iconSize) / 2
    local subject = Content.getTurret(item.id) or Content.getItem(item.id) or item.id
    IconSystem.drawIconAny({ subject, item.id }, dx + iconPad, dy + iconPad, iconSize, 1.0)
    Theme.setColor(Theme.colors.accent)
    love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
    love.graphics.printf("∞", dx + 4, dy + 2, slotW - 4, "left")
    local qtyOwned = 0
    if player and player.components and player.components.cargo and player.components.cargo.getQuantity then
      qtyOwned = player.components.cargo:getQuantity(item.id)
    end
    local countText = Util.formatNumber(qtyOwned)
    local countWidth = love.graphics.getFont():getWidth(countText)
    local countX = dx + slotW - countWidth - 4
    local countY = dy + slotH - 14
    if qtyOwned > 0 then Theme.setColor(Theme.colors.textHighlight) else Theme.setColor(Theme.colors.textDisabled) end
    love.graphics.print(countText, countX, countY)
    Theme.setColor(Theme.colors.accentGold)
    love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
    local priceText = Util.formatNumber(item.price)
    local priceWidth = love.graphics.getFont():getWidth(priceText)
    love.graphics.print(priceText, dx + slotW - priceWidth - 12, dy + 2)
    Theme.drawCurrencyToken(dx + slotW - 10, dy + 2, 8)
    table.insert(DockedUI._shopItems, { x = dx, y = dy, w = slotW, h = slotH, item = item, canAfford = (player:getGC() >= item.price) })
  end
  if currentHoveredItem then
    if DockedUI.hoveredItem and DockedUI.hoveredItem.item.id == currentHoveredItem.item.id then
      DockedUI.hoverTimer = DockedUI.hoverTimer + love.timer.getDelta()
    else
      DockedUI.hoveredItem = currentHoveredItem
      DockedUI.hoverTimer = 0
    end
    if DockedUI.hoverTimer > 0.5 then
      local mx, my = Viewport.getMousePosition()
      Tooltip.drawItemTooltip(currentHoveredItem.item, mx, my)
    end
  else
    DockedUI.hoveredItem = nil
    DockedUI.hoverTimer = 0
  end
  love.graphics.pop()
end

return Shop


