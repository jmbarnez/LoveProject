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
    local popup = getRepairPopup()
    if not popup or not world or not player then
        return
    end

    local repairableEntities = world:get_entities_with_components("repairable")
    if not repairableEntities or #repairableEntities == 0 then
        popup.hide()
        return
    end

    local playerPos = player.components and player.components.position
    if not playerPos then
        popup.hide()
        return
    end

    local interactionRange = popup.interactionRange or 220
    local rangeSq = interactionRange * interactionRange

    local nearestStation = nil
    local nearestDistSq = rangeSq + 1

    for _, entity in ipairs(repairableEntities) do
        local repairable = entity.components and entity.components.repairable
        local stationComponent = entity.components and entity.components.station
        if repairable and repairable.broken and stationComponent and stationComponent.type == "beacon_station" then
            local pos = entity.components.position
            if pos then
                local dx = playerPos.x - pos.x
                local dy = playerPos.y - pos.y
                local distSq = dx * dx + dy * dy
                if distSq <= rangeSq and distSq < nearestDistSq then
                    nearestStation = entity
                    nearestDistSq = distSq
                end
            end
        end
    end

    if nearestStation then
        popup.show(nearestStation, player, RepairSystem.tryRepair)
    else
        popup.hide()
    end
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
