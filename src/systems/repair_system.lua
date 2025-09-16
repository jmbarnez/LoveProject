local RepairSystem = {}

-- Check if player has required materials for repair
local function hasRepairMaterials(player, repairCost)
    if not player.inventory then
        return false
    end

    for _, requirement in ipairs(repairCost) do
        local playerAmount = player.inventory[requirement.item] or 0
        if playerAmount < requirement.amount then
            return false
        end
    end

    return true
end

-- Check individual item quantities in player inventory
local function getPlayerItemCount(player, itemId)
    if not player.inventory then
        return 0
    end
    return player.inventory[itemId] or 0
end

-- Consume repair materials from player inventory
local function consumeRepairMaterials(player, repairCost)
    if not player.inventory then
        return false
    end

    -- Double-check we have everything before consuming
    if not hasRepairMaterials(player, repairCost) then
        return false
    end

    -- Consume the materials
    for _, requirement in ipairs(repairCost) do
        player.inventory[requirement.item] = player.inventory[requirement.item] - requirement.amount
    end

    return true
end

-- Display repair requirements when player is near
local function showRepairRequirements(station, player)
    if not station.components.repairable or not station.components.repairable.broken then
        return
    end

    local dx = player.components.position.x - station.components.position.x
    local dy = player.components.position.y - station.components.position.y
    local distance = math.sqrt(dx * dx + dy * dy)
    local interactionRange = 200 -- Close enough to see repair requirements

    if distance <= interactionRange then
        -- Show repair requirements in UI
        -- This would integrate with the existing UI system
        local requirements = station.components.repairable.repairCost
        local text = "REPAIR REQUIRED:\n"
        for _, req in ipairs(requirements) do
            text = text .. string.format("• %s: %d\n", req.item, req.amount)
        end

        -- For now, just store the text on the station for UI to pick up
        station.repairText = text
        station.showingRepairText = true
    else
        station.showingRepairText = false
    end
end

-- Attempt to repair the station
local function attemptRepair(station, player)
    if not station.components.repairable or not station.components.repairable.broken then
        return false
    end

    local repairCost = station.components.repairable.repairCost
    if hasRepairMaterials(player, repairCost) then
        -- Consume materials from inventory
        if not consumeRepairMaterials(player, repairCost) then
            return false -- Failed to consume materials
        end

        -- Repair the station
        station.components.repairable.broken = false
        station.broken = false

        -- Enable no-spawn radius for beacon stations
        if station.components.station.type == "beacon_station" then
            station.noSpawnRadius = 2500
        end

        -- Update station name
        if station.components.station then
            station.components.station.name = "Defensive Beacon Array (OPERATIONAL)"
        end

        return true -- Successfully repaired
    end

    return false -- Not enough materials
end

function RepairSystem.update(dt, player, world)
    -- Get all repairable entities
    local repairable_entities = world:get_entities_with_components("repairable")

    -- Debug: print repairable entities found
    if #repairable_entities > 0 then
        for _, entity in ipairs(repairable_entities) do
            if entity.components.repairable and entity.components.repairable.broken then
                showRepairRequirements(entity, player)
            end
        end
    end
end

-- Handle repair interaction (would be called by input system)
function RepairSystem.tryRepair(station, player)
    return attemptRepair(station, player)
end

-- Utility functions for UI
function RepairSystem.hasAllMaterials(player, repairCost)
    return hasRepairMaterials(player, repairCost)
end

function RepairSystem.getPlayerItemCount(player, itemId)
    return getPlayerItemCount(player, itemId)
end

return RepairSystem