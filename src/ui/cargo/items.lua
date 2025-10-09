local Content = require("src.content.content")
local Util = require("src.core.util")

local CargoItems = {}

local rarityOrder = {
    Common = 1,
    Uncommon = 2,
    Rare = 3,
    Epic = 4,
    Legendary = 5
}

function CargoItems.getItemDefinition(item)
    if not item then return nil end
    return item.turretData or Content.getItem(item.id) or Content.getTurret(item.id)
end

function CargoItems.getPlayerItems(player)
    if not player or not player.components or not player.components.cargo then
        return {}
    end

    local cargo = player.components.cargo
    local items = {}

    cargo:iterate(function(slot, entry)
        local data = entry.meta and Util.deepCopy(entry.meta) or nil
        items[#items + 1] = {
            id = entry.id,
            qty = entry.qty,
            meta = data,
            slot = slot,
        }
    end)

    table.sort(items, function(a, b)
        local defA = a.meta or Content.getItem(a.id) or Content.getTurret(a.id)
        local defB = b.meta or Content.getItem(b.id) or Content.getTurret(b.id)
        local nameA = (defA and defA.name) or a.id
        local nameB = (defB and defB.name) or b.id
        return nameA < nameB
    end)

    return items
end

local function getSortValue(item, sortBy)
    local def = CargoItems.getItemDefinition(item)
    if not def then return "" end

    if sortBy == "name" then
        return def.name or item.id
    elseif sortBy == "type" then
        return def.type or "unknown"
    elseif sortBy == "rarity" then
        return rarityOrder[def.rarity] or 0
    elseif sortBy == "value" then
        return def.price or def.value or 0
    elseif sortBy == "quantity" then
        return item.qty or 1
    end

    return ""
end

function CargoItems.sort(items, sortBy, sortOrder)
    table.sort(items, function(a, b)
        local aVal = getSortValue(a, sortBy)
        local bVal = getSortValue(b, sortBy)

        if sortOrder == "desc" then
            return aVal > bVal
        end

        return aVal < bVal
    end)
end

function CargoItems.filter(items, searchText)
    if not searchText or searchText == "" then
        return items
    end

    local filtered = {}
    local search = searchText:lower()

    for _, item in ipairs(items) do
        local def = CargoItems.getItemDefinition(item)
        if def then
            local name = (def.name or item.id):lower()
            local itemType = (def.type or ""):lower()
            local description = (def.description or ""):lower()

            if name:find(search, 1, true)
                or itemType:find(search, 1, true)
                or description:find(search, 1, true) then
                filtered[#filtered + 1] = item
            end
        end
    end

    return filtered
end

return CargoItems
