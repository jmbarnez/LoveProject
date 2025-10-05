--[[
    Network Server
    Simplified authoritative host that tracks connected clients and republishes
    lightweight player state for remote visualisation.
]]

local Log = require("src.core.log")
local Events = require("src.core.events")
local Messages = require("src.core.network.messages")

local TYPES = Messages.TYPES

local NetworkServer = {}
NetworkServer.__index = NetworkServer

local function now()
    if love and love.timer and love.timer.getTime then
        return love.timer.getTime()
    end
    return os.clock()
end

local function canonicalPlayerId(id)
    if id == nil then
        return nil
    end
    if type(id) == "number" then
        return id
    end
    if tonumber(id) then
        return tonumber(id)
    end
    return id
end

local function sanitiseState(state)
    if type(state) ~= "table" then
        return {
            position = { x = 0, y = 0, angle = 0 },
            velocity = { x = 0, y = 0 },
            health = { hp = 100, maxHP = 100, shield = 0, maxShield = 0, energy = 0, maxEnergy = 0 }
        }
    end

    local position = state.position or {}
    local velocity = state.velocity or {}
    local health = state.health or {}

    return {
        name = state.name,
        position = {
            x = tonumber(position.x) or 0,
            y = tonumber(position.y) or 0,
            angle = tonumber(position.angle) or 0
        },
        velocity = {
            x = tonumber(velocity.x) or 0,
            y = tonumber(velocity.y) or 0
        },
        health = {
            hp = tonumber(health.hp) or 100,
            maxHP = tonumber(health.maxHP) or 100,
            shield = tonumber(health.shield) or 0,
            maxShield = tonumber(health.maxShield) or 0,
            energy = tonumber(health.energy) or 0,
            maxEnergy = tonumber(health.maxEnergy) or 0
        }
    }
end

local function buildSnapshot(players)
    local snapshot = {}
    for id, entry in pairs(players) do
        snapshot[#snapshot + 1] = {
            playerId = id,
            name = entry.name,
            state = entry.state
        }
    end
    return snapshot
end

local function sanitiseWorldExtras(extra)
    if type(extra) ~= "table" then
        return nil
    end

    local sanitised = {}
    for key, value in pairs(extra) do
        local valueType = type(value)
        if valueType == "number" or valueType == "string" or valueType == "boolean" then
            sanitised[key] = value
        end
    end

    if next(sanitised) then
        return sanitised
    end

    return nil
end

local function sanitiseWorldEntry(entry)
    if type(entry) ~= "table" then
        return nil
    end

    if not entry.kind or not entry.id then
        return nil
    end

    local x = tonumber(entry.x)
    local y = tonumber(entry.y)
    local angle = entry.angle

    if (not x or not y) and type(entry.position) == "table" then
        x = tonumber(entry.position.x) or x
        y = tonumber(entry.position.y) or y
        angle = angle ~= nil and angle or entry.position.angle
    end

    if not x or not y then
        return nil
    end

    local sanitised = {
        kind = tostring(entry.kind),
        id = tostring(entry.id),
        x = x,
        y = y
    }

    if angle ~= nil then
        sanitised.angle = tonumber(angle) or 0
    end

    local extra = sanitiseWorldExtras(entry.extra)
    if extra then
        sanitised.extra = extra
    end

    return sanitised
end

local function sanitiseWorldSnapshot(snapshot)
    if type(snapshot) ~= "table" then
        return nil
    end

    local width = tonumber(snapshot.width)
    local height = tonumber(snapshot.height)

    local sanitised = {
        entities = {}
    }

    if width ~= nil then
        sanitised.width = width
    end

    if height ~= nil then
        sanitised.height = height
    end

    if type(snapshot.entities) == "table" then
        for _, entry in ipairs(snapshot.entities) do
            local sanitisedEntry = sanitiseWorldEntry(entry)
            if sanitisedEntry then
                sanitised.entities[#sanitised.entities + 1] = sanitisedEntry
            end
        end
    end

    return sanitised
end

local function sanitiseEnemySnapshot(snapshot)
    if type(snapshot) ~= "table" then
        return {}
    end

    local sanitised = {}
    for _, enemy in ipairs(snapshot) do
        if type(enemy) == "table" and enemy.id and enemy.type then
            local sanitisedEnemy = {
                id = tostring(enemy.id),
                type = tostring(enemy.type),
                position = {
                    x = tonumber(enemy.position and enemy.position.x) or 0,
                    y = tonumber(enemy.position and enemy.position.y) or 0,
                    angle = tonumber(enemy.position and enemy.position.angle) or 0
                },
                velocity = {
                    x = tonumber(enemy.velocity and enemy.velocity.x) or 0,
                    y = tonumber(enemy.velocity and enemy.velocity.y) or 0
                }
            }

            -- Include health data if available
            if enemy.health then
                sanitisedEnemy.health = {
                    hp = tonumber(enemy.health.hp) or 100,
                    maxHP = tonumber(enemy.health.maxHP) or 100,
                    shield = tonumber(enemy.health.shield) or 0,
                    maxShield = tonumber(enemy.health.maxShield) or 0,
                    energy = tonumber(enemy.health.energy) or 0,
                    maxEnergy = tonumber(enemy.health.maxEnergy) or 0
                }
            end

            -- Include AI state if available
            if enemy.ai then
                sanitisedEnemy.ai = {
                    state = tostring(enemy.ai.state) or "patrolling",
                    target = enemy.ai.target or nil
                }
            end

            table.insert(sanitised, sanitisedEnemy)
        end
    end

    return sanitised
end

local function sanitiseProjectileSnapshot(snapshot)
    if type(snapshot) ~= "table" then
        return {}
    end

    local sanitised = {}
    for _, projectile in ipairs(snapshot) do
        if type(projectile) == "table" and projectile.id and projectile.type then
            local sanitisedProjectile = {
                id = tostring(projectile.id),
                type = tostring(projectile.type),
                position = {
                    x = tonumber(projectile.position and projectile.position.x) or 0,
                    y = tonumber(projectile.position and projectile.position.y) or 0,
                    angle = tonumber(projectile.position and projectile.position.angle) or 0
                },
                velocity = {
                    x = tonumber(projectile.velocity and projectile.velocity.x) or 0,
                    y = tonumber(projectile.velocity and projectile.velocity.y) or 0
                },
                friendly = projectile.friendly or false,
                sourceId = projectile.sourceId or nil,
                damage = projectile.damage or nil,
                kind = projectile.kind or "bullet",
                timed_life = projectile.timed_life or nil
            }

            -- Include damage data if available
            if projectile.damage then
                sanitisedProjectile.damage = {
                    min = tonumber(projectile.damage.min) or 1,
                    max = tonumber(projectile.damage.max) or 2,
                    skill = projectile.damage.skill or nil
                }
            end

            -- Include timed life data if available
            if projectile.timed_life then
                sanitisedProjectile.timed_life = {
                    duration = tonumber(projectile.timed_life.duration) or 2.0,
                    elapsed = tonumber(projectile.timed_life.elapsed) or 0
                }
            end

            table.insert(sanitised, sanitisedProjectile)
        end
    end

    return sanitised
end

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
        Log.error("ENet transport not available for server")
        return false
    end

    local host, err = EnetTransport.createServer(self.port)
    if not host then
        Log.error("Failed to create ENet server:", err)
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

    Log.info("Server started on port", self.port)
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

    Log.info("Server stopped")
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
        Log.error("Network server: ENet host is nil, stopping server")
        self:stop()
        return
    end

    -- Allow a small timeout for the first poll to avoid busy waiting when idle,
    -- but switch to non-blocking reads once we start draining the queue. This
    -- prevents the host from sleeping 10ms for every queued event which caused
    -- massive frame hitches when a lot of packets arrived in the same frame.
    local pollTimeout = 10
    local ok, event = pcall(self.transport.service, self.enetServer, pollTimeout)
    if not ok then
        Log.error("Network server service error:", event)
        -- Don't stop the server on service errors, just log and continue
        return
    end

    while event do
        if event.type == "connect" then
            if event.peer then
                self.peers[event.peer] = true
                Log.info("Peer connected")
            else
                Log.warn("Received connect event without peer")
            end
        elseif event.type == "receive" then
            if event.peer and event.data then
                local message = Messages.decode(event.data)
                if message then
                    self:_handleMessage(event.peer, message)
                else
                    Log.warn("Failed to decode message from peer")
                end
            else
                Log.warn("Received receive event without peer or data")
            end
        elseif event.type == "disconnect" then
            if event.peer then
                self:_handleDisconnect(event.peer)
            else
                Log.warn("Received disconnect event without peer")
            end
        end

        -- Get next event with error handling
        local ok2, nextEvent = pcall(self.transport.service, self.enetServer, 0)
        if ok2 then
            event = nextEvent
        else
            Log.error("Error getting next server event:", nextEvent)
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
        Log.warn("Received unknown message type:", message.type)
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

    Log.info("Player", name, "joined with id", playerId)
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

    Log.info("Player", playerId, "disconnected")
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
            Log.warn("Failed to send PONG response:", err)
        end
    end
end

function NetworkServer:_handleEnemyUpdate(peer, message)
    -- For now, just log that we received an enemy update
    -- In a full implementation, this might be used for client-side prediction
    -- or validation, but for host-authoritative mode, we ignore client enemy updates
    Log.debug("Received enemy update from peer (ignored in host-authoritative mode)")
end

function NetworkServer:_handleWeaponFireRequest(peer, message)
    -- Handle weapon fire requests from clients
    local playerId = self.peerToPlayer[peer]
    if not playerId then
        Log.warn("Received weapon fire request from unknown peer")
        return
    end

    local request = message.request
    if not request then
        Log.warn("Received weapon fire request without request data")
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

    for peer in pairs(self.peers) do
        if peer ~= excludedPeer then
            local ok, err = self.transport.send({ peer = peer }, data, 0, true)
            if not ok then
                Log.warn("Failed to broadcast to peer:", err)
            end
        end
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

    -- Sanitize enemy data before broadcasting
    local sanitizedEnemyData = sanitiseEnemySnapshot(enemyData)
    if not sanitizedEnemyData or #sanitizedEnemyData == 0 then
        return
    end

    local encoded = Messages.encode({
        type = TYPES.ENEMY_UPDATE,
        enemies = sanitizedEnemyData
    })

    if encoded then
        self:_broadcastExcept(nil, encoded)
    end

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

    local encoded = Messages.encode({
        type = TYPES.PROJECTILE_UPDATE,
        projectiles = sanitizedProjectileData
    })

    if encoded then
        self:_broadcastExcept(nil, encoded)
    end

    -- Don't emit event to host - host already has the projectile data in its world
    -- Events.emit("NETWORK_PROJECTILE_UPDATE", { projectiles = sanitizedProjectileData })
end

return NetworkServer
