local RepairSystem = {}

local function hasRepairMaterials(player, repairCost)
    local cargo = player.components and player.components.cargo
    if not cargo then
        return false
    end

    for _, requirement in ipairs(repairCost) do
        if cargo:getQuantity(requirement.item) < requirement.amount then
            return false
        end
    end

    return true
end

local function getPlayerItemCount(player, itemId)
    local cargo = player.components and player.components.cargo
    if not cargo then
        return 0
    end
    return cargo:getQuantity(itemId)
end

local function consumeRepairMaterials(player, repairCost)
    local cargo = player.components and player.components.cargo
    if not cargo then
        return false
    end

    if not hasRepairMaterials(player, repairCost) then
        return false
    end

    for _, requirement in ipairs(repairCost) do
        cargo:remove(requirement.item, requirement.amount)
    end

    return true
end

local BeaconRepairPopupModule = nil
local function getRepairPopup()
    if BeaconRepairPopupModule == nil then
        local ok, popup = pcall(require, "src.ui.beacon_repair_popup")
        if ok then
            BeaconRepairPopupModule = popup
        else
            BeaconRepairPopupModule = false
        end
    end

    if BeaconRepairPopupModule == false then
        return nil
    end

    return BeaconRepairPopupModule
end

local function attemptRepair(station, player)
    if not station.components.repairable or not station.components.repairable.broken then
        return false
    end

    local repairCost = station.components.repairable.repairCost
    if hasRepairMaterials(player, repairCost) then
        if not consumeRepairMaterials(player, repairCost) then
            return false
        end

        station.components.repairable.broken = false
        station.broken = false

        if station.components.station.type == "beacon_station" then
            station.noSpawnRadius = 2500
        end

        if station.components.station then
            station.components.station.name = "Defensive Beacon Array (OPERATIONAL)"
        end

        local popup = getRepairPopup()
        if popup and popup.onRepairSuccess then
            popup.onRepairSuccess()
        end

        return true
    end

    return false
end

function RepairSystem.update(dt, player, world)
    -- Repair system disabled - players must build their own stations
    return
end

function RepairSystem.tryRepair(station, player)
    return attemptRepair(station, player)
end

function RepairSystem.hasAllMaterials(player, repairCost)
    return hasRepairMaterials(player, repairCost)
end

function RepairSystem.getPlayerItemCount(player, itemId)
    return getPlayerItemCount(player, itemId)
end

return RepairSystem
