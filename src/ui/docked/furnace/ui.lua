--[[
    Furnace UI
    
    Handles rendering of the furnace interface including:
    - Recipe selection grid
    - Amount input
    - Smelt button
    - Progress display
]]

local Theme = require("src.core.theme")
local Content = require("src.content.content")
local FurnaceRecipes = require("src.ui.docked.furnace.recipes")

local FurnaceUI = {}

function FurnaceUI.draw(self, window, x, y, w, h)
    local state = self.state
    if not state then return end
    
    -- Furnace background
    Theme.setColor(Theme.colors.bg1)
    love.graphics.rectangle("fill", x, y, w, h)
    
    -- Furnace border
    Theme.setColor(Theme.colors.border)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h)
    
    -- Title
    Theme.setColor(Theme.colors.text)
    Theme.setFont("medium")
    love.graphics.print("Ore Furnace", x + 12, y + 12)
    
    -- Get available recipes
    local recipes, playerQuantities = FurnaceRecipes.getAvailableRecipes(state:getPlayer())
    
    if #recipes == 0 then
        FurnaceUI.drawNoOreMessage(x + 12, y + 40, w - 24, h - 52)
        return
    end
    
    -- Draw recipe grid
    local gridX = x + 12
    local gridY = y + 40
    local gridW = w - 24
    local gridH = h - 120
    
    FurnaceUI.drawRecipeGrid(self, recipes, playerQuantities, gridX, gridY, gridW, gridH)
    
    -- Draw amount input and smelt button
    local inputY = y + h - 70
    local inputW = 120
    local inputH = 28
    local buttonW = 100
    local buttonH = 32
    local buttonX = x + w - buttonW - 12
    local buttonY = inputY - 2
    
    FurnaceUI.drawAmountInput(self, gridX, inputY, inputW, inputH)
    FurnaceUI.drawSmeltButton(self, buttonX, buttonY, buttonW, buttonH)
    
    -- Draw info text
    if state:getInfoText() then
        Theme.setColor(Theme.colors.textSecondary)
        Theme.setFont("small")
        love.graphics.print(state:getInfoText(), gridX, inputY + inputH + 8)
    end
end

function FurnaceUI.drawNoOreMessage(x, y, w, h)
    Theme.setColor(Theme.colors.textSecondary)
    Theme.setFont("medium")
    local text = "No ore available for smelting"
    local textW = Theme.fonts.medium:getWidth(text)
    local textH = Theme.fonts.medium:getHeight()
    local textX = x + (w - textW) * 0.5
    local textY = y + (h - textH) * 0.5
    love.graphics.print(text, textX, textY)
end

function FurnaceUI.drawRecipeGrid(self, recipes, playerQuantities, x, y, w, h)
    local state = self.state
    local cols = 3
    local rows = math.ceil(#recipes / cols)
    local slotW = (w - (cols - 1) * 8) / cols
    local slotH = (h - (rows - 1) * 8) / rows
    
    for i, recipe in ipairs(recipes) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local slotX = x + col * (slotW + 8)
        local slotY = y + row * (slotH + 8)
        
        local isSelected = state:getSelectedOre() == recipe.oreId
        local isHovered = state:getHoveredRecipe() == recipe
        
        FurnaceUI.drawRecipeSlot(self, recipe, slotX, slotY, slotW, slotH, isSelected, isHovered)
    end
end

function FurnaceUI.drawRecipeSlot(self, recipe, x, y, w, h, selected, hovered)
    local state = self.state
    
    -- Background
    local bgColor = selected and Theme.colors.accent or (hovered and Theme.colors.bg3 or Theme.colors.bg2)
    Theme.setColor(bgColor)
    love.graphics.rectangle("fill", x, y, w, h)
    
    -- Border
    local borderColor = selected and Theme.colors.borderBright or Theme.colors.border
    Theme.setColor(borderColor)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h)
    
    -- Item icon
    local iconSize = 32
    local iconX = x + (w - iconSize) * 0.5
    local iconY = y + 8
    
    if recipe.item and recipe.item.icon then
        local IconSystem = require("src.core.icon_system")
        IconSystem.drawIcon(recipe.item.icon, iconX, iconY, iconSize)
    else
        -- Fallback icon
        Theme.setColor(Theme.colors.textSecondary)
        love.graphics.rectangle("fill", iconX, iconY, iconSize, iconSize)
    end
    
    -- Item name
    Theme.setColor(Theme.colors.text)
    Theme.setFont("small")
    local name = recipe.item and recipe.item.name or recipe.oreId
    local nameW = Theme.fonts.small:getWidth(name)
    local nameX = x + (w - nameW) * 0.5
    local nameY = iconY + iconSize + 4
    love.graphics.print(name, nameX, nameY)
    
    -- Quantity
    Theme.setColor(Theme.colors.textSecondary)
    local quantityText = string.format("x%d", recipe.quantity)
    local quantityW = Theme.fonts.small:getWidth(quantityText)
    local quantityX = x + (w - quantityW) * 0.5
    local quantityY = nameY + 14
    love.graphics.print(quantityText, quantityX, quantityY)
    
    -- Recipe info
    local recipeInfo = FurnaceRecipes.formatRecipeDescription(recipe.oreId)
    local infoW = Theme.fonts.small:getWidth(recipeInfo)
    local infoX = x + (w - infoW) * 0.5
    local infoY = quantityY + 14
    love.graphics.print(recipeInfo, infoX, infoY)
    
    -- Store rect for hover detection
    state:setHoverRect({x = x, y = y, w = w, h = h})
end

function FurnaceUI.drawAmountInput(self, x, y, w, h)
    local state = self.state
    
    -- Label
    Theme.setColor(Theme.colors.textSecondary)
    Theme.setFont("small")
    love.graphics.print("Amount:", x, y - 16)
    
    -- Input background
    local bgColor = state:isInputActive() and Theme.colors.bg3 or Theme.colors.bg2
    Theme.setColor(bgColor)
    love.graphics.rectangle("fill", x, y, w, h)
    
    -- Input border
    local borderColor = state:isInputActive() and Theme.colors.borderBright or Theme.colors.border
    Theme.setColor(borderColor)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h)
    
    -- Input text
    Theme.setColor(Theme.colors.text)
    Theme.setFont("medium")
    local text = state:getAmountText()
    local textX = x + 8
    local textY = y + (h - Theme.fonts.medium:getHeight()) * 0.5
    love.graphics.print(text, textX, textY)
    
    -- Cursor (if active)
    if state:isInputActive() then
        local cursorX = textX + Theme.fonts.medium:getWidth(text)
        local cursorY = textY
        local cursorH = Theme.fonts.medium:getHeight()
        Theme.setColor(Theme.colors.text)
        love.graphics.rectangle("fill", cursorX, cursorY, 1, cursorH)
    end
    
    -- Store rect for click detection
    state:setInputRect({x = x, y = y, w = w, h = h})
end

function FurnaceUI.drawSmeltButton(self, x, y, w, h)
    local state = self.state
    local canSmelt = state:canSmelt() and not state:isSmelting()
    local isSmelting = state:isSmelting()
    
    -- Button background
    local bgColor = canSmelt and Theme.colors.accent or Theme.colors.bg3
    Theme.setColor(bgColor)
    love.graphics.rectangle("fill", x, y, w, h)
    
    -- Button border
    Theme.setColor(Theme.colors.border)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h)
    
    -- Button text
    local text = isSmelting and "Smelting..." or "Smelt"
    local textColor = canSmelt and Theme.colors.textHighlight or Theme.colors.textDisabled
    Theme.setColor(textColor)
    Theme.setFont("medium")
    local textW = Theme.fonts.medium:getWidth(text)
    local textH = Theme.fonts.medium:getHeight()
    local textX = x + (w - textW) * 0.5
    local textY = y + (h - textH) * 0.5
    love.graphics.print(text, textX, textY)
    
    -- Progress bar (if smelting)
    if isSmelting then
        local progress = state:getSmeltProgress()
        local barW = w - 8
        local barH = 4
        local barX = x + 4
        local barY = y + h - 8
        
        -- Background
        Theme.setColor(Theme.colors.bg2)
        love.graphics.rectangle("fill", barX, barY, barW, barH)
        
        -- Progress
        Theme.setColor(Theme.colors.accent)
        love.graphics.rectangle("fill", barX, barY, barW * progress, barH)
    end
    
    -- Store rect for click detection
    state:setSmeltButtonRect({x = x, y = y, w = w, h = h})
end

return FurnaceUI
