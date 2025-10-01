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
-- Removed activeShopTab - no longer using separate buy/sell tabs
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
    hoveredRecipe = nil,
    hoverRect = nil,
}

local function isFurnaceStation()
    return DockedUI.stationType == "ore_furnace_station"
end

-- Furnace recipes
local FURNACE_RECIPES = {
    ["stones"] = {
        { output = "credits", ratio = 1, type = "credits" }, -- 1 stone = 1 credit
        { output = "ore_tritanium", ratio = 25, type = "item" } -- 25 stones = 1 tritanium
    },
    ["ore_tritanium"] = {
        { output = "credits", ratio = 50, type = "credits" } -- 1 tritanium = 50 credits
    }
}

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

local function collectFurnaceRecipes(player)
    local recipes = {}
    local playerQuantities = {}
    
    -- Get player's current quantities
    if player and player.components and player.components.cargo then
        player.components.cargo:iterate(function(_, entry)
            if entry and entry.id then
                playerQuantities[entry.id] = (playerQuantities[entry.id] or 0) + (entry.qty or 0)
            end
        end)
    end
    
    -- Create recipe cards for all available recipes
    for inputId, recipeList in pairs(FURNACE_RECIPES) do
        for _, recipe in ipairs(recipeList) do
            local inputItem = Content.getItem(inputId)
            if inputItem then
                local playerQty = playerQuantities[inputId] or 0
                local recipeCard = {
                    id = inputId,
                    quantity = playerQty,
                    item = inputItem,
                    name = inputItem.name or inputId,
                    recipe = recipe,
                    canSmelt = playerQty >= recipe.ratio,
                    maxSmeltable = math.floor(playerQty / recipe.ratio)
                }
                table.insert(recipes, recipeCard)
            end
        end
    end
    
    -- Also include any ores the player has that don't have recipes yet
    if player and player.components and player.components.cargo then
        player.components.cargo:iterate(function(_, entry)
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
                    
                    -- Only add if it's an ore and doesn't have recipes
                    if hasOreTag and not FURNACE_RECIPES[entry.id] then
                        local existing = nil
                        for _, recipe in ipairs(recipes) do
                            if recipe.id == entry.id then
                                existing = recipe
                                break
                            end
                        end
                        
                        if existing then
                            existing.quantity = existing.quantity + (entry.qty or 0)
                        else
                            local recipeCard = {
                                id = entry.id,
                                quantity = entry.qty or 0,
                                item = item,
                                name = item.name or entry.id,
                                recipe = nil, -- No recipe available
                                canSmelt = false,
                                maxSmeltable = 0
                            }
                            table.insert(recipes, recipeCard)
                        end
                    end
                end
            end
        end)
    end

    table.sort(recipes, function(a, b)
        -- Sort by: has recipe first, then by name
        if a.recipe and not b.recipe then return true end
        if not a.recipe and b.recipe then return false end
        return (a.name or a.id) < (b.name or b.id)
    end)

    return recipes
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

local function ensureFurnaceSelection(recipes)
    local state = DockedUI.furnaceState
    if not recipes or #recipes == 0 then
        state.selectedOre = nil
        state.selectedOreId = nil
        return
    end

    if state.selectedOreId then
        for _, recipe in ipairs(recipes) do
            if recipe.id == state.selectedOreId then
                state.selectedOre = recipe
                return
            end
        end
    end

    state.selectedOre = recipes[1]
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

local function drawFurnaceSlot(recipe, rect, selected)
    local hover = false
    local mx, my = Viewport.getMousePosition()
    if mx >= rect.x and mx <= rect.x + rect.w and my >= rect.y and my <= rect.y + rect.h then
        hover = true
    end

    local bg1 = selected and Theme.colors.bg3 or Theme.colors.bg2
    local bg2 = selected and Theme.colors.bg2 or Theme.colors.bg1
    local border = selected and Theme.colors.accent or Theme.colors.border

    -- Dim the card if no recipe available
    local alpha = recipe.recipe and 1.0 or 0.6
    if recipe.recipe then
        Theme.drawGradientGlowRect(rect.x, rect.y, rect.w, rect.h, 4, bg1, bg2, border,
            hover and Theme.effects.glowMedium or Theme.effects.glowWeak)
    else
        Theme.drawGradientGlowRect(rect.x, rect.y, rect.w, rect.h, 4, bg1, bg2, Theme.colors.border,
            hover and Theme.effects.glowWeak or 0)
    end

    -- Draw input material icon at the top
    local iconSize = rect.w - 16
    local iconX = rect.x + (rect.w - iconSize) * 0.5
    local iconY = rect.y + 10
    IconSystem.drawIconAny({ recipe.item, recipe.id }, iconX, iconY, iconSize, alpha)

    -- Draw output item icon above the quantity
    if recipe.recipe then
        local outputIconSize = 24
        local outputIconX = rect.x + (rect.w - outputIconSize) * 0.5
        local outputIconY = rect.y + rect.h - 50
        
        if recipe.recipe.type == "credits" then
            -- Draw credits icon (simple circle with $)
            Theme.setColor(Theme.colors.accent)
            love.graphics.circle("fill", outputIconX + outputIconSize/2, outputIconY + outputIconSize/2, outputIconSize/2)
            Theme.setColor(Theme.colors.bg0)
            love.graphics.setFont(Theme.fonts and Theme.fonts.tiny or love.graphics.getFont())
            love.graphics.printf("$", outputIconX, outputIconY, outputIconSize, "center")
        elseif recipe.recipe.type == "item" then
            -- Draw output item icon
            local outputItem = Content.getItem(recipe.recipe.output)
            if outputItem then
                IconSystem.drawIconAny({ outputItem, recipe.recipe.output }, outputIconX, outputIconY, outputIconSize, alpha)
            end
        end
    end

    -- Show player's quantity at bottom center
    local quantity = recipe.quantity or 0
    local qtyColor = quantity > 0 and Theme.colors.textHighlight or Theme.colors.textSecondary
    if not recipe.recipe then
        qtyColor = Theme.colors.textDisabled
    end
    Theme.setColor(qtyColor)
    love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
    local qtyText = Util.formatNumber and Util.formatNumber(quantity) or tostring(quantity)
    love.graphics.printf(qtyText, rect.x + 4, rect.y + rect.h - 20, rect.w - 8, "center")
    
    -- Store hover state for tooltip
    if hover then
        DockedUI.furnaceState.hoveredRecipe = recipe
        DockedUI.furnaceState.hoverRect = rect
    end
end

local function drawNoOreMessage(areaX, areaY, areaW, areaH)
    Theme.setColor(Theme.colors.textSecondary)
    love.graphics.setFont(Theme.fonts and Theme.fonts.normal or love.graphics.getFont())
    love.graphics.printf("No ores available for smelting", areaX, areaY + areaH * 0.5 - 12, areaW, "center")
end

local function drawFurnaceTooltip(recipe, rect)
    if not recipe or not rect then return end
    
    local mx, my = Viewport.getMousePosition()
    local tooltipX = mx + 10
    local tooltipY = my - 10
    
    -- Calculate tooltip size - only show recipe information
    local lines = {}
    
    if recipe.recipe then
        if recipe.recipe.type == "credits" then
            table.insert(lines, string.format("%d %s → %d Credits", recipe.recipe.ratio, recipe.name or recipe.id, 1))
        elseif recipe.recipe.type == "item" then
            table.insert(lines, string.format("%d %s → %s", recipe.recipe.ratio, recipe.name or recipe.id, recipe.recipe.output))
        end
    else
        table.insert(lines, "No smelting recipe available")
    end
    
    -- Calculate tooltip dimensions
    local maxWidth = 0
    local lineHeight = 16
    local padding = 8
    
    love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
    for _, line in ipairs(lines) do
        local width = love.graphics.getFont():getWidth(line)
        maxWidth = math.max(maxWidth, width)
    end
    
    local tooltipW = maxWidth + padding * 2
    local tooltipH = #lines * lineHeight + padding * 2
    
    -- Adjust position to stay on screen
    local sw, sh = Viewport.getDimensions()
    if tooltipX + tooltipW > sw then
        tooltipX = mx - tooltipW - 10
    end
    if tooltipY + tooltipH > sh then
        tooltipY = my - tooltipH - 10
    end
    
    -- Draw tooltip background
    Theme.setColor(Theme.colors.bg0)
    love.graphics.rectangle("fill", tooltipX, tooltipY, tooltipW, tooltipH)
    Theme.setColor(Theme.colors.border)
    love.graphics.rectangle("line", tooltipX, tooltipY, tooltipW, tooltipH)
    
    -- Draw tooltip text
    Theme.setColor(Theme.colors.text)
    for i, line in ipairs(lines) do
        local y = tooltipY + padding + (i - 1) * lineHeight
        love.graphics.print(line, tooltipX + padding, y)
    end
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

    -- Clear hover state
    DockedUI.furnaceState.hoveredRecipe = nil
    DockedUI.furnaceState.hoverRect = nil

    local recipes = collectFurnaceRecipes(DockedUI.player)
    DockedUI.furnaceState.slots = {}
    ensureFurnaceSelection(recipes)

    if #recipes == 0 then
        drawNoOreMessage(x, gridY, w, gridHeight)
    else
        local slotSize = 120
        local spacing = 12
        local cols = math.max(1, math.floor((w - pad * 2 + spacing) / (slotSize + spacing)))
        local totalWidth = cols * slotSize + (cols - 1) * spacing
        local startX = x + (w - totalWidth) * 0.5
        local startY = gridY

        for index, recipe in ipairs(recipes) do
            local zeroBased = index - 1
            local row = math.floor(zeroBased / cols)
            local col = zeroBased % cols
            local slotX = math.floor(startX + col * (slotSize + spacing) + 0.5)
            local slotY = math.floor(startY + row * (slotSize + spacing) + 0.5)
            if slotY + slotSize <= gridY + gridHeight then
                local rect = { x = slotX, y = slotY, w = slotSize, h = slotSize }
                drawFurnaceSlot(recipe, rect, DockedUI.furnaceState.selectedOreId == recipe.id)
                table.insert(DockedUI.furnaceState.slots, { rect = rect, ore = recipe })
            end
        end
    end

    drawFurnaceBottomBar(x + pad, y + h - bottomBarHeight, w - pad * 2, bottomBarHeight - pad, DockedUI.furnaceState.selectedOre)
    
    -- Draw tooltip if hovering over a recipe
    if DockedUI.furnaceState.hoveredRecipe and DockedUI.furnaceState.hoverRect then
        drawFurnaceTooltip(DockedUI.furnaceState.hoveredRecipe, DockedUI.furnaceState.hoverRect)
    end
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

    local itemId = ore.id
    local recipes = FURNACE_RECIPES[itemId]
    
    if not recipes then
        Notifications.info("No smelting recipes available for " .. (ore.name or itemId))
        return
    end

    -- For now, use the first available recipe
    local recipe = recipes[1]
    if not recipe then
        Notifications.info("No valid recipe found")
        return
    end

    -- Calculate how much we can actually smelt based on available materials
    local maxSmeltable = math.floor(amount / recipe.ratio)
    if maxSmeltable <= 0 then
        Notifications.info(string.format("Need at least %d %s to smelt", recipe.ratio, ore.name or itemId))
        return
    end

    -- Calculate actual amounts
    local inputAmount = maxSmeltable * recipe.ratio
    local outputAmount = maxSmeltable

    -- Remove input materials
    if not DockedUI.player:removeItem(itemId, inputAmount) then
        Notifications.info("Failed to remove materials from cargo")
        return
    end

    -- Add output
    if recipe.type == "credits" then
        DockedUI.player:addGC(outputAmount)
        Notifications.action(string.format("Smelted %d %s into %d credits", inputAmount, ore.name or itemId, outputAmount))
    elseif recipe.type == "item" then
        DockedUI.player:addItem(recipe.output, outputAmount)
        Notifications.action(string.format("Smelted %d %s into %d %s", inputAmount, ore.name or itemId, outputAmount, recipe.output))
    end

    -- Update furnace state
    state.inputActive = false
    if love and love.keyboard and love.keyboard.setTextInput then
        love.keyboard.setTextInput(false)
    end
    
    -- Refresh the recipe list
    local recipes = collectFurnaceRecipes(DockedUI.player)
    ensureFurnaceSelection(recipes)
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
        -- Shop content area (no more tabs)
        local shopContentY = contentY
        local shopContentH = h - (shopContentY - y) - pad
        
        -- Draw combined shop interface
        DockedUI.drawCombinedShop(x + pad, shopContentY, w - pad * 2, shopContentH, player, mx, my)
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
  local dropdownWidth = 120
  local searchX = x + w - searchWidth
  local dropdownX = x
  
  -- Category dropdown
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
