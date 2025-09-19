local Theme = require("src.core.theme")
local Util = require("src.core.util")
local Content = require("src.content.content")
local Viewport = require("src.core.viewport")
local Tooltip = require("src.ui.tooltip")
local Input = require("src.core.input")
local Notifications = require("src.ui.notifications")
local Ship = require("src.ui.ship")
local Quests = require("src.ui.quests")
local Nodes = require("src.ui.nodes")

local DockedUI = {}

-- State
DockedUI.visible = false
DockedUI.player = nil
DockedUI.shopScroll = 0
DockedUI.selectedCategory = "All"
DockedUI.activeShopTab = "Buy" -- Buy | Sell | Buyback
DockedUI.buybackItems = {}
DockedUI.searchText = ""
DockedUI.searchActive = false
DockedUI.hoveredItem = nil
DockedUI.hoverTimer = 0
DockedUI.drag = nil
DockedUI.contextMenu = { visible = false, x = 0, y = 0, item = nil, quantity = "1", type = "buy" }
DockedUI.categoryDropdownOpen = false
DockedUI._bountyRef = nil

-- New Tabbed Interface State
DockedUI.tabs = {"Shop", "Ship", "Quests", "Nodes"}
DockedUI.activeTab = "Shop"

-- Window properties (fullscreen)
DockedUI.windowW = 0
DockedUI.windowH = 0
DockedUI.windowX = 0
DockedUI.windowY = 0

-- Initialize the docked window
function DockedUI.init()
  local sw, sh = Viewport.getDimensions()
  DockedUI.windowW = sw
  DockedUI.windowH = sh
  DockedUI.windowX = 0
  DockedUI.windowY = 0
  DockedUI.equipment = Ship:new()
  DockedUI.quests = Quests:new()
  DockedUI.nodes = Nodes:new()
end

-- Show the docked window
function DockedUI.show(player, station)
  DockedUI.visible = true
  DockedUI.player = player
  DockedUI.station = station
  if DockedUI.quests then
    DockedUI.quests.station = station
  end
end

function DockedUI.setBounty(bounty)
  DockedUI._bountyRef = bounty
  if DockedUI.quests then
    DockedUI.quests.bountyRef = bounty
  end
end

-- Hide the docked window
function DockedUI.hide()
  DockedUI.visible = false
  DockedUI.player = nil
end

-- Check if docked window is visible
function DockedUI.isVisible()
  return DockedUI.visible
end

-- Draw the docked window
function DockedUI.draw(player)
  if not DockedUI.visible or not player or not player.docked then return end
  
  -- Update window dimensions to match viewport (fullscreen)
  local sw, sh = Viewport.getDimensions()
  DockedUI.windowW = sw
  DockedUI.windowH = sh
  DockedUI.windowX = 0
  DockedUI.windowY = 0
  
  local x, y, w, h = DockedUI.windowX, DockedUI.windowY, DockedUI.windowW, DockedUI.windowH
  local mx, my = Viewport.getMousePosition()
  
  -- Window background
  Theme.drawGradientGlowRect(x, y, w, h, 8,
    Theme.colors.bg1, Theme.colors.bg0,
    Theme.colors.accent, Theme.effects.glowWeak)
  Theme.drawEVEBorder(x, y, w, h, 8, Theme.colors.border, 6)
  
  -- Title bar
  local titleH = 32
  Theme.drawGradientGlowRect(x, y, w, titleH, 8,
    Theme.colors.bg3, Theme.colors.bg2,
    Theme.colors.accent, Theme.effects.glowWeak)
  
  -- Title text
  Theme.setColor(Theme.colors.textHighlight)
  love.graphics.setFont(Theme.fonts and Theme.fonts.medium or love.graphics.getFont())
  local font = love.graphics.getFont()
  local stationName = (DockedUI.station and DockedUI.station.components.station.name) or "Station"
  local titleText = stationName .. " Services"
  local textWidth = font:getWidth(titleText)
  local textHeight = font:getHeight()
  love.graphics.print(titleText, x + (w - textWidth) / 2, y + (titleH - textHeight) / 2)
  
  -- Close button
  local closeRect = { x = x + w - 26, y = y + 6, w = 20, h = 20 }
  local closeHover = mx >= closeRect.x and mx <= closeRect.x + closeRect.w and my >= closeRect.y and my <= closeRect.y + closeRect.h
  Theme.drawCloseButton(closeRect, closeHover)
  DockedUI._closeButton = closeRect
  
  -- Main tabs
  local mainTabY = y + titleH + 8
  local mainTabH = 28
  DockedUI.drawMainTabs(x + 12, mainTabY, w - 24, mainTabH)

  -- Content area
  local contentY = mainTabY + mainTabH + 8
  local contentH = h - (contentY - y) - 12

  if DockedUI.activeTab == "Shop" then
    -- Category tabs
    local tabY = contentY
    local tabH = 28
    DockedUI.drawCategoryTabs(x + 12, tabY, w - 24, tabH)
    
    -- Shop content area
    local shopContentY = tabY + tabH + 8
    local shopContentH = h - (shopContentY - y) - 12
    if DockedUI.activeShopTab == "Buy" then
      DockedUI.drawShopItems(x + 12, shopContentY, w - 24, shopContentH, player)
    elseif DockedUI.activeShopTab == "Sell" then
      DockedUI.drawPlayerInventoryForSale(x + 12, shopContentY, w - 24, shopContentH, player)
    elseif DockedUI.activeShopTab == "Buyback" then
      DockedUI.drawBuybackItems(x + 12, shopContentY, w - 24, shopContentH, player)
    end
  elseif DockedUI.activeTab == "Ship" then
    DockedUI.equipment:draw(player, x + 12, contentY, w - 24, contentH)
  elseif DockedUI.activeTab == "Quests" then
    DockedUI.quests:draw(player, x + 12, contentY, w - 24, contentH)
  elseif DockedUI.activeTab == "Nodes" then
    DockedUI.nodes:draw(player, x + 12, contentY, w - 24, contentH)
  end

  -- Draw dropdown options on top of everything else
  if DockedUI.categoryDropdownOpen then
    local dd = DockedUI._categoryDropdown
    if dd then
      local categories = {"All", "Weapons", "Consumables", "Materials"}
      local optionH = 24
      for i, category in ipairs(categories) do
        local optY = dd.y + dd.h + (i-1) * optionH
        local hover = mx >= dd.x and mx <= dd.x + dd.w and my >= optY and my <= optY + optionH
        Theme.drawGradientGlowRect(dd.x, optY, dd.w, optionH, 4,
          hover and Theme.colors.bg3 or Theme.colors.bg2,
          Theme.colors.bg1, Theme.colors.border, Theme.effects.glowWeak)
        Theme.setColor(Theme.colors.text)
        love.graphics.print(category, dd.x + 8, optY + (optionH - 12) * 0.5)
      end
    end
  end
  
-- Draw context menu for numeric purchase/sale
if DockedUI.contextMenu.visible then
  local menu = DockedUI.contextMenu
  local x_, y_, w_, h_ = menu.x, menu.y, 200, 160
  Theme.drawGradientGlowRect(x_, y_, w_, h_, 6, Theme.colors.bg2, Theme.colors.bg1, Theme.colors.border, Theme.effects.glowWeak)

  -- Item name
  Theme.setColor(Theme.colors.textHighlight)
  love.graphics.setFont(Theme.fonts and Theme.fonts.medium or love.graphics.getFont())
  love.graphics.printf(menu.item.name, x_, y_ + 8, w_, "center")

  -- Quantity input field
  local inputW, inputH = 100, 28
  local inputX, inputY = x_ + (w_ - inputW) / 2, y_ + 36
  Theme.drawGradientGlowRect(inputX, inputY, inputW, inputH, 3,
    Theme.colors.bg0, Theme.colors.bg1, Theme.colors.accent, Theme.effects.glowWeak)
  Theme.setColor(Theme.colors.text)
  local textWidth = love.graphics.getFont():getWidth(menu.quantity)
  local textX = inputX + (inputW - textWidth) / 2
  love.graphics.print(menu.quantity, textX, inputY + 6)

  -- Blinking cursor
  if math.floor(love.timer.getTime() * 2) % 2 == 0 then
      love.graphics.rectangle("fill", textX + textWidth + 2, inputY + 4, 2, inputH - 8)
  end

  -- +/- buttons
  local btnSize = 28
  Theme.drawGradientGlowRect(inputX - btnSize - 4, inputY, btnSize, btnSize, 3, Theme.colors.bg3, Theme.colors.bg2, Theme.colors.border, Theme.effects.glowWeak)
  love.graphics.printf("-", inputX - btnSize - 4, inputY + 6, btnSize, "center")
  Theme.drawGradientGlowRect(inputX + inputW + 4, inputY, btnSize, btnSize, 3, Theme.colors.bg3, Theme.colors.bg2, Theme.colors.border, Theme.effects.glowWeak)
  love.graphics.printf("+", inputX + inputW + 4, inputY + 6, btnSize, "center")

  -- Total price
  local qty = tonumber(menu.quantity) or 0
  local totalPrice = (menu.item.price or 0) * qty
  Theme.setColor(Theme.colors.text)
  love.graphics.printf("Total: " .. Util.formatNumber(totalPrice), x_, y_ + 72, w_, "center")

  -- Player balance
  Theme.setColor(Theme.colors.textDisabled)
  love.graphics.printf("Balance: " .. Util.formatNumber(player:getGC()), x_, y_ + 90, w_, "center")

  -- Action button (Buy/Sell)
  local btnW, btnH = 120, 32
  local btnX, btnY = x_ + (w_ - btnW) / 2, y_ + 116
  local mx2, my2 = Viewport.getMousePosition()
  local btnHover = mx2 >= btnX and mx2 <= btnX + btnW and my2 >= btnY and my2 <= btnY + btnH
  local actionText = menu.type == "buy" and "BUY" or "SELL"
  local canAfford = true

  if menu.type == "buy" then
    canAfford = DockedUI.player and DockedUI.player:getGC() >= totalPrice
  else
    canAfford = DockedUI.player and DockedUI.player.inventory and
               DockedUI.player.inventory[menu.item.id] and
               DockedUI.player.inventory[menu.item.id] >= qty
  end

  local btnColor = canAfford and (btnHover and Theme.colors.success or Theme.colors.bg3) or Theme.colors.bg1
  Theme.drawGradientGlowRect(btnX, btnY, btnW, btnH, 4, btnColor, Theme.colors.bg1, Theme.colors.border, Theme.effects.glowWeak)
  Theme.setColor(canAfford and Theme.colors.textHighlight or Theme.colors.textSecondary)
  love.graphics.printf(actionText, btnX, btnY + 8, btnW, "center")
end

-- Store window rect for dragging
DockedUI._titleBarRect = { x = x, y = y, w = w - 20 - 8, h = titleH }
end

function DockedUI.drawMainTabs(x, y, w, h)
  DockedUI._mainTabs = {}
  local mainTabWidth = 100
  local mainTabSpacing = 4
  local mx, my = Viewport.getMousePosition()

  for i, tabName in ipairs(DockedUI.tabs) do
    local tabX = x + (i - 1) * (mainTabWidth + mainTabSpacing)
    local isSelected = DockedUI.activeTab == tabName
    local hover = mx >= tabX and mx <= tabX + mainTabWidth and my >= y and my <= y + h
    
    local tabColor = isSelected and Theme.colors.primary or (hover and Theme.colors.bg3 or Theme.colors.bg2)
    local borderColor = isSelected and Theme.colors.accent or Theme.colors.border
    
    Theme.drawGradientGlowRect(tabX, y, mainTabWidth, h, 4,
      tabColor, Theme.colors.bg1, borderColor, Theme.effects.glowWeak)
    
    Theme.setColor(isSelected and Theme.colors.textHighlight or Theme.colors.textSecondary)
    love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
    local textW = love.graphics.getFont():getWidth(tabName)
    love.graphics.print(tabName, tabX + (mainTabWidth - textW) * 0.5, y + (h - 12) * 0.5)
    
    table.insert(DockedUI._mainTabs, {
      x = tabX, y = y, w = mainTabWidth, h = h, name = tabName
    })
  end
end

-- Draw main Buy/Sell/Buyback tabs and category tabs
function DockedUI.drawCategoryTabs(x, y, w, h)
  local shopTabs = {"Buy", "Sell", "Buyback"}
  DockedUI._shopTabs = {}
  local shopTabWidth = 80
  local shopTabSpacing = 4

  local mx, my = Viewport.getMousePosition()

  -- Draw main Buy/Sell tabs
  for i, tabName in ipairs(shopTabs) do
    local tabX = x + (i - 1) * (shopTabWidth + shopTabSpacing)
    local isSelected = DockedUI.activeShopTab == tabName
    local hover = mx >= tabX and mx <= tabX + shopTabWidth and my >= y and my <= y + h
    
    local tabColor = isSelected and Theme.colors.primary or (hover and Theme.colors.bg3 or Theme.colors.bg2)
    local borderColor = isSelected and Theme.colors.accent or Theme.colors.border
    
    Theme.drawGradientGlowRect(tabX, y, shopTabWidth, h, 4,
      tabColor, Theme.colors.bg1, borderColor, Theme.effects.glowWeak)
    
    Theme.setColor(isSelected and Theme.colors.textHighlight or Theme.colors.textSecondary)
    love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
    local textW = love.graphics.getFont():getWidth(tabName)
    love.graphics.print(tabName, tabX + (shopTabWidth - textW) * 0.5, y + (h - 12) * 0.5)
    
    table.insert(DockedUI._shopTabs, {
      x = tabX, y = y, w = shopTabWidth, h = h, name = tabName
    })
  end

  -- Category dropdown and search bar (only for Buy tab)
  local searchWidth = 150
  if DockedUI.activeShopTab == "Buy" then
    local categories = {"All", "Weapons", "Consumables", "Materials"}
    local dropdownWidth = 150
    local filterX = x + #shopTabs * (shopTabWidth + shopTabSpacing) + 16
    
    -- Draw dropdown box
    Theme.drawGradientGlowRect(filterX, y, dropdownWidth, h, 4,
      Theme.colors.bg2, Theme.colors.bg1, Theme.colors.border, Theme.effects.glowWeak)
    
    -- Draw selected category text
    Theme.setColor(Theme.colors.text)
    love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
    love.graphics.print(DockedUI.selectedCategory, filterX + 8, y + (h - 12) * 0.5)
    
    -- Draw dropdown arrow
    love.graphics.print("▼", filterX + dropdownWidth - 20, y + (h - 12) * 0.5)
    
    DockedUI._categoryDropdown = { x = filterX, y = y, w = dropdownWidth, h = h }

    -- Dropdown is drawn in the main draw function to render on top
  else
    DockedUI._categoryDropdown = nil
  end
  
  -- Search bar
  local searchX = x + w - searchWidth
  local searchIsActive = DockedUI.searchActive
  Theme.drawGradientGlowRect(searchX, y, searchWidth, h, 3,
    Theme.colors.bg0, Theme.colors.bg1, searchIsActive and Theme.colors.accent or Theme.colors.border, Theme.effects.glowWeak)
  
  love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
  if DockedUI.searchText == "" and not searchIsActive then
    Theme.setColor(Theme.colors.textDisabled)
    love.graphics.print("Search...", searchX + 6, y + (h - 12) * 0.5)
  else
    Theme.setColor(Theme.colors.text)
    love.graphics.print(DockedUI.searchText, searchX + 6, y + (h - 12) * 0.5)
  end
  
  if searchIsActive and math.fmod(love.timer.getTime(), 1) > 0.5 then
    local textW = love.graphics.getFont():getWidth(DockedUI.searchText)
    love.graphics.rectangle("fill", searchX + 6 + textW, y + 4, 2, h - 8)
  end
  
  DockedUI._searchBar = { x = searchX, y = y, w = searchWidth, h = h }
end

-- Draw buyback items
function DockedUI.drawBuybackItems(x, y, w, h, player)
  if not player then return end

  local items = DockedUI.buybackItems or {}

  -- List layout
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
      -- Icon
      local icon = item.def.icon
      if icon and type(icon) == "userdata" then
        Theme.setColor({1,1,1,1})
        local scale = math.min((rowH - 8) / icon:getWidth(), (rowH - 8) / icon:getHeight())
        love.graphics.draw(icon, dx + 4, dy + 4, 0, scale, scale)
      end

      -- Name
      Theme.setColor(Theme.colors.text)
      love.graphics.setFont(Theme.fonts and Theme.fonts.medium or love.graphics.getFont())
      love.graphics.print(item.name, dx + rowH + 8, dy + (rowH - 16)/2)

      -- Price
      Theme.setColor(Theme.colors.accentGold)
      local priceText = Util.formatNumber(item.price)
      local priceWidth = love.graphics.getFont():getWidth(priceText)
      love.graphics.print(priceText, dx + w - 200 - priceWidth - 14, dy + (rowH - 10)/2)
      Theme.drawCurrencyToken(dx + w - 200 - 12, dy + (rowH - 10)/2, 10)

      -- Buy button
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
  else
    if not DockedUI.hoveredItem or (DockedUI.hoveredItem and not DockedUI.hoveredItem.x) then
      -- Don't clear if the hover is from another panel
    else
      DockedUI.hoveredItem = nil
      DockedUI.hoverTimer = 0
    end
  end
end

-- Draw player inventory for selling
function DockedUI.drawPlayerInventoryForSale(x, y, w, h, player)
  if not player or not player.inventory then return end

  local items = {}
  for id, qty in pairs(player.inventory) do
    local def = Content.getItem(id) or Content.getTurret(id)
    if def and not def.unsellable then
      table.insert(items, {
        id = id,
        qty = qty,
        def = def,
        name = def.name or id,
        price = math.floor((def.price or 0) * 0.5) -- Sell for 50% of base price
      })
    end
  end

  table.sort(items, function(a, b) return a.name < b.name end)

  -- Grid layout
  local slotSize = 88
  local padding = 8
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
      if hover then
        currentHoveredItem = { x = dx, y = dy, w = slotSize, h = slotSize, item = item }
      end

      -- Slot background
      Theme.drawGradientGlowRect(dx, dy, slotSize, slotSize, 4,
        hover and Theme.colors.bg2 or Theme.colors.bg1,
        Theme.colors.bg0, Theme.colors.border, Theme.effects.glowWeak)

      -- Icon
      local icon = item.def.icon
      if icon and type(icon) == "userdata" then
        Theme.setColor({1,1,1,1})
        local scale = math.min((slotSize - 8) / icon:getWidth(), (slotSize - 8) / icon:getHeight())
        love.graphics.draw(icon, dx + 4, dy + 4, 0, scale, scale)
      else
        Theme.setColor(Theme.colors.text)
        love.graphics.printf(item.name, dx + 4, dy + slotSize/2 - 7, slotSize - 8, "center")
      end

      -- Name
      Theme.setColor(Theme.colors.text)
      love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
      love.graphics.printf(item.name, dx, dy + slotSize - 28, slotSize, "center")

      -- Quantity
      Theme.setColor(Theme.colors.accent)
      love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
      love.graphics.printf(Util.formatNumber(item.qty), dx + 4, dy + 2, slotSize - 4, "left")

      -- Inventory count
      local inventoryCount = (player.inventory and player.inventory[item.id]) or 0
      Theme.setColor(Theme.colors.textDisabled)
      love.graphics.printf("In Cargo: " .. Util.formatNumber(inventoryCount), dx, dy + slotSize - 14, slotSize, "center")

      -- Price
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
  else
    DockedUI.hoveredItem = nil
    DockedUI.hoverTimer = 0
  end

  love.graphics.setScissor()
  love.graphics.pop()
end

-- Draw shop items
function DockedUI.drawShopItems(x, y, w, h, player)
  if not player then return end
  
  -- Get all shop items
  local allShopItems = {}
  
  -- Add turrets
  for _, turret in ipairs(Content.turrets or {}) do
    if turret.price then
      table.insert(allShopItems, {
        type = "turret",
        data = turret,
        price = turret.price,
        name = turret.name,
        description = turret.description,
        id = turret.id,
        category = "Weapons"
      })
    end
  end
  
  -- Add regular items
  for _, item in ipairs(Content.items) do
    if item.price then
      table.insert(allShopItems, {
        type = "item",
        data = item,
        price = item.price,
        name = item.name,
        description = item.description,
        id = item.id,
        category = item.type == "consumable" and "Consumables" or "Materials"
      })
    end
  end
  
  -- Filter items
  local shopItems = {}
  for _, item in ipairs(allShopItems) do
    local matchesCategory = DockedUI.selectedCategory == "All" or item.category == DockedUI.selectedCategory
    local matchesSearch = DockedUI.searchText == "" or 
                         string.lower(item.name):find(string.lower(DockedUI.searchText), 1, true)
    
    if matchesCategory and matchesSearch then
      table.insert(shopItems, item)
    end
  end
  
  -- Sort by price
  table.sort(shopItems, function(a, b) return a.price < b.price end)
  
  -- Grid layout (match Inventory style)
  local slotSize = 88
  local slotW = slotSize
  local slotH = slotSize
  local padding = 8
  local cols = math.floor(w / (slotW + padding))
  if cols < 1 then cols = 1 end
  local startX = x + (w - cols * (slotW + padding) + padding) / 2
  local startY = y

  local mx, my = Viewport.getMousePosition()
  DockedUI._shopItems = {}
  local currentHoveredItem = nil

  -- Calculate scroll (in pixels)
  local itemFullH = slotH + padding
  local totalRows = math.ceil(#shopItems / cols)
  local contentHeight = math.max(0, totalRows * itemFullH - padding)
  local maxScroll = math.max(0, contentHeight - h)
  DockedUI.shopScroll = math.max(0, math.min(DockedUI.shopScroll or 0, maxScroll))

  love.graphics.push()
  love.graphics.setScissor(x, y, w, h)
  for i, item in ipairs(shopItems) do
    local index = i - 1
    local row = math.floor(index / cols)
    local col = index % cols
    local sx = startX + col * (slotW + padding)
    local sy = startY + row * (slotH + padding) - DockedUI.shopScroll
    -- Use integer drawing positions to avoid blur on GPU
    local dx = math.floor(sx + 0.5)
    local dy = math.floor(sy + 0.5)

    -- Only draw visible rows
    if sy + slotH >= startY and sy <= startY + h then
      local hover = mx >= sx and my >= sy and mx <= sx + slotW and my <= sy + slotH
      if hover then
        currentHoveredItem = { x = dx, y = dy, w = slotW, h = slotH, item = item }
      end
      local canAfford = player:getGC() >= item.price

      -- Slot background
      if hover then
        Theme.drawGradientGlowRect(dx, dy, slotW, slotH, 4,
          Theme.colors.bg2, Theme.colors.bg1, Theme.colors.border, Theme.effects.glowWeak)
      else
        Theme.drawGradientGlowRect(dx, dy, slotW, slotH, 4,
          Theme.colors.bg1, Theme.colors.bg0, Theme.colors.border, Theme.effects.glowWeak)
      end

      -- Icon (turret or item) - constrain to an iconArea leaving room for name/price
      local iconSize = 64
      local iconPad = (slotW - iconSize) / 2
      local tdef = Content.getTurret(item.id)
      if tdef then
        if tdef.icon and type(tdef.icon) == "userdata" then
          Theme.setColor({1,1,1,1})
          local scale = math.min(iconSize / tdef.icon:getWidth(), iconSize / tdef.icon:getHeight())
          love.graphics.draw(tdef.icon, dx + iconPad, dy + iconPad, 0, scale, scale)
        elseif UI and UI.drawTurretIcon then
          UI.drawTurretIcon(tdef.type or tdef.kind or "gun", (tdef.tracer and tdef.tracer.color), dx + iconPad, dy + iconPad, iconSize)
        end
      else
        local def = Content.getItem(item.id)
        local icon = nil
        if def and def.icon and type(def.icon) == "userdata" then icon = def.icon end
        if icon then
          Theme.setColor({1,1,1,1})
          local scale = math.min(iconSize / icon:getWidth(), iconSize / icon:getHeight())
          love.graphics.draw(icon, dx + iconPad, dy + iconPad, 0, scale, scale)
        else
          -- Fallback name
          Theme.setColor(Theme.colors.text)
          love.graphics.printf(item.name or item.id, dx + 4, dy + iconSize/2 - 7, slotW - 8, "center")
        end
      end

      -- Name
      Theme.setColor(Theme.colors.text)
      love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
      love.graphics.printf(item.name, dx, dy + slotH - 28, slotW, "center")

      -- Quantity
      Theme.setColor(Theme.colors.accent)
      love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
      love.graphics.printf("∞", dx + 4, dy + 2, slotW - 4, "left")

      -- Inventory count
      local inventoryCount = (player.inventory and player.inventory[item.id]) or 0
      Theme.setColor(Theme.colors.textDisabled)
      love.graphics.printf("In Cargo: " .. Util.formatNumber(inventoryCount), dx, dy + slotH - 14, slotW, "center")

      -- Price
      Theme.setColor(Theme.colors.accentGold)
      love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
      local priceText = Util.formatNumber(item.price)
      local priceWidth = love.graphics.getFont():getWidth(priceText)
      love.graphics.print(priceText, dx + slotW - priceWidth - 12, dy + 2)
      Theme.drawCurrencyToken(dx + slotW - 10, dy + 2, 8)

      table.insert(DockedUI._shopItems, { x = dx, y = dy, w = slotW, h = slotH, item = item, canAfford = canAfford })
    end
  end
  if currentHoveredItem then
    if DockedUI.hoveredItem and DockedUI.hoveredItem.item.id == currentHoveredItem.item.id then
      DockedUI.hoverTimer = DockedUI.hoverTimer + love.timer.getDelta()
    else
      DockedUI.hoveredItem = currentHoveredItem
      DockedUI.hoverTimer = 0
    end
  else
    DockedUI.hoveredItem = nil
    DockedUI.hoverTimer = 0
  end
  love.graphics.setScissor()
  love.graphics.pop()

  -- Draw vertical scrollbar
  if contentHeight > h then
    local scrollBarW = 8
    local scrollBarX = x + w - scrollBarW - 6
    local scrollBarY = y + 4
    local scrollBarH = h - 8

    Theme.setColor(Theme.withAlpha(Theme.colors.bg3, 0.6))
    love.graphics.rectangle("fill", scrollBarX, scrollBarY, scrollBarW, scrollBarH)

    local thumbH = math.max(20, (h / contentHeight) * scrollBarH)
    local tPct = (DockedUI.shopScroll / (maxScroll > 0 and maxScroll or 1))
    local thumbY = scrollBarY + tPct * (scrollBarH - thumbH)

    Theme.setColor(Theme.colors.accent)
    love.graphics.rectangle("fill", scrollBarX, thumbY, scrollBarW, thumbH)

    DockedUI._shopScrollBar = { x = scrollBarX, y = scrollBarY, w = scrollBarW, h = scrollBarH, thumbY = thumbY, thumbH = thumbH }
    DockedUI._shopMaxScroll = maxScroll
  else
    DockedUI._shopScrollBar = nil
  end
end

-- Purchase an item
function DockedUI.purchaseItem(item, player)
  if not player or not item then return end

  if player:getGC() < item.price then return false end

  player:spendGC(item.price)

  -- Check if this is a turret and apply procedural generation
  local itemId = item.id
  local itemName = item.name
  local ProceduralGen = require("src.core.procedural_gen")
  local Content = require("src.content.content")

  if Content.getTurret(itemId) then
    -- This is a turret, generate procedural stats
    local baseTurret = Content.getTurret(itemId)
    local proceduralTurret = ProceduralGen.generateTurretStats(baseTurret, 1)

    -- Store the procedural turret in player's inventory with a unique ID
    local uniqueId = itemId .. "_" .. tostring(love.timer.getTime()) .. "_" .. tostring(math.random(10000))
    proceduralTurret.id = uniqueId
    proceduralTurret.baseId = itemId -- Keep track of the base turret type

    -- Add to player's inventory as the full turret data
    if not player.inventory then player.inventory = {} end
    player.inventory[uniqueId] = proceduralTurret

    itemName = proceduralTurret.proceduralName or proceduralTurret.name
  else
    -- Regular item, add normally
    local Cargo = require("src.core.cargo")
    Cargo.add(player, itemId, 1, { notify = false })
  end

  Notifications.action("Purchased " .. itemName)
  return true
end

-- Sell an item
function DockedUI.sellItem(item, player)
  if not player or not item then return end
  
  if not player.inventory or not player.inventory[item.id] or player.inventory[item.id] <= 0 then
    return false
  end
  
  player.inventory[item.id] = player.inventory[item.id] - 1
  if player.inventory[item.id] == 0 then
    player.inventory[item.id] = nil
  end
  
  player:addGC(item.price)
  Notifications.action("Sold " .. item.name)
  
  table.insert(DockedUI.buybackItems, 1, {
    id = item.id,
    price = item.price,
    def = item.def,
    name = item.name,
  })
  -- Limit buyback list to 10 items
  if #DockedUI.buybackItems > 10 then
    table.remove(DockedUI.buybackItems)
  end
  
  return true
end

-- Handle mouse press
function DockedUI.mousepressed(x, y, button)
  if not DockedUI.visible then return false end

  -- Handle context menu first (always priority)
  if DockedUI.contextMenu and DockedUI.contextMenu.visible then
    local menu = DockedUI.contextMenu
    local mx, my = x, y
    local w_, h_ = 200, 160 -- Correct dimensions to match draw function
    local bx, by = menu.x + (w_ - 100) / 2, menu.y + 116 -- Correct button position to match draw function
    if mx >= menu.x and mx <= menu.x + w_ and my >= menu.y and my <= menu.y + h_ then
      -- Inside menu
      if button == 1 then
        -- Check +/- buttons
        local inputW, inputH = 100, 28
        local inputX, inputY = menu.x + (w_ - inputW) / 2, menu.y + 36
        local btnSize = 28
        if mx >= inputX - btnSize - 4 and mx <= inputX - btnSize - 4 + btnSize and my >= inputY and my <= inputY + btnSize then
          -- Minus button
          local qty = tonumber(menu.quantity) or 1
          if qty > 1 then
            menu.quantity = tostring(qty - 1)
          end
        elseif mx >= inputX + inputW + 4 and mx <= inputX + inputW + 4 + btnSize and my >= inputY and my <= inputY + btnSize then
          -- Plus button
          local qty = tonumber(menu.quantity)
          menu.quantity = tostring(qty + 1)
        else
          -- Check action button (BUY/SELL)
          if mx >= bx and mx <= bx + 120 and my >= by and my <= by + 32 then
            local qty = tonumber(menu.quantity) or 0
            if qty > 0 and DockedUI.player then
              if menu.type == "buy" then
                local cost = (menu.item.price or 0) * qty
                if DockedUI.player:getGC() >= cost then
                  for i = 1, qty do
                    DockedUI.purchaseItem(menu.item, DockedUI.player)
                  end
                end
              elseif menu.type == "sell" then
                -- Check if player has enough items to sell
                if DockedUI.player.inventory and DockedUI.player.inventory[menu.item.id] and
                   DockedUI.player.inventory[menu.item.id] >= qty then
                  for i = 1, qty do
                    DockedUI.sellItem(menu.item, DockedUI.player)
                  end
                end
              end
            end
            DockedUI.contextMenu.visible = false
          end
        end
      end
      return true, false
    else
      DockedUI.contextMenu.visible = false
      return true, false
    end
  end

  if button == 1 then
    -- Common UI elements that are always visible
    -- Close button
    if DockedUI._closeButton then
      local btn = DockedUI._closeButton
      local closeButton = {_rect = {x = btn.x, y = btn.y, w = btn.w, h = btn.h}}
      if Theme.handleButtonClick(closeButton, x, y, function()
        -- Close action will be handled by the return value
      end) then
        return true, true -- consumed, should close
      end
    end

    -- Title bar dragging disabled for fullscreen UI

    -- Main tabs (always available)
    if DockedUI._mainTabs then
      for _, tab in ipairs(DockedUI._mainTabs) do
        if x >= tab.x and x <= tab.x + tab.w and y >= tab.y and y <= tab.y + tab.h then
          DockedUI.activeTab = tab.name
          -- Reset tab-specific states when switching
          if tab.name ~= "Shop" then
            DockedUI.categoryDropdownOpen = false
            DockedUI.activeShopTab = "Buy"
          end
          return true, false
        end
      end
    end

    -- Delegate to the active tab's UI handler
    if DockedUI.activeTab == "Shop" then
      -- Shop-specific UI elements

      -- Shop Buy/Sell tabs
      if DockedUI._shopTabs then
        for _, tab in ipairs(DockedUI._shopTabs) do
          if x >= tab.x and x <= tab.x + tab.w and y >= tab.y and y <= tab.y + tab.h then
            DockedUI.activeShopTab = tab.name
            DockedUI.categoryDropdownOpen = false -- Close dropdown when changing main tabs
            return true, false
          end
        end
      end

      -- Category dropdown
      if DockedUI.activeShopTab == "Buy" and DockedUI._categoryDropdown then
        local dd = DockedUI._categoryDropdown
        if x >= dd.x and x <= dd.x + dd.w and y >= dd.y and y <= dd.y + dd.h then
          DockedUI.categoryDropdownOpen = not DockedUI.categoryDropdownOpen
          return true, false
        end
        if DockedUI.categoryDropdownOpen then
          local categories = {"All", "Weapons", "Consumables", "Materials"}
          for i, category in ipairs(categories) do
            local optY = dd.y + dd.h + (i-1) * 24
            if x >= dd.x and x <= dd.x + dd.w and y >= optY and y <= optY + 24 then
              DockedUI.selectedCategory = category
              DockedUI.categoryDropdownOpen = false
              DockedUI.shopScroll = 0
              return true, false
            end
          end
        end
      end

      -- Scrollbar drag start
      if DockedUI._shopScrollBar then
        local sb = DockedUI._shopScrollBar
        if x >= sb.x and x <= sb.x + sb.w and y >= sb.y and y <= sb.y + sb.h then
          -- clicked anywhere on the scrollbar track -> start dragging
          DockedUI._draggingScroll = true
          DockedUI._dragScrollOffsetY = y - sb.thumbY
          return true, false
        end
      end

      -- Shop items (Buy tab): left-click opens buy popup
      if DockedUI.activeShopTab == "Buy" and DockedUI._shopItems then
        for _, shopItem in ipairs(DockedUI._shopItems) do
          if x >= shopItem.x and x <= shopItem.x + shopItem.w and
             y >= shopItem.y and y <= shopItem.y + shopItem.h and
             shopItem.canAfford then
            DockedUI.contextMenu = { visible = true, x = x, y = y, item = shopItem.item, quantity = "1", type = "buy" }
            return true, false
          end
        end
      end

      -- Sell items (Sell tab): left-click opens sell popup
      if DockedUI.activeShopTab == "Sell" and DockedUI._sellItems then
        for _, sellItem in ipairs(DockedUI._sellItems) do
          if x >= sellItem.x and x <= sellItem.x + sellItem.w and
             y >= sellItem.y and y <= sellItem.y + sellItem.h then
            DockedUI.contextMenu = { visible = true, x = x, y = y, item = sellItem.item, quantity = "1", type = "sell" }
            return true, false
          end
        end
      end

      -- Buyback items (Buyback tab): click to buy back
      if DockedUI.activeShopTab == "Buyback" and DockedUI._buybackButtons then
        for _, btn in ipairs(DockedUI._buybackButtons) do
          if x >= btn.x and x <= btn.x + btn.w and
             y >= btn.y and y <= btn.y + btn.h then
            -- Use the stored docked player reference
            if DockedUI.player and DockedUI.player:getGC() >= btn.item.price then
              DockedUI.player:spendGC(btn.item.price)
              local Cargo = require("src.core.cargo")
              Cargo.add(DockedUI.player, btn.item.id, 1, { notify = false })
              table.remove(DockedUI.buybackItems, btn.index)
              return true, false
            end
          end
        end
      end

      -- Search bar click
      if DockedUI.activeShopTab == "Buy" and DockedUI._searchBar then
        local sb = DockedUI._searchBar
        if x >= sb.x and x <= sb.x + sb.w and y >= sb.y and y <= sb.y + sb.h then
          DockedUI.searchActive = true
          return true, false
        else
          DockedUI.searchActive = false
        end
      else
        DockedUI.searchActive = false
      end

    elseif DockedUI.activeTab == "Ship" and DockedUI.equipment then
      -- Delegate to equipment UI
      local consumed = DockedUI.equipment:mousepressed(DockedUI.player, x, y, button)
      if consumed then return consumed end

    elseif DockedUI.activeTab == "Quests" and DockedUI.quests then
      -- Delegate to quests UI
      local consumed = DockedUI.quests:mousepressed(DockedUI.player, x, y, button)
      if consumed then return consumed end

    elseif DockedUI.activeTab == "Nodes" and DockedUI.nodes then
      -- Delegate to nodes UI
      local consumed = DockedUI.nodes:mousepressed(DockedUI.player, x, y, button)
      if consumed then return consumed end
    end

  elseif button == 2 then
    -- Right-click handling (only for shop when active)
    if DockedUI.activeTab == "Shop" then
      -- Right-click: Alternative way to open popups (keeping for backwards compatibility)
      if DockedUI.activeShopTab == "Buy" and DockedUI._shopItems then
        for _, shopItem in ipairs(DockedUI._shopItems) do
          if x >= shopItem.x and x <= shopItem.x + shopItem.w and
             y >= shopItem.y and y <= shopItem.y + shopItem.h then
            DockedUI.contextMenu = { visible = true, x = x, y = y, item = shopItem.item, quantity = "1", type = "buy" }
            return true, false
          end
        end
      elseif DockedUI.activeShopTab == "Sell" and DockedUI._sellItems then
        for _, sellItem in ipairs(DockedUI._sellItems) do
          if x >= sellItem.x and x <= sellItem.x + sellItem.w and
             y >= sellItem.y and y <= sellItem.y + sellItem.h then
            DockedUI.contextMenu = { visible = true, x = x, y = y, item = sellItem.item, quantity = "1", type = "sell" }
            return true, false
          end
        end
      end
    end
  end

  -- If click was within the window but not on an interactive element, don't consume it
  if x >= DockedUI.windowX and x <= DockedUI.windowX + DockedUI.windowW and y >= DockedUI.windowY and y <= DockedUI.windowY + DockedUI.windowH then
    return false, false
  end

  return false, false -- not consumed, don't close
end

-- Handle mouse release
function DockedUI.mousereleased(x, y, button)
  if not DockedUI.visible then return false end

  -- Window dragging disabled for fullscreen UI

  if button == 1 and DockedUI._draggingScroll then
    DockedUI._draggingScroll = nil
    DockedUI._dragScrollOffsetY = nil
    return true
  end

  -- Delegate to the active tab's UI handler
  if DockedUI.activeTab == "Shop" then
    -- No specific mouse release handling for shop
  elseif DockedUI.activeTab == "Ship" and DockedUI.equipment then
    return DockedUI.equipment:mousereleased(DockedUI.player, x, y, button)
  elseif DockedUI.activeTab == "Quests" and DockedUI.quests then
    return DockedUI.quests:mousereleased(DockedUI.player, x, y, button)
  elseif DockedUI.activeTab == "Nodes" and DockedUI.nodes then
    return DockedUI.nodes:mousereleased(DockedUI.player, x, y, button)
  end

  return false
end

-- Handle mouse movement
function DockedUI.mousemoved(x, y, dx, dy)
  if not DockedUI.visible then return false end
  
  -- Window dragging disabled for fullscreen UI

  if DockedUI._draggingScroll and DockedUI._shopScrollBar and DockedUI._shopMaxScroll then
    local sb = DockedUI._shopScrollBar
    local thumbH = sb.thumbH or 20
    local localY = y - sb.y - DockedUI._dragScrollOffsetY
    local pct = math.max(0, math.min(1, localY / (sb.h - thumbH)))
    DockedUI.shopScroll = pct * DockedUI._shopMaxScroll
    return true
  end
  
  if DockedUI.activeTab == "Ship" and DockedUI.equipment then
    return DockedUI.equipment:mousemoved(DockedUI.player, x, y, dx, dy)
  elseif DockedUI.activeTab == "Quests" and DockedUI.quests then
    return DockedUI.quests:mousemoved(DockedUI.player, x, y, dx, dy)
  elseif DockedUI.activeTab == "Nodes" and DockedUI.nodes then
    return DockedUI.nodes:mousemoved(DockedUI.player, x, y, dx, dy)
  end

  return false
end

-- Handle mouse wheel
function DockedUI.wheelmoved(dx, dy)
  if not DockedUI.visible then return false end
  -- Nodes tab: forward to nodes panel for chart zoom
  if DockedUI.activeTab == "Nodes" and DockedUI.nodes and DockedUI.nodes.wheelmoved then
    return DockedUI.nodes:wheelmoved(DockedUI.player, dx, dy)
  end
  -- Shop tab: scroll list
  if DockedUI.activeTab == "Shop" then
    local delta = -dy * 24 -- scroll speed in pixels per wheel tick
    DockedUI.shopScroll = math.max(0, math.min(DockedUI.shopScroll + delta, DockedUI._shopMaxScroll or 0))
    return true
  end
  return false
end

-- Handle key press
function DockedUI.keypressed(key)
  if not DockedUI.visible then return false end

  if DockedUI.searchActive then
    if key == "backspace" then
      DockedUI.searchText = DockedUI.searchText:sub(1, -2)
      return true
    elseif key == "return" or key == "kpenter" then
      DockedUI.searchActive = false
      return true
    end
  end

  if DockedUI.contextMenu.visible then
    local menu = DockedUI.contextMenu
    if key == "backspace" then
      menu.quantity = menu.quantity:sub(1, -2)
      if menu.quantity == "" then menu.quantity = "0" end
      return true
    elseif key == "return" or key == "kpenter" then
          local qty = tonumber(menu.quantity) or 0
          if qty > 0 and DockedUI.player then
            if menu.type == "buy" then
              local cost = (menu.item.price or 0) * qty
              if DockedUI.player:getGC() >= cost then
                for i = 1, qty do
                  DockedUI.purchaseItem(menu.item, DockedUI.player)
                end
              end
            elseif menu.type == "sell" then
          if DockedUI.player.inventory and DockedUI.player.inventory[menu.item.id] and
             DockedUI.player.inventory[menu.item.id] >= qty then
            for i = 1, qty do
              DockedUI.sellItem(menu.item, DockedUI.player)
            end
          end
        end
      end
      DockedUI.contextMenu.visible = false
      return true
    elseif key == "escape" then
      DockedUI.contextMenu.visible = false
      return true
    end
  end

  -- Handle escape key to undock
  if key == "escape" then
    return true, true -- consumed, should close (undock)
  end

  -- Forward to Nodes panel if active
  if DockedUI.activeTab == "Nodes" and DockedUI.nodes and DockedUI.nodes.keypressed then
    return DockedUI.nodes:keypressed(key)
  end

  return true, false
end

function DockedUI.textinput(text)
  if not DockedUI.visible then return false end

  if DockedUI.searchActive then
    DockedUI.searchText = DockedUI.searchText .. text
    return true
  end

  if DockedUI.contextMenu.visible then
    if text:match("%d") then
      local menu = DockedUI.contextMenu
      if menu.quantity == "0" then menu.quantity = "" end
      menu.quantity = menu.quantity .. text
      return true
    end
  end

  -- Forward to Nodes panel if active
  if DockedUI.activeTab == "Nodes" and DockedUI.nodes and DockedUI.nodes.textinput then
    return DockedUI.nodes:textinput(text)
  end

  return false
end

function DockedUI.update(dt)
  if not DockedUI.visible then return end

  if DockedUI.activeTab == "Ship" and DockedUI.equipment then
    DockedUI.equipment:update(dt)
  elseif DockedUI.activeTab == "Quests" and DockedUI.quests then
    DockedUI.quests:update(dt)
  elseif DockedUI.activeTab == "Nodes" and DockedUI.nodes then
    DockedUI.nodes:update(dt)
  end
end

return DockedUI
