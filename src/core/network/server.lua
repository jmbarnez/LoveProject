--[[
    Network Server
    Simplified authoritative host that tracks connected clients and republishes
    lightweight player state for remote visualisation.
]]

local Log = require("src.core.log")
local Events = require("src.core.events")
local Messages = require("src.core.network.messages")
local Utils = require("src.core.network.server.utils")
local Sanitizers = require("src.core.network.server.sanitizers")

local TYPES = Messages.TYPES

local NetworkServer = {}
NetworkServer.__index = NetworkServer

local now = Utils.now
local simpleHash = Utils.simpleHash
local canonicalPlayerId = Utils.canonicalPlayerId
local buildSnapshot = Utils.buildSnapshot

local sanitiseState = Sanitizers.sanitisePlayerState
local sanitiseWorldSnapshot = Sanitizers.sanitiseWorldSnapshot
local sanitiseEnemySnapshot = Sanitizers.sanitiseEnemySnapshot
local sanitiseProjectileSnapshot = Sanitizers.sanitiseProjectileSnapshot

function NetworkServer.new(port)
    local self = setmetatable({}, NetworkServer)
    local Constants = require("src.core.constants")

    self.port = port or Constants.NETWORK.DEFAULT_PORT
    self.isRunning = false
    self.transport = nil
    self.enetServer = nil

    self.players = {}
    self.peers = {}
    self.peerToPlayer = {}
    self.nextPlayerId = 1
    self.events = {}
    self.worldSnapshot = nil
    
    -- Performance optimization: Message caching to avoid re-encoding
    self._messageCache = {}
    self._lastMessageHashes = {}

    return self
end

local function pushEvent(self, kind, payload)
    self.events[#self.events + 1] = {
        type = kind,
        payload = payload or {}
    }
end

function NetworkServer:start()
    if self.isRunning then
        return true
    end

    local ok, EnetTransport = pcall(require, "src.core.network.transport.enet")
    if not ok or not EnetTransport or not EnetTransport.isAvailable() then
        return false
    end

    local host, err = EnetTransport.createServer(self.port)
    if not host then
        return false
    end

    self.transport = EnetTransport
    self.enetServer = host
    self.isRunning = true
    self.peers = {}
    
    -- Initialize with empty world snapshot
    self.worldSnapshot = {
        entities = {}
    }
    self.peerToPlayer = {}
    self.players = {}
    self.nextPlayerId = 1
    self.events = {}

    Events.emit("NETWORK_SERVER_STARTED", { port = self.port })
    return true
end

function NetworkServer:stop()
    if not self.isRunning then
        return
    end

    if self.transport and self.enetServer then
        self.transport.destroy(self.enetServer)
    end

    self.transport = nil
    self.enetServer = nil
    self.isRunning = false
    self.players = {}
    self.peers = {}
    self.peerToPlayer = {}
    self.nextPlayerId = 1
    self.events = {}
    self.worldSnapshot = nil

    Events.emit("NETWORK_SERVER_STOPPED")
end

function NetworkServer:pullEvents()
    if #self.events == 0 then
        return {}
    end

    local events = self.events
    self.events = {}
    return events
end

function NetworkServer:update(dt)
    if not self.isRunning or not self.transport or not self.enetServer then
        return
    end
    
    -- Additional safety checks for ENet server
    if not self.enetServer.host then
        self:stop()
        return
    end

    -- Performance optimization: Use non-blocking poll to avoid frame drops
    -- Only use a small timeout for the first poll, then switch to non-blocking
    local pollTimeout = 0  -- Non-blocking to prevent FPS drops
    local ok, event = pcall(self.transport.service, self.enetServer, pollTimeout)
    if not ok then
        -- Don't stop the server on service errors, just log and continue
        return
    end

    while event do
        if event.type == "connect" then
            if event.peer then
                self.peers[event.peer] = true
            else
            end
        elseif event.type == "receive" then
            if event.peer and event.data then
                local message = Messages.decode(event.data)
                if message then
                    self:_handleMessage(event.peer, message)
                else
                end
            else
            end
        elseif event.type == "disconnect" then
            if event.peer then
                self:_handleDisconnect(event.peer)
            else
            end
        end

        -- Get next event with error handling (non-blocking)
        local ok2, nextEvent = pcall(self.transport.service, self.enetServer, 0)
        if ok2 then
            event = nextEvent
        else
            break
        end
    end
end

function NetworkServer:_handleMessage(peer, message)
    if not message or type(message) ~= "table" then
        return
    end

    if message.type == TYPES.HELLO then
        self:_handleHello(peer, message)
    elseif message.type == TYPES.STATE then
        self:_handleState(peer, message)
    elseif message.type == TYPES.GOODBYE then
        self:_handleDisconnect(peer)
    elseif message.type == TYPES.PING then
        self:_handlePing(peer, message)
    elseif message.type == TYPES.ENEMY_UPDATE then
        self:_handleEnemyUpdate(peer, message)
    elseif message.type == TYPES.WEAPON_FIRE_REQUEST then
        self:_handleWeaponFireRequest(peer, message)
    else
    end
end

function NetworkServer:_handleHello(peer, message)
    local playerId = self.nextPlayerId
    self.nextPlayerId = self.nextPlayerId + 1

    local name = message.name or string.format("Player %d", playerId)

    -- Generate a proper spawn position for the new client
    local spawnPosition = self:_generateSpawnPosition()

    self.players[playerId] = {
        playerId = playerId,
        name = name,
        state = {
            position = spawnPosition,
            velocity = { x = 0, y = 0 }
        },
        lastSeen = now()
    }

    self.peerToPlayer[peer] = playerId

    -- Force update host player state to ensure new client gets current health data
    -- Get current host player state from the game
    local Game = require("src.game")
    local world = Game.world
    local hostPlayer = world and world:getPlayer()
    if hostPlayer and hostPlayer.components then
        local position = hostPlayer.components.position
        local velocity = hostPlayer.components.velocity
        local hull = hostPlayer.components.hull
        local shield = hostPlayer.components.shield
        
        
        local currentState = {
            position = position and { x = position.x, y = position.y, angle = position.angle or 0 } or { x = 0, y = 0, angle = 0 },
            velocity = velocity and { x = velocity.x or 0, y = velocity.y or 0 } or { x = 0, y = 0 },
            health = health and {
                hp = health.hp or 100,
                maxHP = health.maxHP or 100,
                shield = health.shield or 0,
                maxShield = health.maxShield or 0,
                energy = health.energy or 0,
                maxEnergy = health.maxEnergy or 0
            } or { hp = 100, maxHP = 100, shield = 0, maxShield = 0, energy = 0, maxEnergy = 0 },
            shieldChannel = hostPlayer.shieldChannel or false
        }
        
        self:updateHostState(currentState)
    end

    local welcomePayload = {
        type = TYPES.WELCOME,
        playerId = playerId,
        players = buildSnapshot(self.players),
        worldSnapshot = self.worldSnapshot
    }

    local welcome = Messages.encode(welcomePayload)
    self.transport.send({ peer = peer }, welcome, 0, true)

    local broadcast = Messages.encode({
        type = TYPES.STATE,
        playerId = playerId,
        state = self.players[playerId].state,
        name = name
    })
    self:_broadcastExcept(peer, broadcast)

    pushEvent(self, "joined", {
        playerId = playerId,
        name = name,
        state = self.players[playerId].state
    })

    Events.emit("NETWORK_PLAYER_JOINED", {
        playerId = playerId,
        playerName = name,
        data = self.players[playerId].state,
        peer = peer
    })

end

function NetworkServer:_handleState(peer, message)
    local playerId = canonicalPlayerId(message.playerId or self.peerToPlayer[peer])
    if not playerId or not self.players[playerId] then
        return
    end

    self.players[playerId].state = sanitiseState(message.state or {})
    self.players[playerId].lastSeen = now()

    local encoded = Messages.encode({
        type = TYPES.STATE,
        playerId = playerId,
        state = self.players[playerId].state,
        name = self.players[playerId].name
    })

    self:_broadcastExcept(peer, encoded)

    pushEvent(self, "state", {
        playerId = playerId,
        state = self.players[playerId].state,
        name = self.players[playerId].name
    })

    Events.emit("NETWORK_PLAYER_UPDATED", {
        playerId = playerId,
        data = self.players[playerId].state,
        playerName = self.players[playerId].name
    })
end

function NetworkServer:_handleDisconnect(peer)
    local playerId = self.peerToPlayer[peer]
    if not playerId then
        return
    end

    local player = self.players[playerId]
    self.players[playerId] = nil
    self.peerToPlayer[peer] = nil
    self.peers[peer] = nil

    local encoded = Messages.encode({
        type = TYPES.GOODBYE,
        playerId = playerId
    })
    self:_broadcastExcept(peer, encoded)

    pushEvent(self, "left", { playerId = playerId })

    Events.emit("NETWORK_PLAYER_LEFT", {
        playerId = playerId,
        playerName = player and player.name or nil
    })

end

function NetworkServer:_handlePing(peer, message)
    -- Respond to ping with pong
    local pongMessage = Messages.encode({
        type = TYPES.PONG,
        timestamp = message.timestamp
    })
    
    if pongMessage then
        local ok, err = self.transport.send({ peer = peer }, pongMessage, 0, true)
        if not ok then
        end
    end
end

function NetworkServer:_handleEnemyUpdate(peer, message)
    -- For now, just log that we received an enemy update
    -- In a full implementation, this might be used for client-side prediction
    -- or validation, but for host-authoritative mode, we ignore client enemy updates
end

function NetworkServer:_handleWeaponFireRequest(peer, message)
    -- Handle weapon fire requests from clients
    local playerId = self.peerToPlayer[peer]
    if not playerId then
        return
    end

    local request = message.request
    if not request then
        return
    end

    local json = require("src.libs.json")

    -- Emit event for the game to handle the weapon fire request
    Events.emit("NETWORK_WEAPON_FIRE_REQUEST", {
        playerId = playerId,
        request = request
    })
end

function NetworkServer:_broadcastExcept(excludedPeer, data)
    if not data then
        return
    end

    -- Performance optimization: Batch peer operations and use cached data
    local peersToSend = {}
    local peerCount = 0
    
    -- Collect peers to send to (avoid modifying table during iteration)
    for peer in pairs(self.peers) do
        if peer ~= excludedPeer then
            peerCount = peerCount + 1
            peersToSend[peerCount] = peer
        end
    end
    
    -- Send to all peers in batch
    for i = 1, peerCount do
        local peer = peersToSend[i]
        local ok, err = self.transport.send({ peer = peer }, data, 0, true)
        if not ok then
            -- Remove failed peer from active peers
            self.peers[peer] = nil
        end
    end
end

-- Optimized broadcast method with message caching
function NetworkServer:_broadcastCached(excludedPeer, messageData, cacheKey)
    if not messageData then
        return
    end

    -- Check if we have a cached version of this message
    local messageHash = simpleHash(messageData)
    local cachedData = self._messageCache[cacheKey]
    
    if cachedData and self._lastMessageHashes[cacheKey] == messageHash then
        -- Use cached encoded data
        self:_broadcastExcept(excludedPeer, cachedData)
        return
    end
    
    -- Encode and cache the message
    local encoded = Messages.encode(messageData)
    if encoded then
        self._messageCache[cacheKey] = encoded
        self._lastMessageHashes[cacheKey] = messageHash
        self:_broadcastExcept(excludedPeer, encoded)
    end
end

function NetworkServer:getPlayers()
    return self.players
end

function NetworkServer:getPlayerCount()
    local count = 0
    for _ in pairs(self.players) do
        count = count + 1
    end
    return count
end

function NetworkServer:_generateSpawnPosition()
    -- Generate a spawn position outside station limits
    -- This should match the logic used in game.lua for player spawning
    local Constants = require("src.core.constants")
    
    -- Default hub position (matches game.lua hub creation at 5000, 5000)
    local hubX = 5000
    local hubY = 5000
    
    -- Try to get hub position from world snapshot if available
    if self.worldSnapshot and self.worldSnapshot.entities then
        for _, entity in ipairs(self.worldSnapshot.entities) do
            local kind = entity.kind or entity.type
            if kind == "hub_station" then
                local x = entity.x
                local y = entity.y

                if not (type(x) == "number" and type(y) == "number") and entity.position then
                    x = entity.position.x
                    y = entity.position.y
                end

                if type(x) == "number" and type(y) == "number" then
                    hubX = x
                    hubY = y
                    break
                end
            end
        end
    end
    
    -- Spawn outside the station weapons-disable zone
    -- Use the same logic as game.lua: get weapon disable radius from station or use default
    local weapon_disable_radius = 200 -- Default radius (matches game.lua fallback)
    
    -- Try to get the actual weapon disable radius from the hub station in world snapshot
    if self.worldSnapshot and self.worldSnapshot.entities then
        for _, entity in ipairs(self.worldSnapshot.entities) do
            local kind = entity.kind or entity.type
            if kind == "hub_station" then
                -- Hub stations typically have a weapon disable radius of around 200-300
                -- This matches the single-player logic that uses hub:getWeaponDisableRadius()
                weapon_disable_radius = 240 -- Reasonable default for hub station
                break
            end
        end
    end
    
    local spawn_dist = weapon_disable_radius * 1.2 -- Spawn 20% outside the weapon disable zone
    local angle = math.random() * math.pi * 2
    
    local px = hubX + math.cos(angle) * spawn_dist
    local py = hubY + math.sin(angle) * spawn_dist
    
    return { x = px, y = py, angle = 0 }
end

function NetworkServer:updateHostState(state)
    local hostId = 0
    if not self.players[hostId] then
        self.players[hostId] = {
            playerId = hostId,
            name = "Host",
            state = sanitiseState(state),
            lastSeen = now()
        }
    else
        self.players[hostId].state = sanitiseState(state)
        self.players[hostId].lastSeen = now()
    end

    pushEvent(self, "state", {
        playerId = hostId,
        state = self.players[hostId].state,
        name = self.players[hostId].name
    })

    local encoded = Messages.encode({
        type = TYPES.STATE,
        playerId = hostId,
        state = self.players[hostId].state,
        name = self.players[hostId].name
    })
    self:_broadcastExcept(nil, encoded)

    Events.emit("NETWORK_PLAYER_UPDATED", {
        playerId = hostId,
        data = self.players[hostId].state,
        playerName = self.players[hostId].name
    })
end

function NetworkServer:addHostPlayer(name, state)
    local hostId = 0
    self.players[hostId] = {
        playerId = hostId,
        name = name or "Host",
        state = sanitiseState(state),
        lastSeen = now()
    }

    pushEvent(self, "state", {
        playerId = hostId,
        state = self.players[hostId].state,
        name = self.players[hostId].name
    })
end

function NetworkServer:updateWorldSnapshot(snapshot, peer)
    if snapshot == nil then
        return
    end

    local sanitised = sanitiseWorldSnapshot(snapshot)
    if not sanitised then
        return
    end

    self.worldSnapshot = sanitised

    pushEvent(self, "world_snapshot", { snapshot = self.worldSnapshot })

    if self.transport then
        local encoded = Messages.encode({
            type = TYPES.WORLD_SNAPSHOT,
            snapshot = self.worldSnapshot
        })

        if encoded then
            if peer then
                self.transport.send({ peer = peer }, encoded, 0, true)
            else
                self:_broadcastExcept(nil, encoded)
            end
        end
    end

    Events.emit("NETWORK_WORLD_SNAPSHOT", { snapshot = self.worldSnapshot })
end

function NetworkServer:broadcastEnemyUpdate(enemyData)
    if not self.transport or not enemyData then
        return
    end

    -- Check if host authoritative enemies is enabled
    local Settings = require("src.core.settings")
    local networkingSettings = Settings.getNetworkingSettings()
    if not networkingSettings or not networkingSettings.host_authoritative_enemies then
        return
    end

    -- Sanitize enemy data before broadcasting
    local sanitizedEnemyData = sanitiseEnemySnapshot(enemyData)
    if not sanitizedEnemyData then
        return
    end

    -- Use cached broadcasting to avoid re-encoding identical messages
    local messageData = {
        type = TYPES.ENEMY_UPDATE,
        enemies = sanitizedEnemyData
    }
    
    self:_broadcastCached(nil, messageData, "enemy_update")

    -- Don't emit event to host - host already has the enemy data in its world
    -- Events.emit("NETWORK_ENEMY_UPDATE", { enemies = sanitizedEnemyData })
end

function NetworkServer:broadcastProjectileUpdate(projectileData)
    if not self.transport or not projectileData then
        return
    end

    -- Sanitize projectile data before broadcasting
    local sanitizedProjectileData = sanitiseProjectileSnapshot(projectileData)
    if not sanitizedProjectileData or #sanitizedProjectileData == 0 then
        return
    end

    -- Use cached broadcasting to avoid re-encoding identical messages
    local messageData = {
        type = TYPES.PROJECTILE_UPDATE,
        projectiles = sanitizedProjectileData
    }
    
    self:_broadcastCached(nil, messageData, "projectile_update")

    -- Don't emit event to host - host already has the projectile data in its world
    -- Events.emit("NETWORK_PROJECTILE_UPDATE", { projectiles = sanitizedProjectileData })
end

return NetworkServer
