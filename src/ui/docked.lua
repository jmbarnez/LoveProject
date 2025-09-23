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
local IconSystem = require("src.core.icon_system")
local Window = require("src.ui.common.window")
local UITabs = require("src.ui.common.tabs")
local Shop = require("src.ui.docked.shop")
local Dropdown = require("src.ui.common.dropdown")

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
DockedUI.contextMenuActive = false -- For text input focus
DockedUI._bountyRef = nil

-- New Tabbed Interface State
DockedUI.tabs = {"Shop", "Ship", "Quests", "Nodes"}
DockedUI.activeTab = "Shop"

-- Window properties (fullscreen)
-- Initialize the docked window
function DockedUI.init()
    local sw, sh = Viewport.getDimensions()
    DockedUI.window = Window.new({
        title = "Station Services",
        x = 0,
        y = 0,
        width = sw,
        height = sh,
        useLoadPanelTheme = true,
        closable = true,
        draggable = true,
        resizable = false,
        drawContent = DockedUI.drawContent,
        onClose = function()
            if DockedUI.player then
                DockedUI.player:undock()
            end
        end
    })
    DockedUI.equipment = Ship:new()
    DockedUI.quests = Quests:new()
    DockedUI.nodes = Nodes:new()

    -- Initialize category dropdown
    DockedUI.categoryDropdown = Dropdown.new({
        x = 0,
        y = 0,
        width = 150,
        optionHeight = 24,
        options = {"All", "Weapons", "Consumables", "Materials"},
        selectedIndex = 1,
        onSelect = function(index, option)
            DockedUI.selectedCategory = option
        end
    })
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
    if not DockedUI.window then DockedUI.init() end
    DockedUI.window.visible = DockedUI.visible
    DockedUI.window:draw()
end

function DockedUI.drawContent(window, x, y, w, h)
    local player = DockedUI.player
    local mx, my = Viewport.getMousePosition()

    -- Main tabs
    local pad = (Theme.ui and Theme.ui.contentPadding) or 12
    local mainTabY = y + ((Theme.ui and Theme.ui.contentPadding) or 8)
    local mainTabH = (Theme.ui and Theme.ui.buttonHeight) or 28
    DockedUI.drawMainTabs(x + pad, mainTabY, w - pad * 2, mainTabH)

    -- Content area
    local contentY = mainTabY + mainTabH + ((Theme.ui and Theme.ui.buttonSpacing) or 8)
    local contentH = h - (contentY - y) - pad

    if DockedUI.activeTab == "Shop" then
        -- Category tabs
        local tabY = contentY
        local tabH = (Theme.ui and Theme.ui.buttonHeight) or 28
        DockedUI.drawCategoryTabs(x + pad, tabY, w - pad * 2, tabH, mx, my)
        
        -- Shop content area
        local shopContentY = tabY + tabH + ((Theme.ui and Theme.ui.buttonSpacing) or 8)
        local shopContentH = h - (shopContentY - y) - pad
        if DockedUI.activeShopTab == "Buy" then
            DockedUI.drawShopItems(x + pad, shopContentY, w - pad * 2, shopContentH, player)
        elseif DockedUI.activeShopTab == "Sell" then
            DockedUI.drawPlayerInventoryForSale(x + pad, shopContentY, w - pad * 2, shopContentH, player)
        elseif DockedUI.activeShopTab == "Buyback" then
            DockedUI.drawBuybackItems(x + pad, shopContentY, w - pad * 2, shopContentH, player)
        end
    elseif DockedUI.activeTab == "Ship" then
        DockedUI.equipment:draw(player, x + pad, contentY, w - pad * 2, contentH)
    elseif DockedUI.activeTab == "Quests" then
        DockedUI.quests:draw(player, x + pad, contentY, w - pad * 2, contentH)
    elseif DockedUI.activeTab == "Nodes" then
        DockedUI.nodes:draw(player, x + pad, contentY, w - pad * 2, contentH)
    end

    -- Category dropdown is handled by the standardized component
    
    -- Draw context menu for numeric purchase/sale
    if DockedUI.contextMenu.visible then
        local menu = DockedUI.contextMenu
        local x_, y_, w_, h_ = menu.x, menu.y, 180, 110
        Theme.drawGradientGlowRect(x_, y_, w_, h_, 4, Theme.colors.bg2, Theme.colors.bg1, Theme.colors.border, Theme.effects.glowWeak)

        -- Item name
        Theme.setColor(Theme.colors.textHighlight)
        love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
        love.graphics.printf(menu.item.name, x_, y_ + 6, w_, "center")

        -- Quantity input field
        local inputW, inputH = 100, 28
        local inputX, inputY = x_ + (w_ - inputW) / 2, y_ + 28
        local inputHover = mx >= inputX and mx <= inputX + inputW and my >= inputY and my <= inputY + inputH
        local inputColor = inputHover and Theme.colors.bg2 or Theme.colors.bg1
        Theme.drawGradientGlowRect(inputX, inputY, inputW, inputH, 3, inputColor, Theme.colors.bg0, Theme.colors.accent, Theme.effects.glowWeak)

        -- Input text
        Theme.setColor(Theme.colors.text)
        local textWidth = love.graphics.getFont():getWidth(menu.quantity)
        local textX = inputX + (inputW - textWidth) / 2
        love.graphics.print(menu.quantity, textX, inputY + 6)

        -- Blinking cursor
        if math.floor(love.timer.getTime() * 2) % 2 == 0 then
            love.graphics.rectangle("fill", textX + textWidth + 2, inputY + 4, 2, inputH - 8)
        end
        menu._inputRect = { x = inputX, y = inputY, w = inputW, h = inputH }

        -- Total price
        local qty = tonumber(menu.quantity) or 0
        local totalPrice = (menu.item.price or 0) * qty
        Theme.setColor(Theme.colors.accentGold)
        love.graphics.printf("Total: " .. Util.formatNumber(totalPrice), x_, y_ + 64, w_, "center")

        -- Action button
        local btnW, btnH = 100, 28
        local btnX, btnY = x_ + (w_ - btnW) / 2, y_ + 78
        local btnHover = mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH
        local actionText = menu.type == "buy" and "BUY" or "SELL"
        local canAfford = true
        if menu.type == "buy" then
            canAfford = DockedUI.player and DockedUI.player:getGC() >= totalPrice
        else
            canAfford = DockedUI.player and DockedUI.player.inventory and DockedUI.player.inventory[menu.item.id] and DockedUI.player.inventory[menu.item.id] >= qty
        end
        local btnColor = canAfford and (btnHover and Theme.colors.success or Theme.colors.bg3) or Theme.colors.bg1
        Theme.drawGradientGlowRect(btnX, btnY, btnW, btnH, 3, btnColor, Theme.colors.bg1, Theme.colors.border, Theme.effects.glowWeak)
        Theme.setColor(canAfford and Theme.colors.textHighlight or Theme.colors.textSecondary)
        love.graphics.printf(actionText, btnX, btnY + 6, btnW, "center")
        menu._buttonRect = { x = btnX, y = btnY, w = btnW, h = btnH }
    end
end

function DockedUI.drawMainTabs(x, y, w, h)
  local res = UITabs.draw(x, y, w, h, DockedUI.tabs, DockedUI.activeTab)
  DockedUI._mainTabs = res.rects
end

-- Draw main Buy/Sell/Buyback tabs and category tabs
function DockedUI.drawCategoryTabs(x, y, w, h, mx, my)
  local shopTabs = {"Buy", "Sell", "Buyback"}
  local res = UITabs.draw(x, y, math.min(w, 3 * 84 + 8), h, shopTabs, DockedUI.activeShopTab)
  DockedUI._shopTabs = res.rects

  -- Category dropdown and search bar (only for Buy tab)
  local searchWidth = 150
  if DockedUI.activeShopTab == "Buy" then
    local last = res.rects[#res.rects]
    local filterX = (last and (last.x + last.w + 16)) or (x + 16)

    -- Set up and draw the category dropdown
    DockedUI.categoryDropdown:setPosition(filterX, y)
    DockedUI.categoryDropdown:drawButtonOnly(mx, my)
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
  return Shop.drawBuybackItems(DockedUI, x, y, w, h, player)
end

-- Draw player inventory for selling
function DockedUI.drawPlayerInventoryForSale(x, y, w, h, player)
  return Shop.drawPlayerInventoryForSale(DockedUI, x, y, w, h, player)
end

-- Draw shop items
function DockedUI.drawShopItems(x, y, w, h, player)
  return Shop.drawShopItems(DockedUI, x, y, w, h, player)
end

-- Purchase an item (can handle bulk purchases)
function DockedUI.purchaseItem(item, player, quantity)
  quantity = quantity or 1
  if not player or not item or quantity <= 0 then return false end

  local totalCost = item.price * quantity
  if player:getGC() < totalCost then return false end

  player:spendGC(totalCost)

  -- Check if this is a turret and apply procedural generation
  local itemId = item.id
  local itemName = item.name
  local ProceduralGen = require("src.core.procedural_gen")
  local Content = require("src.content.content")

  if Content.getTurret(itemId) then
    -- This is a turret, generate procedural stats for each one
    local baseTurret = Content.getTurret(itemId)
    local purchasedItems = {}

    for i = 1, quantity do
      local proceduralTurret = ProceduralGen.generateTurretStats(baseTurret, 1)

      -- Store the procedural turret in player's inventory with a unique ID
      local uniqueId = itemId .. "_" .. tostring(love.timer.getTime()) .. "_" .. tostring(math.random(10000)) .. "_" .. tostring(i)
      proceduralTurret.id = uniqueId
      proceduralTurret.baseId = itemId -- Keep track of the base turret type

      -- Add to player's inventory as the full turret data
      if not player.inventory then player.inventory = {} end
      player.inventory[uniqueId] = proceduralTurret

      purchasedItems[i] = proceduralTurret.proceduralName or proceduralTurret.name

      -- Refresh inventory display
      local Inventory = require("src.ui.inventory")
      if Inventory.refresh then Inventory.refresh() end
    end

    itemName = purchasedItems[1] -- Use the first item's name for the notification
  else
    -- Regular item, add normally
    local Cargo = require("src.core.cargo")
    Cargo.add(player, itemId, quantity, { notify = false })
  end

  -- Create single notification with quantity
  local notificationText = quantity > 1 and ("Purchased " .. itemName .. " x" .. quantity) or ("Purchased " .. itemName)
  Notifications.action(notificationText)
  return true
end

-- Sell an item (can handle bulk sales)
function DockedUI.sellItem(item, player, quantity)
  quantity = quantity or 1
  if not player or not item or quantity <= 0 then return false end

  if not player.inventory or not player.inventory[item.id] then
    return false
  end

  local currentValue = player.inventory[item.id]
  local currentAmount = (type(currentValue) == "number") and currentValue or 0
  if currentAmount < quantity then
    return false
  end

  local newAmount = currentAmount - quantity
  if newAmount <= 0 then
    player.inventory[item.id] = nil
  else
    player.inventory[item.id] = newAmount
  end

  player:addGC(item.price * quantity)

  -- Create single notification with quantity
  local notificationText = quantity > 1 and ("Sold " .. item.name .. " x" .. quantity) or ("Sold " .. item.name)
  Notifications.action(notificationText)

  -- Add items to buyback list (only add one entry regardless of quantity)
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
    if not DockedUI.visible then return false, false end
    if not DockedUI.window then return false, false end

    if DockedUI.window:mousepressed(x, y, button) then
        return true, false
    end

    -- Handle context menu first
    if DockedUI.contextMenu and DockedUI.contextMenu.visible then
        local menu = DockedUI.contextMenu
        local w_, h_ = 180, 110
        if x >= menu.x and x <= menu.x + w_ and y >= menu.y and y <= menu.y + h_ then
            if button == 1 then
                if menu._inputRect and x >= menu._inputRect.x and x <= menu._inputRect.x + menu._inputRect.w and y >= menu._inputRect.y and y <= menu._inputRect.y + menu._inputRect.h then
                    DockedUI.contextMenuActive = true
                    return true, false
                end
                if menu._buttonRect and x >= menu._buttonRect.x and x <= menu._buttonRect.x + menu._buttonRect.w and y >= menu._buttonRect.y and y <= menu._buttonRect.y + menu._buttonRect.h then
                    local qty = tonumber(menu.quantity) or 0
                    if qty > 0 and DockedUI.player then
                        if menu.type == "buy" then
                            DockedUI.purchaseItem(menu.item, DockedUI.player, qty)
                        elseif menu.type == "sell" then
                            DockedUI.sellItem(menu.item, DockedUI.player, qty)
                        end
                    end
                    DockedUI.contextMenu.visible = false
                    DockedUI.contextMenuActive = false
                    return true, false
                end
            end
            return true, false
        else
            DockedUI.contextMenu.visible = false
            return true, false
        end
    end

    -- Main tabs
    if DockedUI._mainTabs then
        for _, tab in ipairs(DockedUI._mainTabs) do
            if x >= tab.x and x <= tab.x + tab.w and y >= tab.y and y <= tab.y + tab.h then
                DockedUI.activeTab = tab.name
                return true, false
            end
        end
    end

    -- Delegate to active tab
    if DockedUI.activeTab == "Shop" then
        if DockedUI._shopTabs then
            for _, tab in ipairs(DockedUI._shopTabs) do
                if x >= tab.x and x <= tab.x + tab.w and y >= tab.y and y <= tab.y + tab.h then
                    DockedUI.activeShopTab = tab.name
                    return true, false
                end
            end
        end
        if button == 1 then
            -- Handle category dropdown clicks
            if DockedUI.activeShopTab == "Buy" then
                if DockedUI.categoryDropdown:mousepressed(x, y, button) then
                    return true, false
                end
            end
    
            if DockedUI.activeShopTab == "Buy" and DockedUI._shopItems then
                for _, itemUI in ipairs(DockedUI._shopItems) do
                    if x >= itemUI.x and x <= itemUI.x + itemUI.w and y >= itemUI.y and y <= itemUI.y + itemUI.h then
                        DockedUI.contextMenu = {
                            visible = true,
                            x = x,
                            y = y,
                            item = itemUI.item,
                            quantity = "1",
                            type = "buy"
                        }
                        DockedUI.contextMenuActive = false
                        return true, false
                    end
                end
            end
            if DockedUI.activeShopTab == "Sell" and DockedUI._sellItems then
                for _, itemUI in ipairs(DockedUI._sellItems) do
                    if x >= itemUI.x and x <= itemUI.x + itemUI.w and y >= itemUI.y and y <= itemUI.y + itemUI.h then
                        DockedUI.contextMenu = {
                            visible = true,
                            x = x,
                            y = y,
                            item = itemUI.item,
                            quantity = "1",
                            type = "sell"
                        }
                        DockedUI.contextMenuActive = false
                        return true, false
                    end
                end
            end
        end
    elseif DockedUI.activeTab == "Ship" and DockedUI.equipment then
        return DockedUI.equipment:mousepressed(DockedUI.player, x, y, button)
    elseif DockedUI.activeTab == "Quests" and DockedUI.quests then
        return DockedUI.quests:mousepressed(DockedUI.player, x, y, button)
    elseif DockedUI.activeTab == "Nodes" and DockedUI.nodes then
        return DockedUI.nodes:mousepressed(DockedUI.player, x, y, button)
    end

    return false, false
end

-- Handle mouse release
function DockedUI.mousereleased(x, y, button)
    if not DockedUI.visible then return false, false end
    if not DockedUI.window then return false, false end

    if DockedUI.window:mousereleased(x, y, button) then
        return true, false
    end

    if button == 1 and DockedUI._draggingScroll then
        DockedUI._draggingScroll = nil
        DockedUI._dragScrollOffsetY = nil
        return true, false
    end

    -- Delegate to active tab
    if DockedUI.activeTab == "Ship" and DockedUI.equipment then
        return DockedUI.equipment:mousereleased(DockedUI.player, x, y, button)
    elseif DockedUI.activeTab == "Quests" and DockedUI.quests then
        return DockedUI.quests:mousereleased(DockedUI.player, x, y, button)
    elseif DockedUI.activeTab == "Nodes" and DockedUI.nodes then
        return DockedUI.nodes:mousereleased(DockedUI.player, x, y, button)
    end

    return false, false
end

-- Handle mouse movement
function DockedUI.mousemoved(x, y, dx, dy)
    if not DockedUI.visible then return false, false end
    if not DockedUI.window then return false, false end

    if DockedUI.window:mousemoved(x, y, dx, dy) then
        return true, false
    end

    if DockedUI._draggingScroll and DockedUI._shopScrollBar and DockedUI._shopMaxScroll then
        local sb = DockedUI._shopScrollBar
        local thumbH = sb.thumbH or 20
        local localY = y - sb.y - DockedUI._dragScrollOffsetY
        local pct = math.max(0, math.min(1, localY / (sb.h - thumbH)))
        DockedUI.shopScroll = pct * DockedUI._shopMaxScroll
        return true, false
    end

    -- Delegate to active tab
    if DockedUI.activeTab == "Ship" and DockedUI.equipment then
        return DockedUI.equipment:mousemoved(DockedUI.player, x, y, dx, dy)
    elseif DockedUI.activeTab == "Quests" and DockedUI.quests then
        return DockedUI.quests:mousemoved(DockedUI.player, x, y, dx, dy)
    elseif DockedUI.activeTab == "Nodes" and DockedUI.nodes then
        return DockedUI.nodes:mousemoved(DockedUI.player, x, y, dx, dy)
    end

    return false, false
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
    if DockedUI.contextMenuActive then
      -- Text input mode
      if key == "backspace" then
        menu.quantity = menu.quantity:sub(1, -2)
        if menu.quantity == "" then menu.quantity = "1" end
        return true
      elseif key == "return" or key == "kpenter" then
        local qty = tonumber(menu.quantity) or 0
        if qty > 0 and DockedUI.player then
          if menu.type == "buy" then
            local cost = (menu.item.price or 0) * qty
            if DockedUI.player:getGC() >= cost then
              DockedUI.purchaseItem(menu.item, DockedUI.player, qty)
            end
          elseif menu.type == "sell" then
            if DockedUI.player.inventory and DockedUI.player.inventory[menu.item.id] and
               DockedUI.player.inventory[menu.item.id] >= qty then
            DockedUI.sellItem(menu.item, DockedUI.player, qty)
            end
          end
        end
        DockedUI.contextMenu.visible = false
        DockedUI.contextMenuActive = false
        return true
      elseif key == "escape" then
        DockedUI.contextMenu.visible = false
        DockedUI.contextMenuActive = false
        return true
      end
    else
      -- Navigation mode
      if key == "return" or key == "kpenter" then
        local qty = tonumber(menu.quantity) or 0
        if qty > 0 and DockedUI.player then
          if menu.type == "buy" then
            local cost = (menu.item.price or 0) * qty
            if DockedUI.player:getGC() >= cost then
              DockedUI.purchaseItem(menu.item, DockedUI.player, qty)
            end
          elseif menu.type == "sell" then
            if DockedUI.player.inventory and DockedUI.player.inventory[menu.item.id] and
               DockedUI.player.inventory[menu.item.id] >= qty then
            DockedUI.sellItem(menu.item, DockedUI.player, qty)
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

  if DockedUI.contextMenu.visible and DockedUI.contextMenuActive then
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
