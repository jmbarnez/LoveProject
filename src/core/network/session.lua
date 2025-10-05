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
        Log.warn("applyWorldSnapshot: missing snapshot or world", snapshot ~= nil, world ~= nil)
        return
    end

    Log.info("applyWorldSnapshot: applying snapshot with", #(snapshot.entities or {}), "entities")
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
            Log.warn("Failed to spawn world entity from snapshot", tostring(entry.kind), tostring(entry.id))
        end
    end
end

local function queueWorldSnapshot(snapshot)
    if not snapshot then
        return
    end

    if not state.world then
        state.pendingWorldSnapshot = Util.deepCopy(snapshot)
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

    local snapshot = {
        width = world.width or 0,
        height = world.height or 0,
        entities = {},
    }

    for _, entity in pairs(world:getEntities()) do
        local components = entity.components or {}
        local position = components.position

        if position and not entity.isPlayer and not entity.isRemotePlayer and not entity.isSyncedEntity then
            local entry = nil

            if entity.isStation or components.station then
                local station = components.station or {}
                entry = {
                    kind = "station",
                    id = station.type or "station",
                    x = position.x or 0,
                    y = position.y or 0,
                }
            elseif entity.type == "world_object" or components.mineable or components.interactable then
                local subtype = entity.subtype or (components.renderable and components.renderable.type) or "world_object"
                entry = {
                    kind = "world_object",
                    id = subtype,
                    x = position.x or 0,
                    y = position.y or 0,
                }
            end

            if entry then
                if position.angle ~= nil then
                    entry.angle = position.angle
                end

                snapshot.entities[#snapshot.entities + 1] = entry
            end
        end
    end

    return snapshot
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
        Log.warn("Failed to resolve player for weapon fire request", playerId)
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

    Log.info(
        "Creating projectile for player",
        playerId,
        "projectileId=" .. projectileId,
        "at position",
        request.position and request.position.x,
        request.position and request.position.y
    )

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
        Log.warn("Failed to create projectile from weapon fire request", playerId, projectileId)
    end
end

local function handleBeamRequest(request, playerId)
    local world = state.world
    if not world or not request then
        return
    end

    local player = resolvePlayerEntityForRequest(playerId)
    if not player then
        Log.warn("Failed to resolve player for beam weapon fire request", playerId)
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
        Log.warn("Failed to resolve player for utility beam weapon fire request", playerId)
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

local function registerWorldSyncEventHandlers()
    if state.worldSyncHandlersRegistered then
        return
    end

    Events.on("NETWORK_WORLD_SNAPSHOT", function(data)
        if state.isHost then
            return
        end

        local snapshot = data and data.snapshot or nil
        if snapshot then
            queueWorldSnapshot(snapshot)
        end
    end)

    Events.on("NETWORK_DISCONNECTED", function()
        if state.isHost then
            return
        end

        clearSyncedWorldEntities()
        state.pendingWorldSnapshot = nil
        state.pendingSelfNetworkState = nil
    end)

    Events.on("NETWORK_SERVER_STOPPED", function()
        if state.isHost then
            return
        end

        clearSyncedWorldEntities()
        state.pendingWorldSnapshot = nil
        state.pendingSelfNetworkState = nil
    end)

    Events.on("NETWORK_SERVER_STARTED", function()
        if not state.isHost or not state.world then
            return
        end

        broadcastHostWorldSnapshot()
    end)

    Events.on("NETWORK_ENEMY_UPDATE", function(data)
        if state.isHost then
            return
        end

        local enemies = data and data.enemies or nil
        if enemies then
            RemoteEnemySync.applyEnemySnapshot(enemies, state.world)
        end
    end)

    Events.on("NETWORK_PROJECTILE_UPDATE", function(data)
        if state.isHost then
            return
        end

        local projectiles = data and data.projectiles or nil
        if projectiles then
            RemoteProjectileSync.applyProjectileSnapshot(projectiles, state.world)
        end
    end)

    Events.on("NETWORK_WEAPON_FIRE_REQUEST", function(data)
        if not state.isHost then
            return
        end

        local request = data and data.request or nil
        if not request then
            return
        end

        Session.handleWeaponRequest(request, data.playerId)
    end)

    Events.on("NETWORK_PLAYER_JOINED", function(data)
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
            Log.warn("NETWORK_PLAYER_JOINED: Failed to sanitize state")
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

    if state.networkManager then
        state.networkManager:leaveGame()
    end

    state.networkManager = NetworkManager.new()

    Session.setMode(opts.multiplayer == true, opts.isHost == true)

    if state.isMultiplayer then
        if state.isHost then
            if not state.networkManager:startHost() then
                Log.error("Failed to start LAN host")
                Session.setMode(false, false)
                return false, "start_failed"
            end
        else
            local connection = opts.pendingConnection
            if not connection then
                Log.error("No pending connection details found for client mode")
                Session.setMode(false, false)
                return false, "No pending connection details found."
            end

            Log.info("Attempting connection to server from start screen parameters")
            Log.info("Connection details:", connection.address, connection.port)
            local ok, err = state.networkManager:joinGame(connection.address, connection.port)
            Log.info("Connection result:", ok, err)
            if not ok then
                Log.error("Failed to connect to server", err)
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
        Log.error("toggleLanHosting called without network manager")
        return false, "no_network"
    end

    if manager:isMultiplayer() then
        if manager:isHost() then
            Log.info("Stopping LAN hosting session")
            manager:leaveGame()
            Session.setMode(false, false)
            return true, "lan_closed"
        else
            Log.info("Leaving multiplayer session before enabling LAN host")
            manager:leaveGame()
            Session.setMode(false, false)
            return true, "client_left"
        end
    end

    Log.info("Starting LAN host from single-player session")
    Session.setMode(true, true)

    if not manager:startHost() then
        Log.error("Failed to start LAN host")
        Session.setMode(false, false)
        return false, "start_failed"
    end

    registerWorldSyncEventHandlers()
    return true, "lan_opened"
end

function Session.setupEventHandlers()
    if state.networkManager and state.networkManager.setupEventListeners then
        state.networkManager:setupEventListeners()
    end
    registerWorldSyncEventHandlers()
end

function Session.resetEventHandlers()
    state.worldSyncHandlersRegistered = false
end

function Session.teardown()
    clearSyncedWorldEntities()

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
end

function Session.setMode(multiplayer, host)
    state.isMultiplayer = multiplayer and true or false
    state.isHost = host and true or false
    Log.info(
        "Network session mode set:",
        "multiplayer=" .. tostring(state.isMultiplayer),
        "host=" .. tostring(state.isHost)
    )
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

return Session
