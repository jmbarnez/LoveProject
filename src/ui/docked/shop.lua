local Theme = require("src.core.theme")
local Util = require("src.core.util")
local Content = require("src.content.content")
local Viewport = require("src.core.viewport")
local Tooltip = require("src.ui.tooltip")
local IconSystem = require("src.core.icon_system")

local Shop = {}

local MENU_WIDTH, MENU_HEIGHT = 180, 110

local function ensureContextMenu(DockedUI)
  DockedUI.contextMenu = DockedUI.contextMenu or { visible = false, quantity = "1", type = "buy" }
  return DockedUI.contextMenu
end

local function positionContextMenu(anchorX, anchorY)
  local sw, sh = Viewport.getDimensions()
  local x = math.max(10, anchorX)
  local y = math.max(10, anchorY)
  if x + MENU_WIDTH > sw then
    x = sw - MENU_WIDTH - 10
  end
  if y + MENU_HEIGHT > sh then
    y = sh - MENU_HEIGHT - 10
  end
  return x, y
end

function Shop.hideContextMenu(DockedUI)
  local menu = DockedUI and DockedUI.contextMenu
  if menu then
    menu.visible = false
  end
  if DockedUI then
    DockedUI.contextMenuActive = false
  end
end

local function openContextMenu(DockedUI, item, menuType, anchorX, anchorY)
  local menu = ensureContextMenu(DockedUI)
  local menuX, menuY = positionContextMenu(anchorX, anchorY)
  menu.visible = true
  menu.x = menuX
  menu.y = menuY
  menu.item = item
  menu.type = menuType or "buy"
  menu.quantity = "1"
  DockedUI.contextMenuActive = false
end

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

local function drawContextMenuContents(DockedUI, mx, my)
  local menu = ensureContextMenu(DockedUI)
  if not menu.visible or not menu.item then return end

  local x_, y_, w_, h_ = menu.x, menu.y, MENU_WIDTH, MENU_HEIGHT
  Theme.drawGradientGlowRect(x_, y_, w_, h_, 4, Theme.colors.bg2, Theme.colors.bg1, Theme.colors.border, Theme.effects.glowWeak)

  Theme.setColor(Theme.colors.textHighlight)
  love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
  love.graphics.printf(menu.item.name or "Unknown Item", x_, y_ + 6, w_, "center")

  local inputW, inputH = 100, 28
  local inputX, inputY = x_ + (w_ - inputW) / 2, y_ + 28
  local inputHover = mx >= inputX and mx <= inputX + inputW and my >= inputY and my <= inputY + inputH
  local inputColor = inputHover and Theme.colors.bg2 or Theme.colors.bg1
  Theme.drawGradientGlowRect(inputX, inputY, inputW, inputH, 3, inputColor, Theme.colors.bg0, Theme.colors.accent, Theme.effects.glowWeak)

  Theme.setColor(Theme.colors.text)
  local quantityText = menu.quantity or "1"
  local font = love.graphics.getFont()
  local textWidth = font:getWidth(quantityText)
  local textX = inputX + (inputW - textWidth) / 2
  love.graphics.print(quantityText, textX, inputY + 6)

  if math.floor(love.timer.getTime() * 2) % 2 == 0 and DockedUI.contextMenuActive then
    love.graphics.rectangle("fill", textX + textWidth + 2, inputY + 4, 2, inputH - 8)
  end
  menu._inputRect = { x = inputX, y = inputY, w = inputW, h = inputH }

  local qty = tonumber(quantityText) or 0
  local totalPrice = (menu.item.price or 0) * qty
  Theme.setColor(Theme.colors.accentGold)
  love.graphics.printf("Total: " .. Util.formatNumber(totalPrice), x_, y_ + 64, w_, "center")

  local btnW, btnH = 100, 28
  local btnX, btnY = x_ + (w_ - btnW) / 2, y_ + 70
  local btnHover = mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH
  local actionText = menu.type == "sell" and "SELL" or "BUY"
  local canAfford = true
  local player = DockedUI.player
  if menu.type == "buy" then
    canAfford = player and player:getGC() >= totalPrice
  else
    local cargo = player and player.components and player.components.cargo
    canAfford = cargo and cargo:has(menu.item.id, qty)
  end
  local btnColor = canAfford and (btnHover and Theme.colors.success or Theme.colors.bg3) or Theme.colors.bg1
  Theme.drawGradientGlowRect(btnX, btnY, btnW, btnH, 3, btnColor, Theme.colors.bg1, Theme.colors.border, Theme.effects.glowWeak)
  Theme.setColor(canAfford and Theme.colors.textHighlight or Theme.colors.textSecondary)
  love.graphics.printf(actionText, btnX, btnY + 6, btnW, "center")
  menu._buttonRect = { x = btnX, y = btnY, w = btnW, h = btnH }
end

function Shop.drawContextMenu(DockedUI, mx, my)
  drawContextMenuContents(DockedUI, mx or 0, my or 0)
end

local function handleContextMenuClick(DockedUI, x, y, button, player)
  local menu = ensureContextMenu(DockedUI)
  if not menu.visible or not menu.item then
    return false
  end

  local inside = x >= menu.x and x <= menu.x + MENU_WIDTH and y >= menu.y and y <= menu.y + MENU_HEIGHT
  if not inside then
    Shop.hideContextMenu(DockedUI)
    return false
  end

  if button ~= 1 then
    return true
  end

  if menu._inputRect and x >= menu._inputRect.x and x <= menu._inputRect.x + menu._inputRect.w and y >= menu._inputRect.y and y <= menu._inputRect.y + menu._inputRect.h then
    DockedUI.contextMenuActive = true
    return true
  end

  if menu._buttonRect and x >= menu._buttonRect.x and x <= menu._buttonRect.x + menu._buttonRect.w and y >= menu._buttonRect.y and y <= menu._buttonRect.y + menu._buttonRect.h then
    local qty = tonumber(menu.quantity) or 0
    if qty > 0 and player then
      if menu.type == "buy" then
        local cost = (menu.item.price or 0) * qty
        if player:getGC() >= cost then
          DockedUI.purchaseItem(menu.item, player, qty)
        end
      elseif menu.type == "sell" then
        DockedUI.sellItem(menu.item, player, qty)
      end
    end
    Shop.hideContextMenu(DockedUI)
    return true
  end

  return true
end

function Shop.mousepressed(DockedUI, x, y, button, player)
  player = player or (DockedUI and DockedUI.player)
  ensureContextMenu(DockedUI)

  if DockedUI.contextMenu and DockedUI.contextMenu.visible and DockedUI.contextMenu.item then
    local consumed = handleContextMenuClick(DockedUI, x, y, button, player)
    if consumed then
      return true, false
    end
  end

  if button ~= 1 then
    Shop.hideContextMenu(DockedUI)
    DockedUI.searchActive = false
    return false, false
  end

  DockedUI.searchActive = false
  if DockedUI._searchBar then
    local sb = DockedUI._searchBar
    if x >= sb.x and x <= sb.x + sb.w and y >= sb.y and y <= sb.y + sb.h then
      DockedUI.searchActive = true
      DockedUI.searchText = DockedUI.searchText or ""
      DockedUI.contextMenuActive = false
      Shop.hideContextMenu(DockedUI)
      return true, false
    end
  end

  if DockedUI.activeShopTab == "Buyback" and DockedUI._buybackButtons then
    for _, btn in ipairs(DockedUI._buybackButtons) do
      if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
        if player and player:getGC() >= btn.item.price then
          DockedUI.purchaseItem(btn.item, player, 1)
          table.remove(DockedUI.buybackItems, btn.index)
          Shop.hideContextMenu(DockedUI)
        end
        return true, false
      end
    end
  end

  if DockedUI.activeShopTab == "Buy" then
    if DockedUI.categoryDropdown and DockedUI.categoryDropdown:mousepressed(x, y, button) then
      Shop.hideContextMenu(DockedUI)
      return true, false
    end
  end

  if DockedUI.activeShopTab == "Buy" and DockedUI._shopItems then
    for _, itemUI in ipairs(DockedUI._shopItems) do
      if x >= itemUI.x and x <= itemUI.x + itemUI.w and y >= itemUI.y and y <= itemUI.y + itemUI.h then
        openContextMenu(DockedUI, itemUI.item, "buy", x + 10, y + 10)
        return true, false
      end
    end
  end

  if DockedUI.activeShopTab == "Sell" and DockedUI._sellItems then
    for _, itemUI in ipairs(DockedUI._sellItems) do
      if x >= itemUI.x and x <= itemUI.x + itemUI.w and y >= itemUI.y and y <= itemUI.y + itemUI.h then
        openContextMenu(DockedUI, itemUI.item, "sell", x + 10, y + 10)
        return true, false
      end
    end
  end

  Shop.hideContextMenu(DockedUI)
  return false, false
end

local function closeContextMenuIfVisible(DockedUI)
  local menu = DockedUI and DockedUI.contextMenu
  if menu and menu.visible then
    Shop.hideContextMenu(DockedUI)
    return true
  end
  return false
end

function Shop.keypressed(DockedUI, key, scancode, isrepeat, player)
  player = player or (DockedUI and DockedUI.player)

  if DockedUI.searchActive then
    if key == "backspace" then
      local text = DockedUI.searchText or ""
      DockedUI.searchText = text:sub(1, -2)
      return true, false
    elseif key == "return" or key == "kpenter" then
      DockedUI.searchActive = false
      return true, false
    elseif key == "escape" then
      DockedUI.searchActive = false
      DockedUI.searchText = DockedUI.searchText or ""
      return true, false
    end
  end

  local menu = ensureContextMenu(DockedUI)
  if menu.visible and menu.item then
    if DockedUI.contextMenuActive then
      if key == "backspace" then
        menu.quantity = (menu.quantity or "1"):sub(1, -2)
        if menu.quantity == "" then menu.quantity = "1" end
        return true, false
      elseif key == "return" or key == "kpenter" then
        local qty = tonumber(menu.quantity) or 0
        if qty > 0 and player then
          if menu.type == "buy" then
            local cost = (menu.item.price or 0) * qty
            if player:getGC() >= cost then
              DockedUI.purchaseItem(menu.item, player, qty)
            end
          elseif menu.type == "sell" then
            DockedUI.sellItem(menu.item, player, qty)
          end
        end
        Shop.hideContextMenu(DockedUI)
        return true, false
      elseif key == "escape" then
        Shop.hideContextMenu(DockedUI)
        return true, false
      end
    else
      if key == "return" or key == "kpenter" then
        local qty = tonumber(menu.quantity) or 0
        if qty > 0 and player then
          if menu.type == "buy" then
            local cost = (menu.item.price or 0) * qty
            if player:getGC() >= cost then
              DockedUI.purchaseItem(menu.item, player, qty)
            end
          elseif menu.type == "sell" then
            DockedUI.sellItem(menu.item, player, qty)
          end
        end
        Shop.hideContextMenu(DockedUI)
        return true, false
      elseif key == "escape" then
        Shop.hideContextMenu(DockedUI)
        return true, false
      end
    end
  end

  if key == "escape" then
    if closeContextMenuIfVisible(DockedUI) then
      return true, false
    end
  end

  return nil
end

function Shop.textinput(DockedUI, text, player)
  if DockedUI.searchActive then
    DockedUI.searchText = (DockedUI.searchText or "") .. text
    return true
  end

  local menu = ensureContextMenu(DockedUI)
  if menu.visible and DockedUI.contextMenuActive and menu.item then
    if text:match("%d") then
      if menu.quantity == "0" then menu.quantity = "" end
      menu.quantity = (menu.quantity or "") .. text
      return true
    end
  end

  return nil
end

return Shop


