local Theme = require("src.core.theme")
local Util = require("src.core.util")
local Viewport = require("src.core.viewport")
local Notifications = require("src.ui.notifications")
local Quests = require("src.ui.quests")
local Nodes = require("src.ui.nodes")
local Window = require("src.ui.common.window")
local UITabs = require("src.ui.common.tabs")
local Shop = require("src.ui.docked.shop")
local FurnacePanel = require("src.ui.docked.furnace_panel")
local Dropdown = require("src.ui.common.dropdown")
-- Ship UI is standalone; do not require it here

local DockedUI = {}

local function get_docking(player)
    return player and player.components and player.components.docking_status
end

local function computeWindowBounds()
    local sw, sh = Viewport.getDimensions()
    local width = math.floor(math.min(sw - 80, math.max(900, sw * 0.65)))
    local height = math.floor(math.min(sh - 80, math.max(560, sh * 0.7)))
    local x = math.floor((sw - width) * 0.5)
    local y = math.floor((sh - height) * 0.5)
    return x, y, width, height
end

local function applyWindowBounds(window)
    if not window then return end
    local x, y, width, height = computeWindowBounds()
    window.x, window.y = x, y
    window.width, window.height = width, height
end

-- State
DockedUI.visible = false
DockedUI.player = nil
DockedUI.shopScroll = 0
DockedUI.selectedCategory = "All"
DockedUI.buybackItems = {}
DockedUI.searchText = ""
DockedUI.searchActive = false
DockedUI.hoveredItem = nil
DockedUI.hoverTimer = 0
DockedUI.drag = nil
DockedUI.contextMenu = { visible = false, x = 0, y = 0, item = nil, quantity = "1", type = "buy" }
DockedUI.contextMenuActive = false -- For text input focus
DockedUI.stationType = nil

-- New Tabbed Interface State
DockedUI.tabs = {"Shop", "Quests", "Nodes"}
DockedUI.activeTab = "Shop"

DockedUI.furnaceState = FurnacePanel.createState()

local function isFurnaceStation()
    return DockedUI.stationType == "ore_furnace_station"
end

function DockedUI.drawFurnaceContent(window, x, y, w, h)
    FurnacePanel.draw(DockedUI.furnaceState, DockedUI.player, x, y, w, h)
end

function DockedUI.handleFurnaceMousePressed(x, y, button)
    if not DockedUI.window then return false, false end

    if DockedUI.window:mousepressed(x, y, button) then
        return true, false
    end

    return FurnacePanel.mousepressed(DockedUI.furnaceState, DockedUI.player, x, y, button)
end



-- Window properties
-- Initialize the docked window
function DockedUI.init()
    local x, y, width, height = computeWindowBounds()
    DockedUI.window = Window.new({
        title = "Station Services",
        x = x,
        y = y,
        width = width,
        height = height,
        useLoadPanelTheme = true,
        closable = true,
        draggable = true,
        resizable = false,
        drawContent = DockedUI.drawContent,
        onClose = function()
        if DockedUI.player then
            local PlayerSystem = require("src.systems.player")
            PlayerSystem.undock(DockedUI.player)
        end
        end
    })
    -- Ship UI is standalone; do not embed ship UI inside DockedUI
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
  if DockedUI.window then
    applyWindowBounds(DockedUI.window)
  end
  DockedUI.player = player
  DockedUI.station = station
  DockedUI.stationType = station and station.components and station.components.station and station.components.station.type or nil
  if DockedUI.window then
    if isFurnaceStation() then
      local name = (station and station.components and station.components.station and station.components.station.name) or "Furnace Station"
      DockedUI.window.title = string.format("%s — Furnace Operations", name)
    else
      DockedUI.window.title = "Station Services"
    end
  end
  if DockedUI.quests then
    DockedUI.quests.station = station
  end

  if isFurnaceStation() then
    FurnacePanel.reset(DockedUI.furnaceState)
    DockedUI.activeTab = "Furnace"
  elseif DockedUI.activeTab == "Furnace" then
    DockedUI.activeTab = "Shop"
  end

  -- Ship UI is standalone. Refresh of ship UI should happen when the Ship window is opened.
end


-- Hide the docked window
function DockedUI.hide()
  DockedUI.visible = false
  DockedUI.player = nil
  DockedUI.searchActive = false
  DockedUI.stationType = nil
  DockedUI.station = nil
  FurnacePanel.reset(DockedUI.furnaceState)
  Shop.hideContextMenu(DockedUI)
end

-- Check if docked window is visible
function DockedUI.isVisible()
  return DockedUI.visible
end

function DockedUI.isSearchActive()
  return DockedUI.searchActive
end

-- Draw the docked window
function DockedUI.draw(player)
    local docking = get_docking(player)
    if not DockedUI.visible or not player or not (docking and docking.docked) then return end
    if not DockedUI.window then DockedUI.init() end
    DockedUI.window.visible = DockedUI.visible
    DockedUI.window:draw()
    
    -- Draw context menu on top of everything else
    if DockedUI.activeTab == "Shop" and not isFurnaceStation() then
        local mx, my = Viewport.getMousePosition()
        Shop.drawContextMenu(DockedUI, mx, my)
    end
end

function DockedUI.drawContent(window, x, y, w, h)
    local player = DockedUI.player
    local mx, my = Viewport.getMousePosition()

    if isFurnaceStation() then
        DockedUI.drawFurnaceContent(window, x, y, w, h)
        return
    end

    -- Main tabs
    local pad = (Theme.ui and Theme.ui.contentPadding) or 12
    local mainTabY = y + ((Theme.ui and Theme.ui.contentPadding) or 8)
    local mainTabH = (Theme.ui and Theme.ui.buttonHeight) or 28
    DockedUI.drawMainTabs(x + pad, mainTabY, w - pad * 2, mainTabH)

    -- Content area
    local contentY = mainTabY + mainTabH + ((Theme.ui and Theme.ui.buttonSpacing) or 8)
    local contentH = h - (contentY - y) - pad

    if DockedUI.activeTab == "Shop" then
        -- Shop content area (no more tabs)
        local shopContentY = contentY
        local shopContentH = h - (shopContentY - y) - pad
        
        -- Draw combined shop interface
        DockedUI.drawCombinedShop(x + pad, shopContentY, w - pad * 2, shopContentH, player, mx, my)
        
        -- Draw dropdown options on top of everything else
        if DockedUI.categoryDropdown then
            DockedUI.categoryDropdown:drawOptionsOnly(mx, my)
        end
  elseif DockedUI.activeTab == "Quests" then
        DockedUI.quests:draw(player, x + pad, contentY, w - pad * 2, contentH)
    elseif DockedUI.activeTab == "Nodes" then
        DockedUI.nodes:draw(player, x + pad, contentY, w - pad * 2, contentH)
    end

    -- Ship UI is standalone; no embedded dropdown options to draw
end

function DockedUI.drawMainTabs(x, y, w, h)
  local res = UITabs.draw(x, y, w, h, DockedUI.tabs, DockedUI.activeTab)
  DockedUI._mainTabs = res.rects
end

-- Draw combined shop interface with category dropdown and search
function DockedUI.drawCombinedShop(x, y, w, h, player, mx, my)
  local searchWidth = 150
  local dropdownWidth = 150
  local searchX = x + w - searchWidth
  local dropdownX = x
  
  -- Category dropdown button only (options drawn later for z-ordering)
  DockedUI.categoryDropdown:setPosition(dropdownX, y)
  DockedUI.categoryDropdown:drawButtonOnly(mx, my)
  
  -- Search bar
  local searchIsActive = DockedUI.searchActive
  Theme.drawGradientGlowRect(searchX, y, searchWidth, 28, 3,
    Theme.colors.bg0, Theme.colors.bg1, searchIsActive and Theme.colors.accent or Theme.colors.border, Theme.effects.glowWeak)
  
  love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
  if DockedUI.searchText == "" and not searchIsActive then
    Theme.setColor(Theme.colors.textDisabled)
    love.graphics.print("Search...", searchX + 6, y + 8)
  else
    Theme.setColor(Theme.colors.text)
    love.graphics.print(DockedUI.searchText, searchX + 6, y + 8)
  end
  
  if searchIsActive and math.fmod(love.timer.getTime(), 1) > 0.5 then
    local textW = love.graphics.getFont():getWidth(DockedUI.searchText)
    love.graphics.rectangle("fill", searchX + 6 + textW, y + 4, 2, 20)
  end
  
  DockedUI._searchBar = { x = searchX, y = y, w = searchWidth, h = 28 }
  
  -- Draw combined shop and inventory content
  local contentY = y + 28 + 8
  local contentH = h - 28 - 8
  DockedUI.drawCombinedShopContent(x, contentY, w, contentH, player)
end

-- Draw combined shop content (shop items only)
function DockedUI.drawCombinedShopContent(x, y, w, h, player)
  if not player then return end
  
  -- Shop items only - use full width
  Theme.setColor(Theme.colors.text)
  love.graphics.setFont(Theme.fonts and Theme.fonts.medium or love.graphics.getFont())
  love.graphics.print("Shop Items", x, y)
  
  local shopY = y + 20
  local shopH = h - 20
  DockedUI.drawShopItems(x, shopY, w, shopH, player)
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
  DockedUI.shopScroll = 0 -- Disable scrolling for shop items
  return Shop.drawShopItems(DockedUI, x, y, w, h, player)
end

-- Purchase an item (can handle bulk purchases)
function DockedUI.purchaseItem(item, player, quantity)
  quantity = quantity or 1
  if not player or not item or quantity <= 0 then return false end

  local totalCost = item.price * quantity
  if player:getGC() < totalCost then return false end

  player:spendGC(totalCost)

  -- Add items to player inventory (turrets are vanilla from shop)
  local itemId = item.id
  local itemName = item.name

  if player.components and player.components.cargo then
    player.components.cargo:add(itemId, quantity)
  end
  
  local Inventory = require("src.ui.inventory")
  if Inventory.refresh then Inventory.refresh() end

  -- Create single notification with quantity
  local notificationText = quantity > 1 and ("Purchased " .. itemName .. " x" .. quantity) or ("Purchased " .. itemName)
  Notifications.action(notificationText)
  return true
end

-- Sell an item (can handle bulk sales)
function DockedUI.sellItem(item, player, quantity)
  quantity = quantity or 1
  if not player or not item or quantity <= 0 then return false end

  local cargo = player.components and player.components.cargo
  if not cargo or not cargo:has(item.id, quantity) then
    return false
  end

  cargo:remove(item.id, quantity)

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
function DockedUI.mousepressed(x, y, button, player)
    if not DockedUI.visible then return false, false end
    if not DockedUI.window then return false, false end

    if player then
        DockedUI.player = player
    end
    local currentPlayer = DockedUI.player

    if isFurnaceStation() then
        return DockedUI.handleFurnaceMousePressed(x, y, button)
    end

    if DockedUI.window:mousepressed(x, y, button) then
        return true, false
    end

    -- Main tabs
    if DockedUI._mainTabs then
        for _, tab in ipairs(DockedUI._mainTabs) do
            if x >= tab.x and x <= tab.x + tab.w and y >= tab.y and y <= tab.y + tab.h then
                DockedUI.activeTab = tab.name
                if DockedUI.activeTab ~= "Shop" then
                    DockedUI.searchActive = false
                    Shop.hideContextMenu(DockedUI)
                end
                return true, false
            end
        end
    end

    -- Delegate to active tab
    if DockedUI.activeTab == "Shop" then
        return Shop.mousepressed(DockedUI, x, y, button, currentPlayer)
    elseif DockedUI.activeTab == "Quests" and DockedUI.quests then
        return DockedUI.quests:mousepressed(currentPlayer, x, y, button)
    elseif DockedUI.activeTab == "Nodes" and DockedUI.nodes then
        return DockedUI.nodes:mousepressed(currentPlayer, x, y, button)
    end

    return false, false
end

-- Handle mouse release
function DockedUI.mousereleased(x, y, button, player)
    if not DockedUI.visible then return false, false end
    if not DockedUI.window then return false, false end

    if player then
        DockedUI.player = player
    end
    local currentPlayer = DockedUI.player

    if isFurnaceStation() then
        if DockedUI.window:mousereleased(x, y, button) then
            return true, false
        end
        return false, false
    end

    if DockedUI.window:mousereleased(x, y, button) then
        return true, false
    end

    if button == 1 and DockedUI._draggingScroll then
        DockedUI._draggingScroll = nil
        DockedUI._dragScrollOffsetY = nil
        return true, false
    end

    -- Delegate to active tab
    if DockedUI.activeTab == "Quests" and DockedUI.quests then
        return DockedUI.quests:mousereleased(currentPlayer, x, y, button)
    elseif DockedUI.activeTab == "Nodes" and DockedUI.nodes then
        return DockedUI.nodes:mousereleased(currentPlayer, x, y, button)
    end

    return false, false
end

-- Handle mouse movement
function DockedUI.mousemoved(x, y, dx, dy, player)
    if not DockedUI.visible then return false, false end
    if not DockedUI.window then return false, false end

    if player then
        DockedUI.player = player
    end
    local currentPlayer = DockedUI.player

    if isFurnaceStation() then
        if DockedUI.window:mousemoved(x, y, dx, dy) then
            return true, false
        end
        return false, false
    end

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

    -- Handle category dropdown mousemoved
    if DockedUI.activeTab == "Shop" and DockedUI.categoryDropdown then
        DockedUI.categoryDropdown:mousemoved(x, y)
    end

    -- Delegate to active tab
    if DockedUI.activeTab == "Quests" and DockedUI.quests then
        return DockedUI.quests:mousemoved(currentPlayer, x, y, dx, dy)
    elseif DockedUI.activeTab == "Nodes" and DockedUI.nodes then
        return DockedUI.nodes:mousemoved(currentPlayer, x, y, dx, dy)
    end

    return false, false
end

-- Handle mouse wheel
function DockedUI.wheelmoved(dx, dy, player)
  if not DockedUI.visible then return false end
  if isFurnaceStation() then
    return false
  end
  if player then
    DockedUI.player = player
  end
  -- Nodes tab: forward to nodes panel for chart zoom
  if DockedUI.activeTab == "Nodes" and DockedUI.nodes and DockedUI.nodes.wheelmoved then
    return DockedUI.nodes:wheelmoved(DockedUI.player, dx, dy)
  end
  return false
end

-- Handle key press
function DockedUI.keypressed(key, scancode, isrepeat, player)
  if not DockedUI.visible then return false end

  if player then
    DockedUI.player = player
  end
  local currentPlayer = DockedUI.player

  if isFurnaceStation() then
    return FurnacePanel.keypressed(DockedUI.furnaceState, key, currentPlayer)
  end

  if DockedUI.activeTab == "Shop" then
    local consumed, shouldClose = Shop.keypressed(DockedUI, key, scancode, isrepeat, currentPlayer)
    if consumed ~= nil then
      return consumed, shouldClose or false
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

function DockedUI.textinput(text, player)
  if not DockedUI.visible then return false end

  if player then
    DockedUI.player = player
  end

  if isFurnaceStation() then
    return FurnacePanel.textinput(DockedUI.furnaceState, text)
  end

  if DockedUI.activeTab == "Shop" then
    local consumed = Shop.textinput(DockedUI, text, player)
    if consumed ~= nil then
      return consumed
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

  if DockedUI.activeTab == "Quests" and DockedUI.quests then
    DockedUI.quests:update(dt)
  elseif DockedUI.activeTab == "Nodes" and DockedUI.nodes then
    DockedUI.nodes:update(dt)
  end
end

return DockedUI
