local Theme = require("src.core.theme")
local Util = require("src.core.util")
local Content = require("src.content.content")
local Viewport = require("src.core.viewport")
local UIUtils = require("src.ui.common.utils")
local IconSystem = require("src.core.icon_system")
local Notifications = require("src.ui.notifications")

local FurnacePanel = {}

local FURNACE_RECIPES = {
    ["ore_tritanium"] = {
        { output = "credits", ratio = 50, type = "credits" }
    }
}

function FurnacePanel.createState()
    return {
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
        canSmelt = false,
    }
end

function FurnacePanel.reset(state)
    state.slots = {}
    state.selectedOre = nil
    state.selectedOreId = nil
    state.canSmelt = false
    state.inputRect = nil
    state.smeltButtonRect = nil
    state.infoText = nil
    if state.inputActive and love and love.keyboard and love.keyboard.setTextInput then
        love.keyboard.setTextInput(false)
    end
    state.inputActive = false
    state.amountText = "1"
    state.hoveredRecipe = nil
    state.hoverRect = nil
end

local function collectRecipes(player)
    local recipes = {}
    local playerQuantities = {}

    if player and player.components and player.components.cargo then
        player.components.cargo:iterate(function(_, entry)
            if entry and entry.id then
                playerQuantities[entry.id] = (playerQuantities[entry.id] or 0) + (entry.qty or 0)
            end
        end)
    end

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
                    canSmelt = playerQty >= (recipe.ratio or 1),
                    maxSmeltable = recipe.ratio and math.floor(playerQty / recipe.ratio) or 0
                }
                table.insert(recipes, recipeCard)
            end
        end
    end

    if player and player.components and player.components.cargo then
        player.components.cargo:iterate(function(_, entry)
            if entry and entry.id and not FURNACE_RECIPES[entry.id] then
                local item = Content.getItem(entry.id)
                if item then
                    local exists = false
                    for _, recipe in ipairs(recipes) do
                        if recipe.id == entry.id then
                            exists = true
                            break
                        end
                    end
                    if not exists then
                        table.insert(recipes, {
                            id = entry.id,
                            quantity = entry.qty or 0,
                            item = item,
                            name = item.name or entry.id,
                            recipe = nil,
                            canSmelt = false,
                            maxSmeltable = 0
                        })
                    end
                end
            end
        end)
    end

    table.sort(recipes, function(a, b)
        if a.recipe and not b.recipe then return true end
        if not a.recipe and b.recipe then return false end
        return (a.name or a.id) < (b.name or b.id)
    end)

    return recipes
end

local function clampAmountText(state, maxAmount)
    local text = state.amountText or "1"
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
    state.amountText = tostring(amount)
    return amount
end

local function ensureSelection(state, recipes)
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
        clampAmountText(state, state.selectedOre.quantity)
    end
end

local function drawSlot(state, recipe, rect, selected)
    local hover = false
    local mx, my = Viewport.getMousePosition()
    if mx >= rect.x and mx <= rect.x + rect.w and my >= rect.y and my <= rect.y + rect.h then
        hover = true
    end

    local bg1 = selected and Theme.colors.bg3 or Theme.colors.bg2
    local bg2 = selected and Theme.colors.bg2 or Theme.colors.bg1
    local border = selected and Theme.colors.accent or Theme.colors.border

    local alpha = recipe.recipe and 1.0 or 0.6
    if recipe.recipe then
        Theme.drawGradientGlowRect(rect.x, rect.y, rect.w, rect.h, 4, bg1, bg2, border,
            hover and Theme.effects.glowMedium or Theme.effects.glowWeak)
    else
        Theme.drawGradientGlowRect(rect.x, rect.y, rect.w, rect.h, 4, bg1, bg2, Theme.colors.border,
            hover and Theme.effects.glowWeak or 0)
    end

    local iconSize = rect.w - 16
    local iconX = rect.x + (rect.w - iconSize) * 0.5
    local iconY = rect.y + 10
    IconSystem.drawIconAny({ recipe.item, recipe.id }, iconX, iconY, iconSize, alpha)

    if recipe.recipe then
        local outputIconSize = 24
        local outputIconX = rect.x + (rect.w - outputIconSize) * 0.5
        local outputIconY = rect.y + rect.h - 50

        if recipe.recipe.type == "credits" then
            Theme.setColor(Theme.colors.accent)
            love.graphics.circle("fill", outputIconX + outputIconSize/2, outputIconY + outputIconSize/2, outputIconSize/2)
            Theme.setColor(Theme.colors.bg0)
            love.graphics.setFont(Theme.fonts and Theme.fonts.tiny or love.graphics.getFont())
            love.graphics.printf("$", outputIconX, outputIconY, outputIconSize, "center")
        elseif recipe.recipe.type == "item" then
            local outputItem = Content.getItem(recipe.recipe.output)
            if outputItem then
                IconSystem.drawIconAny({ outputItem, recipe.recipe.output }, outputIconX, outputIconY, outputIconSize, alpha)
            end
        end
    end

    local quantity = recipe.quantity or 0
    local qtyColor = quantity > 0 and Theme.colors.textHighlight or Theme.colors.textSecondary
    if not recipe.recipe then
        qtyColor = Theme.colors.textDisabled
    end
    Theme.setColor(qtyColor)
    love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
    local qtyText = Util.formatNumber and Util.formatNumber(quantity) or tostring(quantity)
    love.graphics.printf(qtyText, rect.x + 4, rect.y + rect.h - 20, rect.w - 8, "center")

    if hover then
        state.hoveredRecipe = recipe
        state.hoverRect = rect
    end
end

local function drawNoOreMessage(areaX, areaY, areaW, areaH)
    Theme.setColor(Theme.colors.textSecondary)
    love.graphics.setFont(Theme.fonts and Theme.fonts.normal or love.graphics.getFont())
    love.graphics.printf("No ores available for smelting", areaX, areaY + areaH * 0.5 - 12, areaW, "center")
end

local function drawTooltip(state)
    local recipe = state.hoveredRecipe
    local rect = state.hoverRect
    if not recipe or not rect then return end

    local mx, my = Viewport.getMousePosition()
    local tooltipX = mx + 10
    local tooltipY = my - 10

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

    local sw, sh = Viewport.getDimensions()
    if tooltipX + tooltipW > sw then
        tooltipX = mx - tooltipW - 10
    end
    if tooltipY + tooltipH > sh then
        tooltipY = my - tooltipH - 10
    end

    Theme.setColor(Theme.colors.bg0)
    love.graphics.rectangle("fill", tooltipX, tooltipY, tooltipW, tooltipH)
    Theme.setColor(Theme.colors.border)
    love.graphics.rectangle("line", tooltipX, tooltipY, tooltipW, tooltipH)

    Theme.setColor(Theme.colors.text)
    for i, line in ipairs(lines) do
        local y = tooltipY + padding + (i - 1) * lineHeight
        love.graphics.print(line, tooltipX + padding, y)
    end
end

local function drawBottomBar(state, x, y, w, h, selectedOre)
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
    local focused = state.inputActive
    state.inputRect = UIUtils.drawTextInput(inputX, inputY, inputWidth, inputHeight,
        selectedOre and state.amountText or "", focused, placeholder)

    local buttonWidth = 160
    local buttonHeight = 40
    local buttonX = x + w - buttonWidth - pad
    local buttonY = y + h - buttonHeight - pad
    local amount = tonumber(state.amountText) or 0
    local hasOre = selectedOre and (selectedOre.quantity or 0) > 0
    local canSmelt = hasOre and amount > 0 and amount <= (selectedOre.quantity or 0)
    state.canSmelt = canSmelt
    local mx, my = Viewport.getMousePosition()
    local hover = canSmelt and mx >= buttonX and mx <= buttonX + buttonWidth and my >= buttonY and my <= buttonY + buttonHeight
    local options = {
        textColor = canSmelt and Theme.colors.text or Theme.colors.textDisabled,
        bg = canSmelt and Theme.colors.bg2 or Theme.colors.bg1,
        hoverBg = Theme.colors.bg3,
        border = Theme.colors.border,
    }
    state.smeltButtonRect = UIUtils.drawButton(buttonX, buttonY, buttonWidth, buttonHeight,
        "Smelt", hover, false, options)

    return inputY + inputHeight
end

function FurnacePanel.draw(state, player, x, y, w, h)
    local pad = (Theme.ui and Theme.ui.contentPadding) or 12
    local bottomBarHeight = 110
    local gridY = y + pad
    local gridHeight = h - bottomBarHeight - pad

    state.hoveredRecipe = nil
    state.hoverRect = nil

    local recipes = collectRecipes(player)
    state.slots = {}
    ensureSelection(state, recipes)

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
                drawSlot(state, recipe, rect, state.selectedOreId == recipe.id)
                table.insert(state.slots, { rect = rect, ore = recipe })
            end
        end
    end

    drawBottomBar(state, x + pad, y + h - bottomBarHeight, w - pad * 2, bottomBarHeight - pad, state.selectedOre)

    drawTooltip(state)
end

local function pointInRect(rect, x, y)
    return rect and UIUtils.pointInRect(x, y, rect)
end

local function setInputActive(state, active)
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

local function executeSmelt(state, player)
    local ore = state.selectedOre
    if not ore then
        Notifications.info("Select an ore to smelt first")
        return
    end
    local amount = clampAmountText(state, ore.quantity)
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

    local recipe = recipes[1]
    if not recipe then
        Notifications.info("No valid recipe found")
        return
    end

    local maxSmeltable = math.floor(amount / recipe.ratio)
    if maxSmeltable <= 0 then
        Notifications.info(string.format("Need at least %d %s to smelt", recipe.ratio, ore.name or itemId))
        return
    end

    local inputAmount = maxSmeltable * recipe.ratio
    local outputAmount = maxSmeltable

    if not player or not player.removeItem or not player.addGC then
        return
    end

    if not player:removeItem(itemId, inputAmount) then
        Notifications.info("Failed to remove materials from cargo")
        return
    end

    if recipe.type == "credits" then
        player:addGC(outputAmount)
        Notifications.action(string.format("Smelted %d %s into %d credits", inputAmount, ore.name or itemId, outputAmount))
    elseif recipe.type == "item" then
        if player.addItem then
            player:addItem(recipe.output, outputAmount)
            Notifications.action(string.format("Smelted %d %s into %d %s", inputAmount, ore.name or itemId, outputAmount, recipe.output))
        end
    end

    state.inputActive = false
    if love and love.keyboard and love.keyboard.setTextInput then
        love.keyboard.setTextInput(false)
    end

    local updatedRecipes = collectRecipes(player)
    ensureSelection(state, updatedRecipes)
end

local function handleSlotClick(state, x, y)
    for _, slot in ipairs(state.slots or {}) do
        if pointInRect(slot.rect, x, y) then
            state.selectedOreId = slot.ore.id
            state.selectedOre = slot.ore
            clampAmountText(state, slot.ore.quantity)
            return true
        end
    end
    return false
end

function FurnacePanel.mousepressed(state, player, x, y, button)
    if button ~= 1 then
        setInputActive(state, false)
        return false, false
    end

    if handleSlotClick(state, x, y) then
        setInputActive(state, false)
        return true, false
    end

    if pointInRect(state.inputRect, x, y) and state.selectedOre then
        setInputActive(state, true)
        return true, false
    end

    setInputActive(state, false)

    if state.canSmelt and pointInRect(state.smeltButtonRect, x, y) then
        executeSmelt(state, player)
        return true, false
    end

    return false, false
end

function FurnacePanel.keypressed(state, key, player)
    if key == "escape" then
        setInputActive(state, false)
        return true, true
    end

    if state.inputActive and key == "backspace" then
        local text = state.amountText or ""
        state.amountText = text:sub(1, -2)
        return true, false
    end

    if key == "return" or key == "kpenter" then
        if state.canSmelt then
            executeSmelt(state, player)
        elseif state.selectedOre then
            clampAmountText(state, state.selectedOre.quantity)
        end
        return true, false
    end

    return true, false
end

function FurnacePanel.textinput(state, text)
    if not state.inputActive or not state.selectedOre then
        return false
    end

    local digits = text:gsub("%D", "")
    if digits ~= "" then
        local base = state.amountText or ""
        if base == "0" then base = "" end
        local combined = base .. digits
        if #combined > 6 then
            combined = combined:sub(1, 6)
        end
        state.amountText = combined
        return true
    end

    return false
end

return FurnacePanel
