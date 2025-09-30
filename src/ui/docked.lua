local Theme = require("src.core.theme")
local Util = require("src.core.util")
local Content = require("src.content.content")
local Viewport = require("src.core.viewport")
local Tooltip = require("src.ui.tooltip")
local Input = require("src.core.input")
local Notifications = require("src.ui.notifications")
local Quests = require("src.ui.quests")
local Nodes = require("src.ui.nodes")
local IconSystem = require("src.core.icon_system")
local Window = require("src.ui.common.window")
local UITabs = require("src.ui.common.tabs")
local UIUtils = require("src.ui.common.utils")
local Shop = require("src.ui.docked.shop")
local Dropdown = require("src.ui.common.dropdown")
-- Ship UI is standalone; do not require it here

local DockedUI = {}

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
DockedUI.stationType = nil

-- New Tabbed Interface State
DockedUI.tabs = {"Shop", "Quests", "Nodes"}
DockedUI.activeTab = "Shop"

DockedUI.furnaceState = {
    slots = {},
    selectedOreId = nil,
    selectedOre = nil,
    amountText = "1",
    inputActive = false,
    inputRect = nil,
    smeltButtonRect = nil,
    infoText = nil,
}

local function isFurnaceStation()
    return DockedUI.stationType == "ore_furnace_station"
end

local function resetFurnaceState()
    DockedUI.furnaceState.slots = {}
    DockedUI.furnaceState.selectedOre = nil
    DockedUI.furnaceState.selectedOreId = nil
    DockedUI.furnaceState.canSmelt = false
    DockedUI.furnaceState.inputRect = nil
    DockedUI.furnaceState.smeltButtonRect = nil
    DockedUI.furnaceState.infoText = nil
    if DockedUI.furnaceState.inputActive and love and love.keyboard and love.keyboard.setTextInput then
        love.keyboard.setTextInput(false)
    end
    DockedUI.furnaceState.inputActive = false
    DockedUI.furnaceState.amountText = "1"
end

local function collectFurnaceOres(player)
    local oresById = {}
    local order = {}
    if not player or not player.components or not player.components.cargo then
        return order
    end

    local cargo = player.components.cargo
    cargo:iterate(function(_, entry)
        if entry and entry.id then
            local item = Content.getItem(entry.id)
            if item and item.tags then
                local hasOreTag = false
                for _, tag in ipairs(item.tags) do
                    if tag == "ore" then
                        hasOreTag = true
                        break
                    end
                end
                if hasOreTag then
                    local existing = oresById[entry.id]
                    if existing then
                        existing.quantity = existing.quantity + (entry.qty or 0)
                    elseif (entry.qty or 0) > 0 then
                        local data = {
                            id = entry.id,
                            quantity = entry.qty or 0,
                            item = item,
                            name = item.name or entry.id,
                        }
                        oresById[entry.id] = data
                        table.insert(order, data)
                    end
                end
            end
        end
    end)

    table.sort(order, function(a, b)
        return (a.name or a.id) < (b.name or b.id)
    end)

    return order
end

local function ensureFurnaceSelection(ores)
    local state = DockedUI.furnaceState
    if not ores or #ores == 0 then
        state.selectedOre = nil
        state.selectedOreId = nil
        return
    end

    if state.selectedOreId then
        for _, ore in ipairs(ores) do
            if ore.id == state.selectedOreId then
                state.selectedOre = ore
                return
            end
        end
    end

    state.selectedOre = ores[1]
    state.selectedOreId = state.selectedOre and state.selectedOre.id or nil
    if state.selectedOre then
        if not state.amountText or state.amountText == "" then
            if (state.selectedOre.quantity or 0) <= 0 then
                state.amountText = "0"
            else
                state.amountText = tostring(math.min(state.selectedOre.quantity, 1))
            end
        end
        clampAmountText(state.selectedOre.quantity)
    end
end

local function clampAmountText(maxAmount)
    local text = DockedUI.furnaceState.amountText or "1"
    local amount = tonumber(text)
    if not amount or amount < 1 then
        amount = 1
    else
        amount = math.floor(amount)
    end
    if maxAmount then
        if maxAmount <= 0 then
            amount = 0
        else
            amount = math.min(amount, maxAmount)
        end
    end
    DockedUI.furnaceState.amountText = tostring(amount)
    return amount
end

local function drawFurnaceSlot(ore, rect, selected)
    local hover = false
    local mx, my = Viewport.getMousePosition()
    if mx >= rect.x and mx <= rect.x + rect.w and my >= rect.y and my <= rect.y + rect.h then
        hover = true
    end

    local bg1 = selected and Theme.colors.bg3 or Theme.colors.bg2
    local bg2 = selected and Theme.colors.bg2 or Theme.colors.bg1
    local border = selected and Theme.colors.accent or Theme.colors.border

    Theme.drawGradientGlowRect(rect.x, rect.y, rect.w, rect.h, 4, bg1, bg2, border,
        hover and Theme.effects.glowMedium or Theme.effects.glowWeak)

    local iconSize = rect.w - 16
    local iconX = rect.x + (rect.w - iconSize) * 0.5
    local iconY = rect.y + 10
    IconSystem.drawIconAny({ ore.item, ore.id }, iconX, iconY, iconSize, 1.0)

    local quantity = ore.quantity or 0
    Theme.setColor(quantity > 0 and Theme.colors.textHighlight or Theme.colors.textSecondary)
    love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
    local qtyText = Util.formatNumber and Util.formatNumber(quantity) or tostring(quantity)
    love.graphics.printf(qtyText, rect.x + 6, rect.y + rect.h - 26, rect.w - 12, "right")

    Theme.setColor(Theme.colors.text)
    love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
    love.graphics.printf(ore.name or ore.id, rect.x + 4, rect.y + rect.h - 16, rect.w - 8, "center")
end

local function drawNoOreMessage(areaX, areaY, areaW, areaH)
    Theme.setColor(Theme.colors.textSecondary)
    love.graphics.setFont(Theme.fonts and Theme.fonts.normal or love.graphics.getFont())
    love.graphics.printf("No ores available for smelting", areaX, areaY + areaH * 0.5 - 12, areaW, "center")
end

local function drawFurnaceBottomBar(x, y, w, h, selectedOre)
    Theme.drawGradientGlowRect(x, y, w, h, 4, Theme.colors.bg2, Theme.colors.bg1, Theme.colors.border, Theme.effects.glowWeak)

    local pad = 16
    local textY = y + pad
    local font = Theme.fonts and Theme.fonts.normal or love.graphics.getFont()
    love.graphics.setFont(font)
    Theme.setColor(Theme.colors.text)

    local label
    if selectedOre then
        label = string.format("Selected: %s", selectedOre.name or selectedOre.id)
    else
        label = "Select an ore to smelt"
    end
    love.graphics.print(label, x + pad, textY)

    if selectedOre then
        local qtyText = string.format("In cargo: %s", Util.formatNumber and Util.formatNumber(selectedOre.quantity) or tostring(selectedOre.quantity))
        Theme.setColor(Theme.colors.textSecondary)
        love.graphics.print(qtyText, x + pad, textY + font:getHeight() + 4)
    end

    local inputWidth = 140
    local inputHeight = 34
    local inputX = x + pad
    local inputY = y + h - inputHeight - pad
    local placeholder = selectedOre and "Amount" or "--"
    local focused = DockedUI.furnaceState.inputActive
    DockedUI.furnaceState.inputRect = UIUtils.drawTextInput(inputX, inputY, inputWidth, inputHeight,
        selectedOre and DockedUI.furnaceState.amountText or "", focused, placeholder)

    local buttonWidth = 160
    local buttonHeight = 40
    local buttonX = x + w - buttonWidth - pad
    local buttonY = y + h - buttonHeight - pad
    local amount = tonumber(DockedUI.furnaceState.amountText) or 0
    local hasOre = selectedOre and (selectedOre.quantity or 0) > 0
    local canSmelt = hasOre and amount > 0 and amount <= (selectedOre.quantity or 0)
    DockedUI.furnaceState.canSmelt = canSmelt
    local mx, my = Viewport.getMousePosition()
    local hover = canSmelt and mx >= buttonX and mx <= buttonX + buttonWidth and my >= buttonY and my <= buttonY + buttonHeight
    local buttonText = "Smelt"
    local options = {
        textColor = canSmelt and Theme.colors.text or Theme.colors.textDisabled,
        bg = canSmelt and Theme.colors.bg2 or Theme.colors.bg1,
        hoverBg = Theme.colors.bg3,
        border = Theme.colors.border,
    }
    DockedUI.furnaceState.smeltButtonRect = UIUtils.drawButton(buttonX, buttonY, buttonWidth, buttonHeight,
        buttonText, hover, false, options)

    return inputY + inputHeight
end

function DockedUI.drawFurnaceContent(window, x, y, w, h)
    local pad = (Theme.ui and Theme.ui.contentPadding) or 12
    local bottomBarHeight = 110
    local gridY = y + pad
    local gridHeight = h - bottomBarHeight - pad

    local ores = collectFurnaceOres(DockedUI.player)
    DockedUI.furnaceState.slots = {}
    ensureFurnaceSelection(ores)

    if #ores == 0 then
        drawNoOreMessage(x, gridY, w, gridHeight)
    else
        local slotSize = 120
        local spacing = 12
        local cols = math.max(1, math.floor((w - pad * 2 + spacing) / (slotSize + spacing)))
        local totalWidth = cols * slotSize + (cols - 1) * spacing
        local startX = x + (w - totalWidth) * 0.5
        local startY = gridY

        for index, ore in ipairs(ores) do
            local zeroBased = index - 1
            local row = math.floor(zeroBased / cols)
            local col = zeroBased % cols
            local slotX = math.floor(startX + col * (slotSize + spacing) + 0.5)
            local slotY = math.floor(startY + row * (slotSize + spacing) + 0.5)
            if slotY + slotSize <= gridY + gridHeight then
                local rect = { x = slotX, y = slotY, w = slotSize, h = slotSize }
                drawFurnaceSlot(ore, rect, DockedUI.furnaceState.selectedOreId == ore.id)
                table.insert(DockedUI.furnaceState.slots, { rect = rect, ore = ore })
            end
        end
    end

    drawFurnaceBottomBar(x + pad, y + h - bottomBarHeight, w - pad * 2, bottomBarHeight - pad, DockedUI.furnaceState.selectedOre)
end

local function furnaceClickInside(rect, x, y)
    return rect and UIUtils.pointInRect(x, y, rect)
end

local function executeFurnaceSmelt()
    local state = DockedUI.furnaceState
    local ore = state.selectedOre
    if not ore then
        Notifications.info("Select an ore to smelt first")
        return
    end
    local amount = clampAmountText(ore.quantity)
    if amount <= 0 then
        Notifications.info("Enter a valid amount to smelt")
        return
    end

    local itemName = ore.name or ore.id
    Notifications.action(string.format("Queued smelting of %d %s", amount, itemName))
    state.inputActive = false
    if love and love.keyboard and love.keyboard.setTextInput then
        love.keyboard.setTextInput(false)
    end
end

local function setFurnaceInputActive(active)
    local state = DockedUI.furnaceState
    if state.inputActive == active then return end
    state.inputActive = active and true or false
    if love and love.keyboard and love.keyboard.setTextInput then
        love.keyboard.setTextInput(state.inputActive)
    end
    if not state.inputActive then
        local amount = tonumber(state.amountText)
        local minValue = 1
        if state.selectedOre and (state.selectedOre.quantity or 0) <= 0 then
            minValue = 0
        end
        if not amount or amount < minValue then
            state.amountText = tostring(minValue)
        end
    end
end

local function handleFurnaceSlotClick(x, y)
    local state = DockedUI.furnaceState
    for _, slot in ipairs(state.slots or {}) do
        if furnaceClickInside(slot.rect, x, y) then
            state.selectedOreId = slot.ore.id
            state.selectedOre = slot.ore
            clampAmountText(slot.ore.quantity)
            return true
        end
    end
    return false
end

function DockedUI.handleFurnaceMousePressed(x, y, button)
    if not DockedUI.window then return false, false end

    if DockedUI.window:mousepressed(x, y, button) then
        return true, false
    end

    if button ~= 1 then
        setFurnaceInputActive(false)
        return false, false
    end

    if handleFurnaceSlotClick(x, y) then
        setFurnaceInputActive(false)
        return true, false
    end

    local state = DockedUI.furnaceState
    if furnaceClickInside(state.inputRect, x, y) and state.selectedOre then
        setFurnaceInputActive(true)
        return true, false
    end

    setFurnaceInputActive(false)

    if state.canSmelt and furnaceClickInside(state.smeltButtonRect, x, y) then
        executeFurnaceSmelt()
        return true, false
    end

    return false, false
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
            DockedUI.player:undock()
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
    resetFurnaceState()
    DockedUI.activeTab = "Furnace"
  elseif DockedUI.activeTab == "Furnace" then
    DockedUI.activeTab = "Shop"
  end

  -- Ship UI is standalone. Refresh of ship UI should happen when the Ship window is opened.
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
  DockedUI.searchActive = false
  DockedUI.stationType = nil
  DockedUI.station = nil
  resetFurnaceState()
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
    if not DockedUI.visible or not player or not player.docked then return end
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

      if player.components and player.components.cargo then
        player.components.cargo:add(itemId, 1)
      end

      purchasedItems[i] = proceduralTurret.proceduralName or proceduralTurret.name
    end

    -- Refresh inventory display once after adding all turrets
    local Inventory = require("src.ui.inventory")
    if Inventory.refresh then Inventory.refresh() end

    itemName = purchasedItems[1] -- Use the first item's name for the notification
  else
    if player.components and player.components.cargo then
      player.components.cargo:add(itemId, quantity)
    end
    local Inventory = require("src.ui.inventory")
    if Inventory.refresh then Inventory.refresh() end
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
                -- ship tab removed
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
                    DockedUI.searchActive = false
                    Shop.hideContextMenu(DockedUI)
                    return true, false
                end
            end
        end
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
    local state = DockedUI.furnaceState
    if key == "escape" then
      setFurnaceInputActive(false)
      return true, true
    end

    if state.inputActive and key == "backspace" then
      local text = state.amountText or ""
      state.amountText = text:sub(1, -2)
      return true, false
    end

    if key == "return" or key == "kpenter" then
      if state.canSmelt then
        executeFurnaceSmelt()
      elseif state.selectedOre then
        clampAmountText(state.selectedOre.quantity)
      end
      return true, false
    end

    return true, false
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
    local state = DockedUI.furnaceState
    if state.inputActive and state.selectedOre then
      local digits = text:gsub("%D", "")
      if digits ~= "" then
        local base = state.amountText or ""
        if base == "0" then base = "" end
        local combined = base .. digits
        if #combined > 6 then
          combined = combined:sub(1, 6)
        end
        state.amountText = combined
      end
      return true
    end
    return false
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
