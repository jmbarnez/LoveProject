--[[
    Furnace State Management
    
    Manages state specific to the furnace functionality including:
    - Recipe selection
    - Input amounts
    - Smelting progress
    - UI interaction states
]]

local FurnaceState = {}

function FurnaceState.new()
    local state = {
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
        smelting = false,
        smeltProgress = 0,
        smeltDuration = 2.0 -- seconds
    }
    
    return state
end

function FurnaceState:update(dt)
    -- Update smelting progress
    if self.smelting then
        self.smeltProgress = self.smeltProgress + dt
        if self.smeltProgress >= self.smeltDuration then
            self:completeSmelting()
        end
    end
end

function FurnaceState:setSelectedOre(oreId, ore)
    self.selectedOreId = oreId
    self.selectedOre = ore
    self:updateCanSmelt()
end

function FurnaceState:getSelectedOre()
    return self.selectedOreId, self.selectedOre
end

function FurnaceState:setAmountText(text)
    self.amountText = text or "1"
    self:updateCanSmelt()
end

function FurnaceState:getAmountText()
    return self.amountText
end

function FurnaceState:setInputActive(active)
    self.inputActive = active
end

function FurnaceState:isInputActive()
    return self.inputActive
end

function FurnaceState:setInputRect(rect)
    self.inputRect = rect
end

function FurnaceState:getInputRect()
    return self.inputRect
end

function FurnaceState:setSmeltButtonRect(rect)
    self.smeltButtonRect = rect
end

function FurnaceState:getSmeltButtonRect()
    return self.smeltButtonRect
end

function FurnaceState:setInfoText(text)
    self.infoText = text
end

function FurnaceState:getInfoText()
    return self.infoText
end

function FurnaceState:setHoveredRecipe(recipe)
    self.hoveredRecipe = recipe
end

function FurnaceState:getHoveredRecipe()
    return self.hoveredRecipe
end

function FurnaceState:setHoverRect(rect)
    self.hoverRect = rect
end

function FurnaceState:getHoverRect()
    return self.hoverRect
end

function FurnaceState:setCanSmelt(canSmelt)
    self.canSmelt = canSmelt
end

function FurnaceState:canSmelt()
    return self.canSmelt
end

function FurnaceState:setSmelting(smelting)
    self.smelting = smelting
    if smelting then
        self.smeltProgress = 0
    end
end

function FurnaceState:isSmelting()
    return self.smelting
end

function FurnaceState:getSmeltProgress()
    return self.smeltProgress / self.smeltDuration
end

function FurnaceState:updateCanSmelt()
    local amount = tonumber(self.amountText)
    if not amount or amount <= 0 then
        self.canSmelt = false
        return
    end
    
    if not self.selectedOre then
        self.canSmelt = false
        return
    end
    
    -- Check if player has enough ore
    local player = self.player
    if not player or not player.components or not player.components.cargo then
        self.canSmelt = false
        return
    end
    
    local cargo = player.components.cargo
    local oreCount = cargo:getItemCount(self.selectedOreId)
    
    self.canSmelt = oreCount >= amount
end

function FurnaceState:completeSmelting()
    if not self.smelting then return end
    
    local amount = tonumber(self.amountText)
    if not amount or amount <= 0 then
        self:reset()
        return
    end
    
    if not self.selectedOre or not self.selectedOreId then
        self:reset()
        return
    end
    
    local player = self.player
    if not player or not player.components or not player.components.cargo then
        self:reset()
        return
    end
    
    -- Remove ore from cargo
    local cargo = player.components.cargo
    local removed = cargo:removeItem(self.selectedOreId, amount)
    
    if removed > 0 then
        -- Add credits based on recipe
        local FurnaceRecipes = require("src.ui.docked.furnace.recipes")
        local recipes = FurnaceRecipes.getRecipes()
        local recipe = recipes[self.selectedOreId]
        
        if recipe and recipe[1] then
            local output = recipe[1]
            if output.type == "credits" then
                local credits = removed * output.ratio
                local PortfolioManager = require("src.managers.portfolio")
                PortfolioManager.addCredits(credits)
                
                -- Show notification
                local Notifications = require("src.ui.notifications")
                Notifications.add(string.format("Smelted %d %s for %d credits", removed, self.selectedOre.name or self.selectedOreId, credits), "success")
            end
        end
    end
    
    self:reset()
end

function FurnaceState:reset()
    self.slots = {}
    self.selectedOreId = nil
    self.selectedOre = nil
    self.amountText = "1"
    self.inputActive = false
    self.inputRect = nil
    self.smeltButtonRect = nil
    self.infoText = nil
    self.hoveredRecipe = nil
    self.hoverRect = nil
    self.canSmelt = false
    self.smelting = false
    self.smeltProgress = 0
    
    -- Disable text input
    if love and love.keyboard and love.keyboard.setTextInput then
        love.keyboard.setTextInput(false)
    end
end

function FurnaceState:setPlayer(player)
    self.player = player
end

function FurnaceState:getPlayer()
    return self.player
end

return FurnaceState
