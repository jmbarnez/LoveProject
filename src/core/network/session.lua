local NetworkManager = require("src.core.network.manager")
local SessionWorldSync = require("src.core.network.session_world_sync")
local NetworkWeaponHandler = require("src.systems.combat.network_weapon_handler")

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
    eventHandlers = {},
    cachedWorldSnapshot = nil,
    lastWorldSnapshotTime = 0,
    worldSnapshotCacheTimeout = 10.0,
    lastWorldSnapshotHash = nil,
    worldSnapshotSendInterval = 2.0,
    lastWorldSnapshotSend = 0
}

local function worldSyncCallbacks()
    return {
        setMode = function(multiplayer, host)
            Session.setMode(multiplayer, host)
        end,
        handleWeaponRequest = function(request, playerId)
            Session.handleWeaponRequest(request, playerId)
        end,
    }
end

function Session.setMode(multiplayer, host)
    state.isMultiplayer = multiplayer and true or false
    state.isHost = host and true or false
end

function Session.load(opts)
    opts = opts or {}

    state.syncedWorldEntities = {}
    state.pendingWorldSnapshot = nil
    state.pendingSelfNetworkState = nil
    state.worldSyncHandlersRegistered = false
    state.eventHandlers = {}

    SessionWorldSync.invalidateCache(state)

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

    SessionWorldSync.registerEventHandlers(state, worldSyncCallbacks())

    return true
end

function Session.update(dt, context)
    if context then
        Session.setContext(context)
    end

    if state.networkManager then
        state.networkManager:update(dt)
    end

    SessionWorldSync.applySelfNetworkState(state)

    if state.isHost and state.networkManager and state.networkManager:isHost() then
        SessionWorldSync.broadcastHostWorldSnapshot(state)
    end
end

function Session.setContext(context)
    context = context or {}

    if context.world and context.world ~= state.world then
        state.world = context.world
        SessionWorldSync.onWorldUpdated(state)
    end

    if context.player ~= nil then
        state.player = context.player
        SessionWorldSync.applySelfNetworkState(state)
    end

    if context.hub ~= nil then
        state.hub = context.hub
    end
end

function Session.applySnapshot(snapshot)
    SessionWorldSync.queueWorldSnapshot(state, snapshot)
end

function Session.handleWeaponRequest(request, playerId)
    NetworkWeaponHandler.handle(state, request, playerId, SessionWorldSync.resolvePlayerEntityForRequest)
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

    SessionWorldSync.registerEventHandlers(state, worldSyncCallbacks())
    return true, "lan_opened"
end

function Session.setupEventHandlers()
    if state.networkManager and state.networkManager.setupEventListeners and not state.networkManagerListenersRegistered then
        state.networkManager:setupEventListeners()
        state.networkManagerListenersRegistered = true
    end
    SessionWorldSync.registerEventHandlers(state, worldSyncCallbacks())
end

function Session.resetEventHandlers()
    SessionWorldSync.clearEventHandlers(state)
    state.networkManagerListenersRegistered = false
end

function Session.teardown()
    SessionWorldSync.clearSyncedWorldEntities(state)
    SessionWorldSync.clearEventHandlers(state)

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
    state.lastWorldSnapshotHash = nil

    SessionWorldSync.invalidateCache(state)
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
    SessionWorldSync.invalidateCache(state)
end

return Session

