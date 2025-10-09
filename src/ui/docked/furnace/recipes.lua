--[[
    Furnace Recipes
    
    Manages furnace recipes and recipe-related logic including:
    - Recipe definitions
    - Recipe validation
    - Output calculations
]]

local Content = require("src.content.content")

local FurnaceRecipes = {}

-- Recipe definitions
local RECIPES = {
    ["ore_tritanium"] = {
        { output = "credits", ratio = 50, type = "credits" } -- 1 tritanium = 50 credits
    },
    ["ore_palladium"] = {
        { output = "credits", ratio = 100, type = "credits" } -- 1 palladium = 100 credits
    }
}

function FurnaceRecipes.init()
    -- Initialize recipes if needed
    -- Could load from content files or configuration
end

function FurnaceRecipes.getRecipes()
    return RECIPES
end

function FurnaceRecipes.getRecipe(oreId)
    return RECIPES[oreId]
end

function FurnaceRecipes.hasRecipe(oreId)
    return RECIPES[oreId] ~= nil
end

function FurnaceRecipes.getAvailableRecipes(player)
    local recipes = {}
    local playerQuantities = {}
    
    if not player or not player.components or not player.components.cargo then
        return recipes, playerQuantities
    end
    
    local cargo = player.components.cargo
    
    -- Get all items that have recipes
    for oreId, recipe in pairs(RECIPES) do
        local item = Content.getItem(oreId)
        if item then
            local quantity = cargo:getItemCount(oreId)
            if quantity > 0 then
                table.insert(recipes, {
                    oreId = oreId,
                    item = item,
                    recipe = recipe,
                    quantity = quantity
                })
                playerQuantities[oreId] = quantity
            end
        end
    end
    
    return recipes, playerQuantities
end

function FurnaceRecipes.calculateOutput(oreId, amount)
    local recipe = RECIPES[oreId]
    if not recipe or not recipe[1] then
        return nil
    end
    
    local output = recipe[1]
    local outputAmount = amount * output.ratio
    
    return {
        type = output.type,
        amount = outputAmount,
        ratio = output.ratio
    }
end

function FurnaceRecipes.validateRecipe(oreId, amount, player)
    if not RECIPES[oreId] then
        return false, "No recipe for this ore"
    end
    
    if not amount or amount <= 0 then
        return false, "Invalid amount"
    end
    
    if not player or not player.components or not player.components.cargo then
        return false, "No cargo system"
    end
    
    local cargo = player.components.cargo
    local available = cargo:getItemCount(oreId)
    
    if available < amount then
        return false, "Insufficient ore"
    end
    
    return true, nil
end

function FurnaceRecipes.getRecipeInfo(oreId)
    local recipe = RECIPES[oreId]
    if not recipe or not recipe[1] then
        return nil
    end
    
    local output = recipe[1]
    local item = Content.getItem(oreId)
    
    return {
        oreId = oreId,
        oreName = item and item.name or oreId,
        outputType = output.type,
        outputAmount = output.ratio,
        ratio = output.ratio
    }
end

function FurnaceRecipes.formatRecipeDescription(oreId)
    local info = FurnaceRecipes.getRecipeInfo(oreId)
    if not info then
        return "No recipe available"
    end
    
    if info.outputType == "credits" then
        return string.format("1 %s = %d credits", info.oreName, info.ratio)
    else
        return string.format("1 %s = %d %s", info.oreName, info.ratio, info.outputType)
    end
end

return FurnaceRecipes
