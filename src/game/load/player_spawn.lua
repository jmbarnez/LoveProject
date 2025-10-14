local Constants = require("src.core.constants")
local Player = require("src.entities.player")
local NetworkSession = require("src.core.network.session")
local Debug = require("src.core.debug")
local Log = require("src.core.log")

local PlayerSpawn = {}

local function loadFromSave(saveSlot)
    local slotName = (type(saveSlot) == "string") and saveSlot or ("slot" .. saveSlot)
    local StateManager = require("src.managers.state_manager")

    local success, result = pcall(StateManager.loadGame, slotName, true)
    if not success then
        Debug.error("game", "Save load failed with error: %s", tostring(result))
        local Notifications = require("src.ui.notifications")
        Notifications.add("Save file corrupted or incompatible", "error")
        return nil, "Save load failed"
    end

    if not result then
        Debug.error("game", "Failed to load game from %s", slotName)
        local Notifications = require("src.ui.notifications")
        Notifications.add("Save file not found or invalid", "error")
        return nil, "Save missing"
    end

    local player = StateManager.getCurrentPlayer()
    if not player then
        Debug.error("game", "Failed to get player from save data")
        local Notifications = require("src.ui.notifications")
        Notifications.add("Save file missing player data", "error")
        return nil, "Save missing player"
    end

    return player
end

local function chooseSpawnPosition(world, hub)
    local px, py

    if NetworkSession.isMultiplayer() and not NetworkSession.isHost() then
        local networkManager = NetworkSession.getManager()
        local assignedPosition

        if networkManager and networkManager.getPlayers then
            local players = networkManager:getPlayers()
            local localPlayerId = networkManager:getLocalPlayerId()
            if localPlayerId and players[localPlayerId] and players[localPlayerId].state then
                assignedPosition = players[localPlayerId].state.position
            end
        end

        if not assignedPosition then
            local pendingState = NetworkSession.getPendingSelfNetworkState and NetworkSession.getPendingSelfNetworkState()
            if pendingState and pendingState.position then
                assignedPosition = pendingState.position
            end
        end

        if assignedPosition then
            px = assignedPosition.x or Constants.SPAWNING.MARGIN
            py = assignedPosition.y or Constants.SPAWNING.MARGIN
        else
            px = 0
            py = 0
        end
    else
        local angle = math.random() * math.pi * 2
        local weapon_disable_radius = hub and hub:getWeaponDisableRadius() or Constants.STATION.WEAPONS_DISABLE_DURATION * 200
        local spawn_dist = weapon_disable_radius * 1.2
        px = (hub and hub.components and hub.components.position and hub.components.position.x or Constants.SPAWNING.MARGIN) + math.cos(angle) * spawn_dist
        py = (hub and hub.components and hub.components.position and hub.components.position.y or Constants.SPAWNING.MARGIN) + math.sin(angle) * spawn_dist

        if not (NetworkSession.isMultiplayer() and not NetworkSession.isHost()) then
            local attempts = 0
            local maxAttempts = 50
            local spawnValid = false

            while not spawnValid and attempts < maxAttempts do
                attempts = attempts + 1
                spawnValid = true

                local stations = world:get_entities_with_components("station")
                for _, station in ipairs(stations) do
                    if station and station.components and station.components.position and station.components.collidable then
                        local sx = station.components.position.x
                        local sy = station.components.position.y
                        local dx = px - sx
                        local dy = py - sy
                        local distance = math.sqrt(dx * dx + dy * dy)

                        local stationRadius = 50
                        if station.components.collidable.radius then
                            stationRadius = station.components.collidable.radius
                        elseif station.radius then
                            stationRadius = station.radius
                        end

                        local safeDistance = stationRadius + 30

                        if distance < safeDistance then
                            spawnValid = false
                            local angle = math.random() * math.pi * 2
                            local weapon_disable_radius = hub and hub:getWeaponDisableRadius() or Constants.STATION.WEAPONS_DISABLE_DURATION * 200
                            local spawn_dist = weapon_disable_radius * 1.2
                            px = (hub and hub.components and hub.components.position and hub.components.position.x or Constants.SPAWNING.MARGIN) + math.cos(angle) * spawn_dist
                            py = (hub and hub.components and hub.components.position and hub.components.position.y or Constants.SPAWNING.MARGIN) + math.sin(angle) * spawn_dist
                            break
                        end
                    end
                end
            end

            if not spawnValid then
                px = Constants.SPAWNING.MARGIN
                py = Constants.SPAWNING.MARGIN
            end
        end
    end

    -- Ensure player spawns within world bounds
    local worldWidth = Constants.WORLD.WIDTH
    local worldHeight = Constants.WORLD.HEIGHT
    local margin = Constants.SPAWNING.MARGIN
    
    -- Clamp position to world bounds with margin
    px = math.max(margin, math.min(px, worldWidth - margin))
    py = math.max(margin, math.min(py, worldHeight - margin))

    return px, py
end

function PlayerSpawn.spawn(fromSave, saveSlot, world, hub)
    if fromSave and saveSlot then
        return loadFromSave(saveSlot)
    end

    local px, py = chooseSpawnPosition(world, hub)
    local player = Player.new(px, py, "starter_frigate_basic")
    return player
end

return PlayerSpawn
