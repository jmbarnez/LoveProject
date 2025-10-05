local Util = require("src.core.util")
local Events = require("src.core.events")
local Log = require("src.core.log")
local EntityFactory = require("src.templates.entity_factory")
local RemoteEnemySync = require("src.systems.remote_enemy_sync")
local RemoteProjectileSync = require("src.systems.remote_projectile_sync")
local NetworkManager = require("src.core.network.manager")
local NetworkSync = require("src.systems.network_sync")

local Session = {}

local state = {
    networkManager = nil,
    isMultiplayer = false,
    isHost = false,
    world = nil,
    player = nil,
    hub = nil,
    syncedWorldEntities = {},
    pendingWorldSnapshot = nil,
    pendingSelfNetworkState = nil,
    worldSyncHandlersRegistered = false,
    networkManagerListenersRegistered = false,
    eventHandlers = {}, -- Track event handlers for cleanup
    -- Performance optimization: Cache world snapshot to avoid expensive rebuilds
    cachedWorldSnapshot = nil,
    lastWorldSnapshotTime = 0,
    worldSnapshotCacheTimeout = 5.0, -- Cache for 5 seconds
}

local function sanitisePlayerNetworkState(playerState)
    if type(playerState) ~= "table" then
        return nil
    end

    local position = playerState.position or {}
    local velocity = playerState.velocity or {}
    local health = playerState.health

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

    if type(health) == "table" then
        sanitised.health = {
            hp = tonumber(health.hp) or 100,
            maxHP = tonumber(health.maxHP) or 100,
            shield = tonumber(health.shield) or 0,
            maxShield = tonumber(health.maxShield) or 0,
            energy = tonumber(health.energy) or 0,
            maxEnergy = tonumber(health.maxEnergy) or 0,
        }
    end

    return sanitised
end

local function clearSyncedWorldEntities()
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

local function spawnEntityFromSnapshot(entry)
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

    -- Handle enemy entities specially
    if entry.kind == "enemy" then
        local entity = EntityFactory.createEnemy(entry.type or entry.id, entry.x or 0, entry.y or 0)
        if entity then
            -- Preserve the ID from the snapshot for matching with remote updates
            entity.id = entry.id
            if entry.angle ~= nil then
                entity.components.position.angle = entry.angle
            end
        end
        return entity
    end

    return EntityFactory.create(entry.kind, entry.id, entry.x or 0, entry.y or 0, extra)
end

local function applySelfNetworkStateIfAvailable()
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

    if pendingState.health and player.components and player.components.health then
        local healthComponent = player.components.health
        for key, value in pairs(pendingState.health) do
            healthComponent[key] = value
        end
    end

    state.pendingSelfNetworkState = nil
end

local function applyWorldSnapshot(snapshot)
    local world = state.world
    if not snapshot or not world then
        return
    end

    clearSyncedWorldEntities()

    world.width = snapshot.width or world.width
    world.height = snapshot.height or world.height

    for _, entry in ipairs(snapshot.entities or {}) do
        local entity = spawnEntityFromSnapshot(entry)
        if entity then
            entity.isSyncedEntity = true
            world:addEntity(entity)
            if entry.kind == "station" and entry.id == "hub_station" then
                state.hub = entity
            end
            table.insert(state.syncedWorldEntities, entity)
        else
        end
    end
end

local function queueWorldSnapshot(snapshot)
    if not snapshot then
        return
    end

    if not state.world then
        -- Use shallow copy for pending snapshot since it's temporary
        state.pendingWorldSnapshot = snapshot
        return
    end

    applyWorldSnapshot(snapshot)
    state.pendingWorldSnapshot = nil
end

local function buildWorldSnapshotFromWorld()
    local world = state.world
    if not world then
        return nil
    end

    -- Performance optimization: Use cached snapshot if available and not expired
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

    -- Performance optimization: Use more efficient entity queries instead of iterating all entities
    -- Get stations first (usually few in number)
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

    -- Get world objects (mineable/interactable entities)
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

    -- Get interactable entities
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

    -- Get enemy entities only if host-authoritative enemies is enabled
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

    -- Cache the snapshot for future use
    state.cachedWorldSnapshot = snapshot
    state.lastWorldSnapshotTime = currentTime

    return snapshot
end

local function invalidateWorldSnapshotCache()
    state.cachedWorldSnapshot = nil
    state.lastWorldSnapshotTime = 0
end

local function broadcastHostWorldSnapshot(peer)
    local manager = state.networkManager
    if not manager or not manager:isHost() then
        return
    end

    local snapshot = buildWorldSnapshotFromWorld()
    if not snapshot then
        return
    end

    manager:updateWorldSnapshot(snapshot, peer)
end

local function ensureRemotePlayerEntity(playerId)
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

local function resolvePlayerEntityForRequest(playerId)
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

    return ensureRemotePlayerEntity(playerId)
end

local function handleProjectileRequest(request, playerId)
    local world = state.world
    if not world or not request then
        return
    end

    local player = resolvePlayerEntityForRequest(playerId)
    if not player then
        return
    end

    local projectileId = request.projectileId or "gun_bullet"
    local extraConfig = {
        angle = request.angle or 0,
        friendly = true,
        damage = request.damageConfig,
        kind = "bullet",
        additionalEffects = request.additionalEffects,
        source = player,
    }


    local projectile = EntityFactory.create(
        "projectile",
        projectileId,
        request.position and request.position.x or 0,
        request.position and request.position.y or 0,
        extraConfig
    )

    if projectile then
        world:addEntity(projectile)
    else
    end
end

local function handleBeamRequest(request, playerId)
    local world = state.world
    if not world or not request then
        return
    end

    local player = resolvePlayerEntityForRequest(playerId)
    if not player then
        return
    end

    local beamLength = request.beamLength or 100
    local startX = request.position and request.position.x or 0
    local startY = request.position and request.position.y or 0
    local endX = startX + math.cos(request.angle or 0) * beamLength
    local endY = startY + math.sin(request.angle or 0) * beamLength

    player.remoteBeamActive = true
    player.remoteBeamStartX = startX
    player.remoteBeamStartY = startY
    player.remoteBeamEndX = endX
    player.remoteBeamEndY = endY
    player.remoteBeamAngle = request.angle or 0
    player.remoteBeamLength = beamLength
    player.remoteBeamStartTime = love.timer and love.timer.getTime() or os.clock()
end

local function handleUtilityBeamRequest(request, playerId)
    local world = state.world
    if not world or not request then
        return
    end

    local player = resolvePlayerEntityForRequest(playerId)
    if not player then
        return
    end

    local beamLength = request.beamLength or 100
    local startX = request.position and request.position.x or 0
    local startY = request.position and request.position.y or 0
    local endX = startX + math.cos(request.angle or 0) * beamLength
    local endY = startY + math.sin(request.angle or 0) * beamLength

    player.remoteUtilityBeamActive = true
    player.remoteUtilityBeamType = request.beamType
    player.remoteUtilityBeamStartX = startX
    player.remoteUtilityBeamStartY = startY
    player.remoteUtilityBeamEndX = endX
    player.remoteUtilityBeamEndY = endY
    player.remoteUtilityBeamAngle = request.angle or 0
    player.remoteUtilityBeamLength = beamLength
    player.remoteUtilityBeamStartTime = love.timer and love.timer.getTime() or os.clock()
end

local function clearEventHandlers()
    for eventName, handler in pairs(state.eventHandlers) do
        if handler and Events.off then
            Events.off(eventName, handler)
        end
    end
    state.eventHandlers = {}
end

local function registerWorldSyncEventHandlers()
    if state.worldSyncHandlersRegistered then
        return
    end

    -- Clear any existing handlers first
    clearEventHandlers()

    -- Register new handlers and track them for cleanup
    state.eventHandlers["NETWORK_WORLD_SNAPSHOT"] = Events.on("NETWORK_WORLD_SNAPSHOT", function(data)
        if state.isHost then
            return
        end

        local snapshot = data and data.snapshot or nil
        if snapshot then
            queueWorldSnapshot(snapshot)
        end
    end)

    state.eventHandlers["NETWORK_DISCONNECTED"] = Events.on("NETWORK_DISCONNECTED", function()
        if state.isHost then
            return
        end

        clearSyncedWorldEntities()
        state.pendingWorldSnapshot = nil
        state.pendingSelfNetworkState = nil
    end)

    state.eventHandlers["NETWORK_SERVER_STOPPED"] = Events.on("NETWORK_SERVER_STOPPED", function()
        if state.isHost then
            return
        end

        clearSyncedWorldEntities()
        state.pendingWorldSnapshot = nil
        state.pendingSelfNetworkState = nil
    end)

    state.eventHandlers["NETWORK_SERVER_STARTED"] = Events.on("NETWORK_SERVER_STARTED", function()
        if not state.isHost or not state.world then
            return
        end

        broadcastHostWorldSnapshot()
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

        Session.handleWeaponRequest(request, data.playerId)
    end)

    state.eventHandlers["NETWORK_PLAYER_JOINED"] = Events.on("NETWORK_PLAYER_JOINED", function(data)
        if state.isHost then
            if not state.isMultiplayer and state.networkManager and state.networkManager:isHost() then
                Session.setMode(true, true)
            end
            if state.networkManager and state.networkManager:isHost() then
                broadcastHostWorldSnapshot(data and data.peer)
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
        applySelfNetworkStateIfAvailable()
    end)

    state.worldSyncHandlersRegistered = true
end

function Session.load(opts)
    opts = opts or {}

    state.syncedWorldEntities = {}
    state.pendingWorldSnapshot = nil
    state.pendingSelfNetworkState = nil
    state.worldSyncHandlersRegistered = false
    -- Clear world snapshot cache on load
    invalidateWorldSnapshotCache()

    if state.networkManager then
        state.networkManager:leaveGame()
    end

    state.networkManager = NetworkManager.new()

    Session.setMode(opts.multiplayer == true, opts.isHost == true)

    if state.isMultiplayer then
        if state.isHost then
            if not state.networkManager:startHost() then
                Session.setMode(false, false)
                return false, "start_failed"
            end
        else
            local connection = opts.pendingConnection
            if not connection then
                Session.setMode(false, false)
                return false, "No pending connection details found."
            end

            local ok, err = state.networkManager:joinGame(connection.address, connection.port, connection.username)
            if not ok then
                Session.setMode(false, false)
                return false, err
            end
        end
    end

    registerWorldSyncEventHandlers()
    return true
end

function Session.update(dt, context)
    if context then
        Session.setContext(context)
    end

    if state.networkManager then
        state.networkManager:update(dt)
    end

    applySelfNetworkStateIfAvailable()
end

function Session.setContext(context)
    context = context or {}

    if context.world and context.world ~= state.world then
        state.world = context.world
        state.syncedWorldEntities = {}
        if state.pendingWorldSnapshot then
            queueWorldSnapshot(state.pendingWorldSnapshot)
        end
    end

    if context.player ~= nil then
        state.player = context.player
        applySelfNetworkStateIfAvailable()
    end

    if context.hub ~= nil then
        state.hub = context.hub
    end
end

function Session.applySnapshot(snapshot)
    queueWorldSnapshot(snapshot)
end

function Session.handleWeaponRequest(request, playerId)
    if not request then
        return
    end

    if request.type == "beam_weapon_fire_request" then
        handleBeamRequest(request, playerId)
    elseif request.type == "utility_beam_weapon_fire_request" then
        handleUtilityBeamRequest(request, playerId)
    else
        handleProjectileRequest(request, playerId)
    end
end

function Session.toggleHosting()
    local manager = state.networkManager
    if not manager then
        return false, "no_network"
    end

    if manager:isMultiplayer() then
        if manager:isHost() then
            manager:leaveGame()
            Session.setMode(false, false)
            return true, "lan_closed"
        else
            manager:leaveGame()
            Session.setMode(false, false)
            return true, "client_left"
        end
    end

    Session.setMode(true, true)

    if not manager:startHost() then
        Session.setMode(false, false)
        return false, "start_failed"
    end

    registerWorldSyncEventHandlers()
    return true, "lan_opened"
end

function Session.setupEventHandlers()
    -- Only setup network manager listeners if not already registered
    if state.networkManager and state.networkManager.setupEventListeners and not state.networkManagerListenersRegistered then
        state.networkManager:setupEventListeners()
        state.networkManagerListenersRegistered = true
    end
    registerWorldSyncEventHandlers()
end

function Session.resetEventHandlers()
    state.worldSyncHandlersRegistered = false
    state.networkManagerListenersRegistered = false
end

function Session.teardown()
    clearSyncedWorldEntities()
    clearEventHandlers()

    if state.networkManager then
        state.networkManager:leaveGame()
        state.networkManager = nil
    end

    state.isMultiplayer = false
    state.isHost = false
    state.world = nil
    state.player = nil
    state.hub = nil
    state.pendingWorldSnapshot = nil
    state.pendingSelfNetworkState = nil
    state.worldSyncHandlersRegistered = false
    state.networkManagerListenersRegistered = false
    -- Clear world snapshot cache
    invalidateWorldSnapshotCache()
end

function Session.setMode(multiplayer, host)
    state.isMultiplayer = multiplayer and true or false
    state.isHost = host and true or false
end

function Session.isMultiplayer()
    return state.isMultiplayer
end

function Session.isHost()
    return state.isHost
end

function Session.getManager()
    return state.networkManager
end

function Session.getHub()
    return state.hub
end

function Session.getPendingSelfNetworkState()
    return state.pendingSelfNetworkState
end

function Session.invalidateWorldSnapshotCache()
    invalidateWorldSnapshotCache()
end

return Session
