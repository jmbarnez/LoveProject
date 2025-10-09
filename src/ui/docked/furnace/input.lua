--[[
    Furnace Input Handler
    
    Handles all input events for the furnace interface including:
    - Recipe selection
    - Amount input
    - Smelt button clicks
    - Text input
]]

local FurnaceRecipes = require("src.ui.docked.furnace.recipes")

local FurnaceInput = {}

function FurnaceInput.mousepressed(self, x, y, button)
    if button ~= 1 then return false end
    
    local state = self.state
    if not state then return false end
    
    -- Check amount input click
    local inputRect = state:getInputRect()
    if inputRect and x >= inputRect.x and x < inputRect.x + inputRect.w and
       y >= inputRect.y and y < inputRect.y + inputRect.h then
        state:setInputActive(true)
        if love and love.keyboard and love.keyboard.setTextInput then
            love.keyboard.setTextInput(true)
        end
        return true
    end
    
    -- Check smelt button click
    local smeltRect = state:getSmeltButtonRect()
    if smeltRect and x >= smeltRect.x and x < smeltRect.x + smeltRect.w and
       y >= smeltRect.y and y < smeltRect.y + smeltRect.h then
        if state:canSmelt() and not state:isSmelting() then
            FurnaceInput.executeSmelt(self)
            return true
        end
    end
    
    -- Check recipe slot clicks
    local hoverRect = state:getHoverRect()
    if hoverRect and x >= hoverRect.x and x < hoverRect.x + hoverRect.w and
       y >= hoverRect.y and y < hoverRect.y + hoverRect.h then
        local hoveredRecipe = state:getHoveredRecipe()
        if hoveredRecipe then
            state:setSelectedOre(hoveredRecipe.oreId, hoveredRecipe.item)
            return true
        end
    end
    
    return false
end

function FurnaceInput.mousereleased(self, x, y, button)
    return false
end

function FurnaceInput.mousemoved(self, x, y, dx, dy)
    local state = self.state
    if not state then return false end
    
    -- Check recipe hover
    local recipes, playerQuantities = FurnaceRecipes.getAvailableRecipes(state:getPlayer())
    local hoveredRecipe = nil
    
    for _, recipe in ipairs(recipes) do
        -- This is a simplified hover detection
        -- In a real implementation, you'd need to calculate the actual grid positions
        local hoverRect = state:getHoverRect()
        if hoverRect and x >= hoverRect.x and x < hoverRect.x + hoverRect.w and
           y >= hoverRect.y and y < hoverRect.y + hoverRect.h then
            hoveredRecipe = recipe
            break
        end
    end
    
    state:setHoveredRecipe(hoveredRecipe)
    
    return false
end

function FurnaceInput.keypressed(self, key)
    local state = self.state
    if not state or not state:isInputActive() then return false end
    
    -- Handle backspace
    if key == "backspace" then
        local amountText = state:getAmountText()
        if #amountText > 0 then
            state:setAmountText(amountText:sub(1, -2))
        end
        return true
    end
    
    -- Handle enter
    if key == "return" or key == "kpenter" then
        state:setInputActive(false)
        if love and love.keyboard and love.keyboard.setTextInput then
            love.keyboard.setTextInput(false)
        end
        return true
    end
    
    -- Handle escape
    if key == "escape" then
        state:setInputActive(false)
        if love and love.keyboard and love.keyboard.setTextInput then
            love.keyboard.setTextInput(false)
        end
        return true
    end
    
    return false
end

function FurnaceInput.textinput(self, text)
    local state = self.state
    if not state or not state:isInputActive() then return false end
    
    -- Only allow numbers and decimal point
    if text:match("[%d%.]") then
        local currentText = state:getAmountText()
        local newText = currentText .. text
        
        -- Validate the new text
        local num = tonumber(newText)
        if num and num > 0 and num <= 999999 then
            state:setAmountText(newText)
        end
    end
    
    return true
end

function FurnaceInput.executeSmelt(self)
    local state = self.state
    if not state then return false end
    
    local amount = tonumber(state:getAmountText())
    if not amount or amount <= 0 then
        state:setInfoText("Invalid amount")
        return false
    end
    
    local oreId, ore = state:getSelectedOre()
    if not oreId or not ore then
        state:setInfoText("No ore selected")
        return false
    end
    
    -- Validate recipe
    local valid, error = FurnaceRecipes.validateRecipe(oreId, amount, state:getPlayer())
    if not valid then
        state:setInfoText(error or "Cannot smelt")
        return false
    end
    
    -- Start smelting
    state:setSmelting(true)
    state:setInfoText("Smelting...")
    
    return true
end

function FurnaceInput.clampAmountText(maxAmount)
    local state = self.state
    if not state then return end
    
    local amount = tonumber(state:getAmountText())
    if amount and amount > maxAmount then
        state:setAmountText(tostring(maxAmount))
    end
end

function FurnaceInput.ensureFurnaceSelection(recipes)
    local state = self.state
    if not state then return end
    
    if not state:getSelectedOre() and #recipes > 0 then
        local firstRecipe = recipes[1]
        state:setSelectedOre(firstRecipe.oreId, firstRecipe.item)
    end
end

return FurnaceInput
