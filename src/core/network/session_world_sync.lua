local Events = require("src.core.events")
local EntityFactory = require("src.templates.entity_factory")
local RemoteEnemySync = require("src.systems.remote_enemy_sync")
local RemoteProjectileSync = require("src.systems.remote_projectile_sync")
local NetworkSync = require("src.systems.network_sync")

local SessionWorldSync = {}

local function simpleHash(data)
    if not data or type(data) ~= "table" then
        return tostring(data)
    end

    local hash = ""
    for key, value in pairs(data) do
        if type(value) == "table" then
            hash = hash .. tostring(key) .. ":" .. simpleHash(value) .. ";"
        else
            hash = hash .. tostring(key) .. ":" .. tostring(value) .. ";"
        end
    end
    return hash
end

local function sanitisePlayerNetworkState(playerState)
    if type(playerState) ~= "table" then
        return nil
    end

    local position = playerState.position or {}
    local velocity = playerState.velocity or {}
    local hull = playerState.hull
    local shield = playerState.shield

    local sanitised = {
        position = {
            x = tonumber(position.x) or 0,
            y = tonumber(position.y) or 0,
            angle = tonumber(position.angle) or 0,
        },
        velocity = {
            x = tonumber(velocity.x) or 0,
            y = tonumber(velocity.y) or 0,
        },
    }

    if type(hull) == "table" then
        sanitised.hull = {
            hp = tonumber(hull.hp) or 100,
            maxHP = tonumber(hull.maxHP) or 100,
        }
    end
    
    if type(energy) == "table" then
        sanitised.energy = {
            energy = tonumber(energy.energy) or 0,
            maxEnergy = tonumber(energy.maxEnergy) or 100,
        }
    end

    return sanitised
end

local function clearSyncedWorldEntities(state)
    local world = state.world
    if world then
        for _, entity in ipairs(state.syncedWorldEntities) do
            if entity then
                world:removeEntity(entity)
            end
        end
    end

    state.syncedWorldEntities = {}
    state.hub = nil
end

local function spawnEntityFromSnapshot(state, entry)
    if not entry or not entry.kind or not entry.id then
        return nil
    end

    local extra = {}
    if entry.extra then
        for key, value in pairs(entry.extra) do
            extra[key] = value
        end
    end

    if entry.angle ~= nil then
        extra.angle = entry.angle
    end

    if next(extra) == nil then
        extra = nil
    end

    if entry.kind == "enemy" then
        local entity = EntityFactory.createEnemy(entry.type or entry.id, entry.x or 0, entry.y or 0)
        if entity then
            entity.id = entry.id
            if entry.angle ~= nil then
                entity.components.position.angle = entry.angle
            end
        end
        return entity
    end

    return EntityFactory.create(entry.kind, entry.id, entry.x or 0, entry.y or 0, extra)
end

local function applySelfNetworkStateIfAvailable(state)
    local player = state.player
    local pendingState = state.pendingSelfNetworkState
    if not player or not pendingState then
        return
    end

    local newPos = pendingState.position
    if newPos and player.components and player.components.position then
        local positionComponent = player.components.position
        positionComponent.x = newPos.x or 0
        positionComponent.y = newPos.y or 0
        positionComponent.angle = newPos.angle or 0

        local physics = player.components.physics
        if physics and physics.body then
            local body = physics.body
            if body.setPosition then
                body:setPosition(positionComponent.x, positionComponent.y)
            else
                body.x = positionComponent.x
                body.y = positionComponent.y
            end
            if body.setAngle then
                body:setAngle(positionComponent.angle)
            else
                body.angle = positionComponent.angle
            end
        end
    end

    local newVel = pendingState.velocity
    if newVel and player.components and player.components.velocity then
        local velocityComponent = player.components.velocity
        velocityComponent.x = newVel.x or 0
        velocityComponent.y = newVel.y or 0

        local physics = player.components.physics
        if physics and physics.body then
            local body = physics.body
            if body.setLinearVelocity then
                body:setLinearVelocity(velocityComponent.x, velocityComponent.y)
            elseif body.setVelocity then
                body:setVelocity(velocityComponent.x, velocityComponent.y)
            else
                body.vx = velocityComponent.x
                body.vy = velocityComponent.y
            end
        end
    end

    if pendingState.hull and player.components and player.components.hull then
        local hullComponent = player.components.hull
        for key, value in pairs(pendingState.hull) do
            hullComponent[key] = value
        end
    end
    
    if pendingState.energy and player.components and player.components.energy then
        local energyComponent = player.components.energy
        for key, value in pairs(pendingState.energy) do
            energyComponent[key] = value
        end
    end
    if pendingState.shield and player.components and player.components.shield then
        local shieldComponent = player.components.shield
        for key, value in pairs(pendingState.shield) do
            shieldComponent[key] = value
        end
    end

    state.pendingSelfNetworkState = nil
end

local function applyWorldSnapshot(state, snapshot)
    local world = state.world
    if not snapshot or not world then
        return
    end

    clearSyncedWorldEntities(state)

    world.width = snapshot.width or world.width
    world.height = snapshot.height or world.height

    for _, entry in ipairs(snapshot.entities or {}) do
        local entity = spawnEntityFromSnapshot(state, entry)
        if entity then
            entity.isSyncedEntity = true
            if entry.id ~= nil then
                entity.syncedHostId = tostring(entry.id)
            end
            world:addEntity(entity)
            if entry.kind == "station" and entry.id == "hub_station" then
                state.hub = entity
            end
            table.insert(state.syncedWorldEntities, entity)
        end
    end
end

local function queueWorldSnapshot(state, snapshot)
    if not snapshot then
        return
    end

    if not state.world then
        state.pendingWorldSnapshot = snapshot
        return
    end

    applyWorldSnapshot(state, snapshot)
    state.pendingWorldSnapshot = nil
end

local function buildWorldSnapshotFromWorld(state)
    local world = state.world
    if not world then
        return nil
    end

    local currentTime = love.timer and love.timer.getTime() or os.clock()
    if state.cachedWorldSnapshot and
       (currentTime - state.lastWorldSnapshotTime) < state.worldSnapshotCacheTimeout then
        return state.cachedWorldSnapshot
    end

    local snapshot = {
        width = world.width or 0,
        height = world.height or 0,
        entities = {},
    }

    local stationEntities = world:get_entities_with_components("station", "position")
    for _, entity in ipairs(stationEntities) do
        if not entity.isPlayer and not entity.isRemotePlayer and not entity.isSyncedEntity then
            local position = entity.components.position
            local station = entity.components.station or {}
            local entry = {
                kind = "station",
                id = station.type or "station",
                x = position.x or 0,
                y = position.y or 0,
            }
            if position.angle ~= nil then
                entry.angle = position.angle
            end
            snapshot.entities[#snapshot.entities + 1] = entry
        end
    end

    local worldObjectEntities = world:get_entities_with_components("mineable", "position")
    for _, entity in ipairs(worldObjectEntities) do
        if not entity.isPlayer and not entity.isRemotePlayer and not entity.isSyncedEntity then
            local position = entity.components.position
            local subtype = entity.subtype or (entity.components.renderable and entity.components.renderable.type) or "world_object"
            local entry = {
                kind = "world_object",
                id = subtype,
                x = position.x or 0,
                y = position.y or 0,
            }
            if position.angle ~= nil then
                entry.angle = position.angle
            end
            snapshot.entities[#snapshot.entities + 1] = entry
        end
    end

    local interactableEntities = world:get_entities_with_components("interactable", "position")
    for _, entity in ipairs(interactableEntities) do
        if not entity.isPlayer and not entity.isRemotePlayer and not entity.isSyncedEntity then
            local position = entity.components.position
            local subtype = entity.subtype or (entity.components.renderable and entity.components.renderable.type) or "world_object"
            local entry = {
                kind = "world_object",
                id = subtype,
                x = position.x or 0,
                y = position.y or 0,
            }
            if position.angle ~= nil then
                entry.angle = position.angle
            end
            snapshot.entities[#snapshot.entities + 1] = entry
        end
    end

    local Settings = require("src.core.settings")
    local networkingSettings = Settings.getNetworkingSettings()
    if networkingSettings and networkingSettings.host_authoritative_enemies then
        local enemyEntities = world:get_entities_with_components("ai", "position")
        for _, entity in ipairs(enemyEntities) do
            if not entity.isPlayer and not entity.isRemotePlayer and not entity.isSyncedEntity then
                local position = entity.components.position
                local entry = {
                    kind = "enemy",
                    id = entity.id or tostring(entity),
                    type = entity.shipId or "basic_drone",
                    x = position.x or 0,
                    y = position.y or 0,
                }
                if position.angle ~= nil then
                    entry.angle = position.angle
                end
                snapshot.entities[#snapshot.entities + 1] = entry
            end
        end
    end

    state.cachedWorldSnapshot = snapshot
    state.lastWorldSnapshotTime = currentTime

    return snapshot
end

local function buildDeltaWorldSnapshot(state)
    local world = state.world
    if not world then
        return nil
    end

    local currentTime = love.timer and love.timer.getTime() or os.clock()
    if (currentTime - state.lastWorldSnapshotSend) < state.worldSnapshotSendInterval then
        return nil
    end

    local snapshot = {
        width = world.width or 0,
        height = world.height or 0,
        entities = {},
        isDelta = true,
        timestamp = currentTime
    }

    local stationEntities = world:get_entities_with_components("station", "position")
    for _, entity in ipairs(stationEntities) do
        if not entity.isPlayer and not entity.isRemotePlayer and not entity.isSyncedEntity then
            local position = entity.components.position
            local station = entity.components.station or {}
            local entry = {
                kind = "station",
                id = station.type or "station",
                x = position.x or 0,
                y = position.y or 0,
            }
            if position.angle ~= nil then
                entry.angle = position.angle
            end
            snapshot.entities[#snapshot.entities + 1] = entry
        end
    end

    local worldObjectEntities = world:get_entities_with_components("mineable", "position")
    for _, entity in ipairs(worldObjectEntities) do
        if not entity.isPlayer and not entity.isRemotePlayer and not entity.isSyncedEntity then
            local position = entity.components.position
            local subtype = entity.subtype or (entity.components.renderable and entity.components.renderable.type) or "world_object"
            local entry = {
                kind = "world_object",
                id = subtype,
                x = position.x or 0,
                y = position.y or 0,
            }
            if position.angle ~= nil then
                entry.angle = position.angle
            end
            snapshot.entities[#snapshot.entities + 1] = entry
        end
    end

    state.lastWorldSnapshotSend = currentTime

    return snapshot
end

local function invalidateWorldSnapshotCache(state)
    state.cachedWorldSnapshot = nil
    state.lastWorldSnapshotTime = 0
end

local function broadcastHostWorldSnapshot(state, peer)
    local manager = state.networkManager
    if not manager or not manager:isHost() then
        return
    end

    local snapshot = buildDeltaWorldSnapshot(state)
    if not snapshot then
        return
    end

    local snapshotHash = simpleHash(snapshot)
    if snapshotHash == state.lastWorldSnapshotHash then
        return
    end
    state.lastWorldSnapshotHash = snapshotHash

    manager:updateWorldSnapshot(snapshot, peer)
end

local function broadcastFullWorldSnapshot(state, peer)
    local manager = state.networkManager
    if not manager or not manager:isHost() then
        return
    end

    local snapshot = buildWorldSnapshotFromWorld(state)
    if not snapshot then
        return
    end

    snapshot.isFullSnapshot = true
    snapshot.timestamp = love.timer and love.timer.getTime() or os.clock()

    manager:updateWorldSnapshot(snapshot, peer)
end

local function ensureRemotePlayerEntity(state, playerId)
    local world = state.world
    local manager = state.networkManager
    if not world or not manager then
        return nil
    end

    local players = manager:getPlayers()
    local playerInfo = players[playerId]
    if not playerInfo then
        return nil
    end

    local entity = NetworkSync.ensureRemoteEntity(playerId, playerInfo.state or {}, world)
    if entity then
        entity.playerName = playerInfo.playerName or string.format("Player %d", playerId)
    end
    return entity
end

local function resolvePlayerEntityForRequest(state, playerId)
    local world = state.world
    if not world then
        return nil
    end

    if playerId == 0 then
        return state.player
    end

    local players = world:get_entities_with_components("player")
    for _, candidate in ipairs(players) do
        if candidate.remotePlayerId == playerId then
            return candidate
        end
    end

    return ensureRemotePlayerEntity(state, playerId)
end

local function clearEventHandlers(state)
    for eventName, handler in pairs(state.eventHandlers) do
        if handler and Events.off then
            Events.off(eventName, handler)
        end
    end
    state.eventHandlers = {}
end

local function registerWorldSyncEventHandlers(state, callbacks)
    if state.worldSyncHandlersRegistered then
        return
    end

    clearEventHandlers(state)

    local setMode = callbacks.setMode or function() end
    local handleWeaponRequest = callbacks.handleWeaponRequest or function() end

    state.eventHandlers["NETWORK_WORLD_SNAPSHOT"] = Events.on("NETWORK_WORLD_SNAPSHOT", function(data)
        if state.isHost then
            return
        end

        local snapshot = data and data.snapshot or nil
        if snapshot then
            queueWorldSnapshot(state, snapshot)
        end
    end)

    state.eventHandlers["NETWORK_DISCONNECTED"] = Events.on("NETWORK_DISCONNECTED", function()
        if state.isHost then
            return
        end

        clearSyncedWorldEntities(state)
        state.pendingWorldSnapshot = nil
        state.pendingSelfNetworkState = nil
    end)

    state.eventHandlers["NETWORK_SERVER_STOPPED"] = Events.on("NETWORK_SERVER_STOPPED", function()
        if state.isHost then
            return
        end

        clearSyncedWorldEntities(state)
        state.pendingWorldSnapshot = nil
        state.pendingSelfNetworkState = nil
    end)

    state.eventHandlers["NETWORK_SERVER_STARTED"] = Events.on("NETWORK_SERVER_STARTED", function()
        if not state.isHost or not state.world then
            return
        end

        broadcastFullWorldSnapshot(state)
    end)

    state.eventHandlers["NETWORK_ENEMY_UPDATE"] = Events.on("NETWORK_ENEMY_UPDATE", function(data)
        if state.isHost then
            return
        end

        local enemies = data and data.enemies or nil
        if enemies then
            RemoteEnemySync.applyEnemySnapshot(enemies, state.world)
        end
    end)

    state.eventHandlers["NETWORK_PROJECTILE_UPDATE"] = Events.on("NETWORK_PROJECTILE_UPDATE", function(data)
        if state.isHost then
            return
        end

        local projectiles = data and data.projectiles or nil
        if projectiles then
            RemoteProjectileSync.applyProjectileSnapshot(projectiles, state.world)
        end
    end)

    state.eventHandlers["NETWORK_WEAPON_FIRE_REQUEST"] = Events.on("NETWORK_WEAPON_FIRE_REQUEST", function(data)
        if not state.isHost then
            return
        end

        local request = data and data.request or nil
        if not request then
            return
        end

        handleWeaponRequest(request, data.playerId)
    end)

    state.eventHandlers["NETWORK_PLAYER_JOINED"] = Events.on("NETWORK_PLAYER_JOINED", function(data)
        if state.isHost then
            if not state.isMultiplayer and state.networkManager and state.networkManager:isHost() then
                setMode(true, true)
            end
            if state.networkManager and state.networkManager:isHost() then
                broadcastFullWorldSnapshot(state, data and data.peer)
            end
            return
        end

        if not data or not data.playerId or not data.isSelf then
            return
        end

        local sanitisedState = sanitisePlayerNetworkState(data.data)
        if not sanitisedState then
            return
        end

        state.pendingSelfNetworkState = sanitisedState
        applySelfNetworkStateIfAvailable(state)
    end)

    state.worldSyncHandlersRegistered = true
end

function SessionWorldSync.applySelfNetworkState(state)
    applySelfNetworkStateIfAvailable(state)
end

function SessionWorldSync.queueWorldSnapshot(state, snapshot)
    queueWorldSnapshot(state, snapshot)
end

function SessionWorldSync.broadcastHostWorldSnapshot(state, peer)
    broadcastHostWorldSnapshot(state, peer)
end

function SessionWorldSync.broadcastFullWorldSnapshot(state, peer)
    broadcastFullWorldSnapshot(state, peer)
end

function SessionWorldSync.invalidateCache(state)
    invalidateWorldSnapshotCache(state)
end

function SessionWorldSync.onWorldUpdated(state)
    state.syncedWorldEntities = {}
    if state.pendingWorldSnapshot then
        queueWorldSnapshot(state, state.pendingWorldSnapshot)
    end
end

function SessionWorldSync.resolvePlayerEntityForRequest(state, playerId)
    return resolvePlayerEntityForRequest(state, playerId)
end

function SessionWorldSync.clearSyncedWorldEntities(state)
    clearSyncedWorldEntities(state)
end

function SessionWorldSync.clearEventHandlers(state)
    clearEventHandlers(state)
    state.worldSyncHandlersRegistered = false
end

function SessionWorldSync.registerEventHandlers(state, callbacks)
    registerWorldSyncEventHandlers(state, callbacks or {})
end

return SessionWorldSync

