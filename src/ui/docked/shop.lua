local Theme = require("src.core.theme")
local Util = require("src.core.util")
local Content = require("src.content.content")
local Viewport = require("src.core.viewport")
local Tooltip = require("src.ui.tooltip")
local IconSystem = require("src.core.icon_system")

local Shop = {}

local MENU_WIDTH, MENU_HEIGHT = 200, 120

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
  menu.type = menuType or "both" -- Can be "buy", "sell", or "both"
  menu.quantity = "1"
  DockedUI.contextMenuActive = false
  
  -- Pre-calculate button rectangles for both Buy and Sell buttons
  local btnW, btnH = 80, 28
  local btnSpacing = 8
  local totalBtnWidth = (btnW * 2) + btnSpacing
  local startX = menuX + (MENU_WIDTH - totalBtnWidth) / 2
  
  menu._buyButtonRect = { x = startX, y = menuY + 80, w = btnW, h = btnH }
  menu._sellButtonRect = { x = startX + btnW + btnSpacing, y = menuY + 80, w = btnW, h = btnH }
  
  -- Pre-calculate input rectangle
  local inputW, inputH = 100, 28
  local inputX, inputY = menuX + (MENU_WIDTH - inputW) / 2, menuY + 28
  menu._inputRect = { x = inputX, y = inputY, w = inputW, h = inputH }
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
      -- Add hover highlighting for the entire item row
      local itemHover = mx >= dx and my >= dy and mx <= dx + w - btnW - 16 and my <= dy + rowH
      if itemHover then
        Theme.drawGradientGlowRect(dx, dy, w - btnW - 16, rowH, 4, Theme.colors.hover, Theme.colors.bg0, Theme.colors.border, Theme.effects.glowWeak, false)
      end
      
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
      Theme.drawGradientGlowRect(btnX, btnY, btnW, btnH, 4, btnColor, Theme.colors.bg1, Theme.colors.border, Theme.effects.glowWeak, false)
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
      local TooltipManager = require("src.ui.tooltip_manager")
      TooltipManager.setTooltip(currentHoveredItem.item, mx, my)
    end
  else
    if not DockedUI.hoveredItem or (DockedUI.hoveredItem and not DockedUI.hoveredItem.x) then
      -- keep
    else
      DockedUI.hoveredItem = nil
      DockedUI.hoverTimer = 0
    end
    -- Clear tooltip when not hovering
    local TooltipManager = require("src.ui.tooltip_manager")
    TooltipManager.clearTooltip()
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
      Theme.drawGradientGlowRect(dx, dy, slotSize, slotSize, 4, hover and Theme.colors.hover or Theme.colors.bg1, Theme.colors.bg0, Theme.colors.border, Theme.effects.glowWeak, false)
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
      local TooltipManager = require("src.ui.tooltip_manager")
      TooltipManager.setTooltip(currentHoveredItem.item, mx, my)
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
  love.graphics.setScissor(x, y, w, h)

  for i, item in ipairs(shopItems) do
    local index = i - 1
    local row = math.floor(index / cols)
    local col = index % cols
    local sx = startX + col * (slotW + padding)
    local sy = startY + row * (slotH + padding)
    local dx = math.floor(sx + 0.5)
    local dy = math.floor(sy + 0.5)

    -- Only render and add to click detection if item is within visible bounds
    if sy + slotH >= y and sy <= y + h then
      local hover = mx >= sx and my >= sy and mx <= sx + slotW and my <= sy + slotH
      if hover then 
        currentHoveredItem = { x = dx, y = dy, w = slotW, h = slotH, item = item } 
      end

      if hover then
        Theme.drawGradientGlowRect(dx, dy, slotW, slotH, 4, Theme.colors.hover, Theme.colors.bg0, Theme.colors.border, Theme.effects.glowWeak, false)
      else
        Theme.drawGradientGlowRect(dx, dy, slotW, slotH, 4, Theme.colors.bg1, Theme.colors.bg0, Theme.colors.border, Theme.effects.glowWeak, false)
      end
      local iconSize = 48
      local iconPad = (slotW - iconSize) / 2
      local subject = Content.getTurret(item.id) or Content.getItem(item.id) or item.id
      IconSystem.drawIconAny({ subject, item.id }, dx + iconPad, dy + iconPad, iconSize, 1.0)
      Theme.setColor(Theme.colors.accent)
      love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
      love.graphics.printf("∞", dx + 4, dy + slotH - 14, slotW - 4, "left")
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
      local TooltipManager = require("src.ui.tooltip_manager")
      TooltipManager.setTooltip(currentHoveredItem.item, mx, my)
    end
  else
    DockedUI.hoveredItem = nil
    DockedUI.hoverTimer = 0
    -- Clear tooltip when not hovering
    local TooltipManager = require("src.ui.tooltip_manager")
    TooltipManager.clearTooltip()
  end
  love.graphics.setScissor()
  love.graphics.pop()
end

local function drawContextMenuContents(DockedUI, mx, my)
  local menu = ensureContextMenu(DockedUI)
  if not menu.visible or not menu.item then return end

  local x_, y_, w_, h_ = menu.x, menu.y, MENU_WIDTH, MENU_HEIGHT
  
  -- Draw main border with enhanced styling
  Theme.drawGradientGlowRect(x_, y_, w_, h_, 6, Theme.colors.bg2, Theme.colors.bg1, Theme.colors.border, Theme.effects.glowWeak, false)
  
  -- Add inner border for more definition
  Theme.setColor(Theme.colors.border)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", x_ + 2, y_ + 2, w_ - 4, h_ - 4)

  -- Item name with compact spacing
  Theme.setColor(Theme.colors.textHighlight)
  love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
  love.graphics.printf(menu.item.name or "Unknown Item", x_ + 4, y_ + 8, w_ - 8, "center")

  -- Compact input field
  local inputW, inputH = 80, 24
  local inputX, inputY = x_ + (w_ - inputW) / 2, y_ + 24
  local inputHover = mx >= inputX and mx <= inputX + inputW and my >= inputY and my <= inputY + inputH
  
  -- Enhanced input field visual feedback
  local inputColor = inputHover and Theme.colors.bg2 or Theme.colors.bg1
  local inputBorderColor = inputHover and Theme.colors.accent or Theme.colors.border
  
  Theme.drawGradientGlowRect(inputX, inputY, inputW, inputH, 3, inputColor, Theme.colors.bg0, inputBorderColor, Theme.effects.glowWeak)
  
  -- Add hover glow effect for input field
  if inputHover then
    Theme.drawGradientGlowRect(inputX - 1, inputY - 1, inputW + 2, inputH + 2, 1, Theme.colors.accent, Theme.colors.bg0, Theme.colors.accent, Theme.effects.glowWeak)
  end

  Theme.setColor(Theme.colors.text)
  local quantityText = menu.quantity or "1"
  local font = love.graphics.getFont()
  
  -- Show placeholder "1" only when not actively editing and field is empty
  local displayText = quantityText
  if not DockedUI.contextMenuActive and (quantityText == "" or quantityText == "1") then
    displayText = "1"  -- Show placeholder when not editing
  elseif DockedUI.contextMenuActive and quantityText == "" then
    displayText = ""   -- Show empty when actively editing
  end
  
  local textWidth = font:getWidth(displayText)
  local textX = inputX + (inputW - textWidth) / 2
  love.graphics.print(displayText, textX, inputY + 4)

  if math.floor(love.timer.getTime() * 2) % 2 == 0 and DockedUI.contextMenuActive then
    love.graphics.rectangle("fill", textX + textWidth + 2, inputY + 2, 2, inputH - 4)
  end
  -- Store input rectangle for click detection
  menu._inputRect = { x = inputX, y = inputY, w = inputW, h = inputH }

  local qty = tonumber(quantityText) or 0
  local totalPrice = (menu.item.price or 0) * qty
  Theme.setColor(Theme.colors.accentGold)
  love.graphics.printf("Total: " .. Util.formatNumber(totalPrice), x_ + 4, y_ + 52, w_ - 8, "center")

  -- Compact Buy and Sell buttons
  local btnW, btnH = 70, 24
  local btnSpacing = 6
  local totalBtnWidth = (btnW * 2) + btnSpacing
  local startX = x_ + (w_ - totalBtnWidth) / 2
  local btnY = y_ + 68
  
  local buyBtnX = startX
  local sellBtnX = startX + btnW + btnSpacing
  
  local buyBtnHover = mx >= buyBtnX and mx <= buyBtnX + btnW and my >= btnY and my <= btnY + btnH
  local sellBtnHover = mx >= sellBtnX and mx <= sellBtnX + btnW and my >= btnY and my <= btnY + btnH
  
  local player = DockedUI.player
  local checkQty = qty > 0 and qty or 1
  local checkPrice = (menu.item.price or 0) * checkQty
  
  -- Check affordability for both buttons
  local canBuy = player and player:getGC() >= checkPrice
  local canSell = false
  if player and player.components and player.components.cargo then
    canSell = player.components.cargo:has(menu.item.id, checkQty)
  end
  
  -- Draw Buy button
  local buyBtnColor, buyTextColor, buyBorderColor
  if not canBuy then
    buyBtnColor = Theme.colors.bg1
    buyTextColor = Theme.colors.textDisabled
    buyBorderColor = Theme.colors.danger
  elseif buyBtnHover then
    buyBtnColor = Theme.colors.success
    buyTextColor = Theme.colors.textHighlight
    buyBorderColor = Theme.colors.success
  else
    buyBtnColor = Theme.colors.bg3
    buyTextColor = Theme.colors.textHighlight
    buyBorderColor = Theme.colors.border
  end
  
  -- Draw Buy button with enhanced borders
  Theme.drawGradientGlowRect(buyBtnX, btnY, btnW, btnH, 4, buyBtnColor, Theme.colors.bg1, buyBorderColor, Theme.effects.glowWeak)
  if buyBtnHover and canBuy then
    Theme.drawGradientGlowRect(buyBtnX - 2, btnY - 2, btnW + 4, btnH + 4, 2, Theme.colors.success, Theme.colors.bg0, Theme.colors.success, Theme.effects.glowStrong)
  end
  
  -- Add inner border for Buy button
  Theme.setColor(buyBorderColor)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", buyBtnX + 1, btnY + 1, btnW - 2, btnH - 2)
  
  Theme.setColor(buyTextColor)
  love.graphics.printf("BUY", buyBtnX, btnY + 4, btnW, "center")
  
  -- Draw Sell button
  local sellBtnColor, sellTextColor, sellBorderColor
  if not canSell then
    sellBtnColor = Theme.colors.bg1
    sellTextColor = Theme.colors.textDisabled
    sellBorderColor = Theme.colors.danger
  elseif sellBtnHover then
    sellBtnColor = Theme.colors.warning
    sellTextColor = Theme.colors.textHighlight
    sellBorderColor = Theme.colors.warning
  else
    sellBtnColor = Theme.colors.bg3
    sellTextColor = Theme.colors.textHighlight
    sellBorderColor = Theme.colors.border
  end
  
  -- Draw Sell button with enhanced borders
  Theme.drawGradientGlowRect(sellBtnX, btnY, btnW, btnH, 4, sellBtnColor, Theme.colors.bg1, sellBorderColor, Theme.effects.glowWeak)
  if sellBtnHover and canSell then
    Theme.drawGradientGlowRect(sellBtnX - 2, btnY - 2, btnW + 4, btnH + 4, 2, Theme.colors.warning, Theme.colors.bg0, Theme.colors.warning, Theme.effects.glowStrong)
  end
  
  -- Add inner border for Sell button
  Theme.setColor(sellBorderColor)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", sellBtnX + 1, btnY + 1, btnW - 2, btnH - 2)
  
  Theme.setColor(sellTextColor)
  love.graphics.printf("SELL", sellBtnX, btnY + 4, btnW, "center")
  
  -- Update button rectangles for click detection
  menu._buyButtonRect = { x = buyBtnX, y = btnY, w = btnW, h = btnH }
  menu._sellButtonRect = { x = sellBtnX, y = btnY, w = btnW, h = btnH }
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

  -- Handle Buy button click
  if menu._buyButtonRect and x >= menu._buyButtonRect.x and x <= menu._buyButtonRect.x + menu._buyButtonRect.w and y >= menu._buyButtonRect.y and y <= menu._buyButtonRect.y + menu._buyButtonRect.h then
    -- Play click sound
    local Sound = require("src.core.sound")
    Sound.playSFX("button_click")
    
    local qty = tonumber(menu.quantity) or 0
    if qty > 0 and player then
      local cost = (menu.item.price or 0) * qty
      if player:getGC() >= cost then
        DockedUI.purchaseItem(menu.item, player, qty)
      end
    end
    Shop.hideContextMenu(DockedUI)
    return true
  end
  
  -- Handle Sell button click
  if menu._sellButtonRect and x >= menu._sellButtonRect.x and x <= menu._sellButtonRect.x + menu._sellButtonRect.w and y >= menu._sellButtonRect.y and y <= menu._sellButtonRect.y + menu._sellButtonRect.h then
    -- Play click sound
    local Sound = require("src.core.sound")
    Sound.playSFX("button_click")
    
    local qty = tonumber(menu.quantity) or 0
    if qty > 0 and player then
      DockedUI.sellItem(menu.item, player, qty)
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

  if DockedUI._buybackButtons then
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

  -- Handle category dropdown clicks
  if DockedUI.categoryDropdown and DockedUI.categoryDropdown:mousepressed(x, y, button) then
    Shop.hideContextMenu(DockedUI)
    return true, false
  end

  -- Handle clicks on shop items
  if DockedUI._shopItems then
    for _, itemUI in ipairs(DockedUI._shopItems) do
      if x >= itemUI.x and x <= itemUI.x + itemUI.w and y >= itemUI.y and y <= itemUI.y + itemUI.h then
        openContextMenu(DockedUI, itemUI.item, "both", x + 10, y + 10)
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
      if #text > 0 then
        DockedUI.searchText = text:sub(1, -2)
      end
      return true, false
    elseif key == "return" or key == "kpenter" then
      DockedUI.searchActive = false
      return true, false
    elseif key == "escape" then
      DockedUI.searchActive = false
      DockedUI.searchText = DockedUI.searchText or ""
      return true, false
    else
      -- Allow other keys to be handled by textinput
      return false, false
    end
  end

  local menu = ensureContextMenu(DockedUI)
  if menu.visible and menu.item then
    if DockedUI.contextMenuActive then
      if key == "backspace" then
        local qty = menu.quantity or ""
        if #qty > 0 then
          menu.quantity = qty:sub(1, -2)
        end
        -- Don't reset to "1" when field becomes empty - let it stay empty
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
      -- Clear the field if it contains the default "1" placeholder
      if menu.quantity == "1" then menu.quantity = "" end
      menu.quantity = (menu.quantity or "") .. text
      return true
    end
  end

  return false
end

return Shop


