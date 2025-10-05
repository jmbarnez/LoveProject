local Events = require("src.core.events")
local RewardCrates = require("src.game.reward_crates")
local PlayerSystem = require("src.systems.player")
local Sound = require("src.core.sound")
local Util = require("src.core.util")

local EventSetup = {}

local function registerSoundEvents(player)
    Events.on(Events.GAME_EVENTS.PLAYER_DAMAGED, function()
        Sound.playSFX("hit")
    end)

    Events.on(Events.GAME_EVENTS.ENTITY_DESTROYED, function()
        Sound.playSFX("ship_destroyed")
    end)

    Events.on(Events.GAME_EVENTS.PLAYER_DIED, function()
        Sound.playSFX("player_death")
    end)
end

local function createDockingRefresher(player, world, hub)
    return function()
        if not player or not world then return end
        local position = player.components and player.components.position
        if not position then return end

        local docking = player.components and player.components.docking_status
        if not docking then return end

        if docking.docked then
            if docking.can_dock or docking.nearby_station then
                Events.emit(Events.GAME_EVENTS.CAN_DOCK, { canDock = false, station = nil })
            end
            return
        end

        local stations = {}
        local worldStations = world.get_entities_with_components and world:get_entities_with_components("station") or {}
        for _, station in ipairs(worldStations) do
            table.insert(stations, station)
        end
        if hub then
            local found = false
            for _, station in ipairs(stations) do
                if station == hub then
                    found = true
                    break
                end
            end
            if not found then
                table.insert(stations, hub)
            end
        end

        local px, py = position.x, position.y
        local nearestStation = nil
        local nearestDist = math.huge

        for _, station in ipairs(stations) do
            local stationPos = station.components and station.components.position
            if stationPos then
                local radius = station.weaponDisableRadius or (station.radius or 100) * 1.5
                local dist = Util.distance(px, py, stationPos.x, stationPos.y)
                if dist <= radius and dist < nearestDist then
                    nearestDist = dist
                    nearestStation = station
                end
            end
        end

        local canDockNow = nearestStation ~= nil
        if canDockNow ~= (docking.can_dock or false) or nearestStation ~= docking.nearby_station then
            Events.emit(Events.GAME_EVENTS.CAN_DOCK, { canDock = canDockNow, station = nearestStation })
        end
    end
end

local function registerDockingEvents(player, world, hub)
    Events.on(Events.GAME_EVENTS.CAN_DOCK, function(data)
        if not data then return end
        local docking = player.components and player.components.docking_status
        if docking then
            docking.can_dock = data.canDock and true or false
            docking.nearby_station = data.station
        end
    end)

    Events.on(Events.GAME_EVENTS.DOCK_REQUESTED, function()
        if RewardCrates.tryCollect(player, world) then
            return
        end
        local docking = player.components and player.components.docking_status
        if not docking or not docking.can_dock then return end
        if docking.docked then
            PlayerSystem.undock(player)
            return
        end
        local target = docking.nearby_station or hub
        if target then
            PlayerSystem.dock(player, target)
        end
    end)
end

local function registerWarpEvents(player, world)
    Events.on(Events.GAME_EVENTS.WARP_REQUESTED, function()
        if not player or not world then return end
        local gates = world:get_entities_with_components("warp_gate")
        for _, gate in ipairs(gates) do
            if gate.canInteractWith and gate:canInteractWith(player) then
                gate:activate(player)
                return
            end
        end
    end)
end

local function registerNotificationEvents()
    Events.on(Events.GAME_EVENTS.GAME_SAVED, function(data)
        local Notifications = require("src.ui.notifications")
        Notifications.add("Game saved: " .. (data.description or "Unknown"), "action")
    end)

    Events.on(Events.GAME_EVENTS.GAME_LOADED, function(data)
        local Notifications = require("src.ui.notifications")
        Notifications.add("Game loaded: " .. (data.loadTime or "Unknown"), "info")
    end)

    Events.on(Events.GAME_EVENTS.GAME_SAVE_DELETED, function(data)
        local Notifications = require("src.ui.notifications")
        Notifications.add("Save slot deleted: " .. (data.slotName or "Unknown"), "info")
    end)
end

function EventSetup.register(player, world, hub)
    registerSoundEvents(player)
    registerDockingEvents(player, world, hub)
    registerWarpEvents(player, world)
    registerNotificationEvents()

    PlayerSystem.init(world)

    local refreshDockingState = createDockingRefresher(player, world, hub)
    refreshDockingState()

    return refreshDockingState
end

return EventSetup
