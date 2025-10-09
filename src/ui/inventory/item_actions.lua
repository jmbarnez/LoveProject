--[[
    Inventory Item Actions
    
    Handles item action execution including:
    - Use item actions
    - Equip item actions
    - Drop item actions
    - Item validation
    - Action feedback
]]

local Content = require("src.content.content")
local Notifications = require("src.ui.notifications")

local ItemActions = {}

function ItemActions.useItem(item, player)
    if not item or not player then
        return false, "Invalid item or player"
    end
    
    if not player.components or not player.components.cargo then
        return false, "No cargo system"
    end
    
    local cargo = player.components.cargo
    
    -- Check if item is usable
    if not ItemActions.isUsable(item) then
        return false, "Item is not usable"
    end
    
    -- Check if player has the item
    if not cargo:hasItem(item.id) then
        return false, "Item not in inventory"
    end
    
    -- Use the item
    if cargo:useItem(item.id) then
        Notifications.add("Used " .. (item.name or item.id), "success")
        return true
    else
        return false, "Failed to use item"
    end
end

function ItemActions.equipItem(item, player)
    if not item or not player then
        return false, "Invalid item or player"
    end
    
    if not player.components or not player.components.equipment then
        return false, "No equipment system"
    end
    
    local equipment = player.components.equipment
    
    -- Check if item is equippable
    if not ItemActions.isEquippable(item) then
        return false, "Item is not equippable"
    end
    
    -- Check if player has the item
    if not player.components.cargo or not player.components.cargo:hasItem(item.id) then
        return false, "Item not in inventory"
    end
    
    -- Try to equip the item
    if equipment:equipItem(item) then
        Notifications.add("Equipped " .. (item.name or item.id), "success")
        return true
    else
        return false, "No available equipment slots"
    end
end

function ItemActions.dropItem(item, player, quantity)
    if not item or not player then
        return false, "Invalid item or player"
    end
    
    if not player.components or not player.components.cargo then
        return false, "No cargo system"
    end
    
    local cargo = player.components.cargo
    quantity = quantity or item.quantity or 1
    
    -- Check if player has enough of the item
    if not cargo:hasItem(item.id, quantity) then
        return false, "Not enough items to drop"
    end
    
    -- Drop the item
    if cargo:dropItem(item.id, quantity) then
        Notifications.add("Dropped " .. (item.name or item.id) .. " x" .. quantity, "success")
        return true
    else
        return false, "Failed to drop item"
    end
end

function ItemActions.sellItem(item, player, quantity)
    if not item or not player then
        return false, "Invalid item or player"
    end
    
    if not player.components or not player.components.cargo then
        return false, "No cargo system"
    end
    
    local cargo = player.components.cargo
    quantity = quantity or item.quantity or 1
    
    -- Check if player has enough of the item
    if not cargo:hasItem(item.id, quantity) then
        return false, "Not enough items to sell"
    end
    
    -- Calculate sell value
    local sellValue = ItemActions.getSellValue(item, quantity)
    if sellValue <= 0 then
        return false, "Item has no sell value"
    end
    
    -- Remove item from cargo
    if cargo:removeItem(item.id, quantity) then
        -- Add credits
        local PortfolioManager = require("src.managers.portfolio")
        PortfolioManager.addCredits(sellValue)
        
        Notifications.add("Sold " .. (item.name or item.id) .. " x" .. quantity .. " for " .. sellValue .. " credits", "success")
        return true
    else
        return false, "Failed to sell item"
    end
end

function ItemActions.isUsable(item)
    if not item then return false end
    
    -- Check if item has a use action
    if item.type == "consumable" or item.type == "utility" then
        return true
    end
    
    -- Check if item has a use function
    if item.use and type(item.use) == "function" then
        return true
    end
    
    return false
end

function ItemActions.isEquippable(item)
    if not item then return false end
    
    -- Check if item is an equipment type
    if item.type == "turret" or item.type == "shield" or item.type == "utility" then
        return true
    end
    
    -- Check if item has equipment properties
    if item.equipment and item.equipment.slot then
        return true
    end
    
    return false
end

function ItemActions.getSellValue(item, quantity)
    if not item then return 0 end
    
    quantity = quantity or 1
    local baseValue = item.value or 0
    
    -- Apply sell multiplier (typically 50% of base value)
    local sellMultiplier = 0.5
    return math.floor(baseValue * sellMultiplier * quantity)
end

function ItemActions.getBuyValue(item, quantity)
    if not item then return 0 end
    
    quantity = quantity or 1
    local baseValue = item.value or 0
    
    -- Apply buy multiplier (typically 100% of base value)
    local buyMultiplier = 1.0
    return math.floor(baseValue * buyMultiplier * quantity)
end

function ItemActions.canAfford(item, player, quantity)
    if not item or not player then return false end
    
    local buyValue = ItemActions.getBuyValue(item, quantity)
    if buyValue <= 0 then return false end
    
    local PortfolioManager = require("src.managers.portfolio")
    local portfolio = PortfolioManager.getPortfolio()
    
    return portfolio.credits >= buyValue
end

function ItemActions.getActionOptions(item, player)
    local options = {}
    
    if not item or not player then return options end
    
    -- Use option
    if ItemActions.isUsable(item) then
        table.insert(options, {text = "Use", action = "use", enabled = true})
    end
    
    -- Equip option
    if ItemActions.isEquippable(item) then
        table.insert(options, {text = "Equip", action = "equip", enabled = true})
    end
    
    -- Drop option
    table.insert(options, {text = "Drop", action = "drop", enabled = true})
    
    -- Sell option (if in shop context)
    if ItemActions.getSellValue(item) > 0 then
        table.insert(options, {text = "Sell", action = "sell", enabled = true})
    end
    
    -- Info option
    table.insert(options, {text = "Info", action = "info", enabled = true})
    
    return options
end

function ItemActions.executeAction(action, item, player, quantity)
    if action == "use" then
        return ItemActions.useItem(item, player)
    elseif action == "equip" then
        return ItemActions.equipItem(item, player)
    elseif action == "drop" then
        return ItemActions.dropItem(item, player, quantity)
    elseif action == "sell" then
        return ItemActions.sellItem(item, player, quantity)
    elseif action == "info" then
        return ItemActions.showItemInfo(item, player)
    else
        return false, "Unknown action"
    end
end

function ItemActions.showItemInfo(item, player)
    if not item then return false end
    
    -- This would typically show detailed item information
    -- For now, just show a notification
    local infoText = string.format("%s: %s", item.name or item.id, item.description or "No description")
    Notifications.add(infoText, "info")
    
    return true
end

function ItemActions.validateItem(item)
    if not item then return false, "No item" end
    if not item.id then return false, "No item ID" end
    
    return true
end

function ItemActions.getItemDescription(item)
    if not item then return "No item" end
    
    local description = item.description or "No description available"
    
    if item.value then
        description = description .. "\nValue: " .. item.value .. " credits"
    end
    
    if item.rarity then
        description = description .. "\nRarity: " .. item.rarity
    end
    
    if item.type then
        description = description .. "\nType: " .. item.type
    end
    
    return description
end

return ItemActions
