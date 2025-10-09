--[[
    Inventory Filters
    
    Handles filtering and sorting logic for the inventory including:
    - Search filtering
    - Sort by different criteria
    - Filter by item type
    - Sort order management
]]

local Content = require("src.content.content")

local InventoryFilters = {}

function InventoryFilters.filterAndSortItems(items, searchText, sortBy, sortOrder)
    if not items then return {} end
    
    -- Apply search filter
    local filteredItems = {}
    if searchText and searchText ~= "" then
        local searchLower = searchText:lower()
        for _, item in ipairs(items) do
            if InventoryFilters.matchesSearch(item, searchLower) then
                table.insert(filteredItems, item)
            end
        end
    else
        filteredItems = items
    end
    
    -- Apply sorting
    table.sort(filteredItems, function(a, b)
        return InventoryFilters.compareItems(a, b, sortBy, sortOrder)
    end)
    
    return filteredItems
end

function InventoryFilters.matchesSearch(item, searchLower)
    if not item then return false end
    
    -- Search in item name
    if item.name and item.name:lower():find(searchLower, 1, true) then
        return true
    end
    
    -- Search in item id
    if item.id and item.id:lower():find(searchLower, 1, true) then
        return true
    end
    
    -- Search in item type
    if item.type and item.type:lower():find(searchLower, 1, true) then
        return true
    end
    
    -- Search in item description
    if item.description and item.description:lower():find(searchLower, 1, true) then
        return true
    end
    
    return false
end

function InventoryFilters.compareItems(a, b, sortBy, sortOrder)
    if not a or not b then return false end
    
    local aValue = InventoryFilters.getItemValue(a, sortBy)
    local bValue = InventoryFilters.getItemValue(b, sortBy)
    
    local result = false
    
    if type(aValue) == "string" and type(bValue) == "string" then
        result = aValue:lower() < bValue:lower()
    elseif type(aValue) == "number" and type(bValue) == "number" then
        result = aValue < bValue
    else
        result = tostring(aValue) < tostring(bValue)
    end
    
    if sortOrder == "desc" then
        result = not result
    end
    
    return result
end

function InventoryFilters.getItemValue(item, sortBy)
    if not item then return "" end
    
    if sortBy == "name" then
        return item.name or item.id or ""
    elseif sortBy == "type" then
        return item.type or ""
    elseif sortBy == "rarity" then
        return item.rarity or "Common"
    elseif sortBy == "value" then
        return item.value or 0
    elseif sortBy == "quantity" then
        return item.quantity or 1
    else
        return item.name or item.id or ""
    end
end

function InventoryFilters.getSortOptions()
    return {
        {value = "name", label = "Name"},
        {value = "type", label = "Type"},
        {value = "rarity", label = "Rarity"},
        {value = "value", label = "Value"},
        {value = "quantity", label = "Quantity"}
    }
end

function InventoryFilters.getSortOrderOptions()
    return {
        {value = "asc", label = "Ascending"},
        {value = "desc", label = "Descending"}
    }
end

function InventoryFilters.getRarityValue(rarity)
    local rarityValues = {
        Common = 1,
        Uncommon = 2,
        Rare = 3,
        Epic = 4,
        Legendary = 5
    }
    return rarityValues[rarity] or 0
end

function InventoryFilters.sortByRarity(a, b)
    local aRarity = InventoryFilters.getRarityValue(a.rarity)
    local bRarity = InventoryFilters.getRarityValue(b.rarity)
    return aRarity < bRarity
end

function InventoryFilters.getFilteredItemCount(items, searchText)
    if not items then return 0 end
    
    if not searchText or searchText == "" then
        return #items
    end
    
    local count = 0
    local searchLower = searchText:lower()
    for _, item in ipairs(items) do
        if InventoryFilters.matchesSearch(item, searchLower) then
            count = count + 1
        end
    end
    
    return count
end

function InventoryFilters.getItemsByType(items, itemType)
    if not items then return {} end
    
    local filtered = {}
    for _, item in ipairs(items) do
        if item.type == itemType then
            table.insert(filtered, item)
        end
    end
    
    return filtered
end

function InventoryFilters.getItemsByRarity(items, rarity)
    if not items then return {} end
    
    local filtered = {}
    for _, item in ipairs(items) do
        if item.rarity == rarity then
            table.insert(filtered, item)
        end
    end
    
    return filtered
end

function InventoryFilters.getItemsInValueRange(items, minValue, maxValue)
    if not items then return {} end
    
    local filtered = {}
    for _, item in ipairs(items) do
        local value = item.value or 0
        if value >= minValue and value <= maxValue then
            table.insert(filtered, item)
        end
    end
    
    return filtered
end

function InventoryFilters.getUniqueItemTypes(items)
    if not items then return {} end
    
    local types = {}
    local seen = {}
    
    for _, item in ipairs(items) do
        if item.type and not seen[item.type] then
            table.insert(types, item.type)
            seen[item.type] = true
        end
    end
    
    table.sort(types)
    return types
end

function InventoryFilters.getUniqueRarities(items)
    if not items then return {} end
    
    local rarities = {}
    local seen = {}
    
    for _, item in ipairs(items) do
        if item.rarity and not seen[item.rarity] then
            table.insert(rarities, item.rarity)
            seen[item.rarity] = true
        end
    end
    
    -- Sort by rarity value
    table.sort(rarities, function(a, b)
        return InventoryFilters.getRarityValue(a) < InventoryFilters.getRarityValue(b)
    end)
    
    return rarities
end

function InventoryFilters.getSearchSuggestions(items, searchText)
    if not items or not searchText or searchText == "" then
        return {}
    end
    
    local suggestions = {}
    local searchLower = searchText:lower()
    local seen = {}
    
    for _, item in ipairs(items) do
        if item.name and item.name:lower():find(searchLower, 1, true) and not seen[item.name] then
            table.insert(suggestions, item.name)
            seen[item.name] = true
        end
    end
    
    table.sort(suggestions)
    return suggestions
end

return InventoryFilters
