--[[
    Network Client
    Minimal ENet client that exchanges player state snapshots with the host.
]]

local Log = require("src.core.log")
local Events = require("src.core.events")
local Messages = require("src.core.network.messages")

local TYPES = Messages.TYPES

local NetworkClient = {}
NetworkClient.__index = NetworkClient

local function sanitiseState(state)
    if type(state) ~= "table" then
        return nil
    end

    local position = state.position or {}
    local velocity = state.velocity or {}
    local thrusterState = state.thrusterState or {}
    local timestamp = tonumber(state.timestamp)
    local updateInterval = tonumber(state.updateInterval)

    return {
        position = {
            x = tonumber(position.x) or 0,
            y = tonumber(position.y) or 0,
            angle = tonumber(position.angle) or 0
        },
        velocity = {
            x = tonumber(velocity.x) or 0,
            y = tonumber(velocity.y) or 0
        },
        health = state.health,
        shieldChannel = state.shieldChannel == true,
        name = state.name,
        thrusterState = {
            isThrusting = thrusterState.isThrusting == true,
            forward = math.max(0, math.min(1, tonumber(thrusterState.forward) or 0)),
            reverse = math.max(0, math.min(1, tonumber(thrusterState.reverse) or 0)),
            strafeLeft = math.max(0, math.min(1, tonumber(thrusterState.strafeLeft) or 0)),
            strafeRight = math.max(0, math.min(1, tonumber(thrusterState.strafeRight) or 0)),
            boost = math.max(0, math.min(1, tonumber(thrusterState.boost) or 0))
        },
        timestamp = timestamp,
        updateInterval = updateInterval
    }
end

local function buildIndex(snapshot)
    local out = {}
    if type(snapshot) ~= "table" then
        return out
    end

    for _, entry in ipairs(snapshot) do
        if entry.playerId ~= nil and entry.state then
            out[entry.playerId] = {
                playerId = entry.playerId,
                name = entry.name,
                state = sanitiseState(entry.state) or {
                    position = { x = 0, y = 0, angle = 0 },
                    velocity = { x = 0, y = 0 }
                }
            }
        end
    end
    return out
end

local function now()
    if love and love.timer and love.timer.getTime then
        return love.timer.getTime()
    end

    return os.clock()
end

local function randomName()
    return string.format("Pilot_%d", love and love.timer and love.timer.getTime and math.floor(love.timer.getTime() * 1000) or os.time())
end

local function normaliseAddress(address)
    if type(address) ~= "string" then
        return "127.0.0.1"
    end

    local trimmed = address:match("^%s*(.-)%s*$")
    if trimmed == "" then
        return "127.0.0.1"
    end

    -- Allow IPv6 style [::1] inputs by trimming square brackets.
    trimmed = trimmed:gsub("^%[(.-)%]$", "%1")

    return trimmed
end

local function addAddressCandidate(candidates, value)
    for _, existing in ipairs(candidates) do
        if existing == value then
            return
        end
    end

    candidates[#candidates + 1] = value
end

local function buildAddressAttempts(address)
    local attempts = {}
    local normalised = normaliseAddress(address)
    local lowered = normalised:lower()

    local function prefer(value)
        if value then
            addAddressCandidate(attempts, value)
        end
    end

    if lowered == "localhost" or lowered == "127.0.0.1" or lowered == "::1" then
        prefer("127.0.0.1")
    else
        prefer(normalised)
    end

    return attempts
end

local function waitForConnection(transport, client, timeoutSeconds)
    local timeout = timeoutSeconds or 5
    local start = now()
    local queue = {}

    while now() - start < timeout do
        local event = transport.service(client, 10)
        if event then
            if event.type == "connect" then
                return true, queue
            elseif event.type == "disconnect" then
                return false, "Connection failed: Disconnected"
            else
                queue[#queue + 1] = event
            end
        end
    end

    return false, "Connection timed out"
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
    if not x or not y then
        return nil
    end

    local sanitised = {
        kind = tostring(entry.kind),
        id = tostring(entry.id),
        x = x,
        y = y
    }

    if entry.angle ~= nil then
        sanitised.angle = tonumber(entry.angle) or 0
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

function NetworkClient.new()
    local self = setmetatable({}, NetworkClient)

    self.transport = nil
    self.enetClient = nil
    self.playerId = nil
    self.players = {}
    self.connected = false
    self.connectionState = "disconnected" -- "disconnected", "connecting", "connected", "disconnecting"
    self.lastError = nil
    self.localName = randomName()
    self.worldSnapshot = nil
    self.connectionAttempts = 0
    self.maxConnectionAttempts = 3
    self.lastHeartbeat = 0
    self.heartbeatInterval = 5.0 -- seconds
    self.connectionTimeout = 12.0 -- seconds
    self.connectionGracePeriod = 3.0 -- seconds
    self.lastConnectionAttempt = 0
    self.lastReceiveTime = 0

    return self
end

function NetworkClient:isConnected()
    if not self.connected or not self.enetClient or self.connectionState ~= "connected" then
        return false
    end

    local currentTime = now()
    if self.lastReceiveTime > 0 and (currentTime - self.lastReceiveTime) <= (self.connectionTimeout + self.connectionGracePeriod) then
        return true
    end

    -- Check if the underlying ENet connection is still alive
    if self.enetClient.peer then
        local rtt = self.enetClient.peer:round_trip_time()
        if rtt and rtt > 0 then
            return true
        end
    end
    
    return false
end

function NetworkClient:getConnectionState()
    return self.connectionState
end

function NetworkClient:canAttemptConnection()
    local currentTime = now()
    return self.connectionAttempts < self.maxConnectionAttempts and 
           (currentTime - self.lastConnectionAttempt) >= 2.0 -- 2 second cooldown between attempts
end

function NetworkClient:resetConnectionAttempts()
    self.connectionAttempts = 0
    self.lastConnectionAttempt = -1000 -- Set to far in the past to bypass cooldown
    self.lastError = nil
end

function NetworkClient:getPlayers()
    return self.players
end

function NetworkClient:getWorldSnapshot()
    return self.worldSnapshot
end

function NetworkClient:getPing()
    if self.enetClient and self.enetClient.peer then
        return self.enetClient.peer:round_trip_time() or 0
    end
    return 0
end

function NetworkClient:getLastError()
    return self.lastError
end

function NetworkClient:connect(address, port)
    if self:isConnected() then
        return true
    end

    -- Reset connection attempts if enough time has passed since last attempt
    local currentTime = now()
    if (currentTime - self.lastConnectionAttempt) > 5.0 then -- 5 second reset window
        self.connectionAttempts = 0
    end

    -- Check if we can attempt connection (but don't update lastConnectionAttempt yet)
    if self.connectionAttempts >= self.maxConnectionAttempts then
        self.lastError = "Maximum connection attempts reached"
        return false, self.lastError
    end

    -- Check cooldown period
    if (currentTime - self.lastConnectionAttempt) < 2.0 then
        self.lastError = "Connection cooldown active"
        return false, self.lastError
    end

    self.connectionState = "connecting"
    self.connectionAttempts = self.connectionAttempts + 1
    self.lastConnectionAttempt = currentTime
    self.lastError = nil

    local ok, EnetTransport = pcall(require, "src.core.network.transport.enet")
    if not ok or not EnetTransport or not EnetTransport.isAvailable() then
        self.lastError = "ENet transport not available"
        self.connectionState = "disconnected"
        return false, self.lastError
    end

    local Constants = require("src.core.constants")
    local portToUse = tonumber(port) or Constants.NETWORK.DEFAULT_PORT
    local attempts = buildAddressAttempts(address or "localhost")
    local connectedClient = nil
    local lastError = nil
    local finalAddress = nil

    for _, target in ipairs(attempts) do
        local client, err = EnetTransport.createClient()
        if not client then
            lastError = err
            break
        end

        local peer, connectErr = EnetTransport.connect(client, target, portToUse)
        if not peer then
            lastError = connectErr
            EnetTransport.destroy(client)
        else
            local okConnect, result = waitForConnection(EnetTransport, client, self.connectionTimeout)
            if okConnect then
                connectedClient = client
                finalAddress = target
                lastError = nil
                break
            else
                lastError = result
                EnetTransport.disconnectClient(client)
                EnetTransport.destroy(client)
            end
        end
    end

    if not connectedClient then
        self.lastError = lastError or "Connection failed"
        self.connectionState = "disconnected"
        return false, self.lastError
    end

    -- Set up connection state
    self.transport = EnetTransport
    self.enetClient = connectedClient
    self.connected = true
    self.connectionState = "connected"
    self.players = {}
    self.lastError = nil
    self.connectionAttempts = 0 -- Reset on successful connection
    local connectedAt = now()
    self.lastHeartbeat = connectedAt
    self.lastReceiveTime = connectedAt


    -- Send initial HELLO message immediately after connection
    self:_send({
        type = TYPES.HELLO,
        name = self.localName,
        state = {
            position = { x = 0, y = 0, angle = 0 },
            velocity = { x = 0, y = 0 }
        }
    })

    -- Emit connected event only once
    Events.emit("NETWORK_CONNECTED")

    return true
end

function NetworkClient:_send(payload)
    if not self:isConnected() then
        return
    end

    local encoded = Messages.encode(payload)
    if not encoded then
        return
    end

    local ok, err = self.transport.send(self.enetClient, encoded, 0, true)
    if not ok then
    end
end

function NetworkClient:disconnect()
    if not self.connected then
        return
    end

    self.connectionState = "disconnecting"

    -- Send goodbye message if we have a valid connection
    if self.enetClient and self.playerId then
        self:_send({ type = TYPES.GOODBYE, playerId = self.playerId })
    end

    -- Clean up transport
    if self.transport and self.enetClient then
        self.transport.disconnectClient(self.enetClient)
        self.transport.destroy(self.enetClient)
    end

    -- Reset state
    self.transport = nil
    self.enetClient = nil
    self.connected = false
    self.connectionState = "disconnected"
    self.playerId = nil
    self.players = {}
    self.worldSnapshot = nil
    self.connectionAttempts = 0
    self.lastReceiveTime = 0

    Events.emit("NETWORK_DISCONNECTED")
end

function NetworkClient:_sendHeartbeat()
    if not self:isConnected() then
        return
    end

    self:_send({
        type = TYPES.PING,
        timestamp = now()
    })
end

function NetworkClient:update(dt)
    if not self.connected or not self.enetClient then
        return
    end

    -- Check connection health
    if self.connectionState == "connected" then
        local currentTime = now()
        if (currentTime - self.lastHeartbeat) > self.heartbeatInterval then
            self:_sendHeartbeat()
            self.lastHeartbeat = currentTime
        end

        if self.lastReceiveTime > 0 and (currentTime - self.lastReceiveTime) > (self.connectionTimeout + self.connectionGracePeriod) then
            self.lastError = "Timed out waiting for server update"
            self:disconnect()
            return
        end
    end

    local event = self.transport.service(self.enetClient, 0)
    while event do
        if event.type == "connect" then
            -- Connection event should only happen during initial connection
            -- Don't send HELLO again or emit NETWORK_CONNECTED again
        elseif event.type == "disconnect" then
            self:disconnect()
            return
        elseif event.type == "receive" then
            self.lastReceiveTime = now()
            local message = Messages.decode(event.data)
            if message then
                self:_handleMessage(message)
            end
        end

        event = self.transport.service(self.enetClient, 0)
    end
end

function NetworkClient:_handleMessage(message)
    if message.type == TYPES.WELCOME then
        self.playerId = message.playerId
        self.players = buildIndex(message.players)

        -- Handle world snapshot from welcome message
        if message.worldSnapshot then
            local snapshot = sanitiseWorldSnapshot(message.worldSnapshot)
            if snapshot then
                self.worldSnapshot = snapshot
                Events.emit("NETWORK_WORLD_SNAPSHOT", { snapshot = snapshot })
            end
        end

        local selfEntry = self.players and self.players[self.playerId]
        local selfState = nil
        if selfEntry and selfEntry.state then
            selfState = sanitiseState(selfEntry.state)
        elseif type(message.players) == "table" then
            -- Fallback: locate the raw snapshot entry if buildIndex filtered it out
            for _, entry in ipairs(message.players) do
                if entry.playerId == self.playerId then
                    selfState = sanitiseState(entry.state)
                    break
                end
            end
        end

        selfState = selfState or {
            position = { x = 0, y = 0, angle = 0 },
            velocity = { x = 0, y = 0 }
        }

        Events.emit("NETWORK_PLAYER_JOINED", {
            playerId = self.playerId,
            isSelf = true,
            playerName = self.localName,
            data = selfState
        })

        for _, entry in ipairs(message.players or {}) do
            if entry.playerId ~= self.playerId then
                Events.emit("NETWORK_PLAYER_JOINED", {
                    playerId = entry.playerId,
                    playerName = entry.name,
                    data = sanitiseState(entry.state)
                })
            end
        end

    elseif message.type == TYPES.STATE then
        if message.playerId == self.playerId then
            return
        end

        if not self.players[message.playerId] then
            self.players[message.playerId] = {
                playerId = message.playerId,
                name = message.name or string.format("Player %s", tostring(message.playerId)),
                state = sanitiseState(message.state) or {
                    position = { x = 0, y = 0, angle = 0 },
                    velocity = { x = 0, y = 0 }
                }
            }
        else
            self.players[message.playerId].state = sanitiseState(message.state) or self.players[message.playerId].state
        end

        Events.emit("NETWORK_PLAYER_UPDATED", {
            playerId = message.playerId,
            data = self.players[message.playerId].state,
            playerName = self.players[message.playerId].name
        })
    elseif message.type == TYPES.GOODBYE then
        self.players[message.playerId] = nil
        Events.emit("NETWORK_PLAYER_LEFT", { playerId = message.playerId })
    elseif message.type == TYPES.WORLD_SNAPSHOT then
        local snapshot = sanitiseWorldSnapshot(message.snapshot)
        if snapshot then
            self.worldSnapshot = snapshot
            Events.emit("NETWORK_WORLD_SNAPSHOT", { snapshot = snapshot })
        end
    elseif message.type == TYPES.ENEMY_UPDATE then
        -- Handle enemy updates from host
        Events.emit("NETWORK_ENEMY_UPDATE", { enemies = message.enemies })
    elseif message.type == TYPES.PROJECTILE_UPDATE then
        -- Handle projectile updates from host
        Events.emit("NETWORK_PROJECTILE_UPDATE", { projectiles = message.projectiles })
    elseif message.type == TYPES.PONG then
        -- Handle pong response for heartbeat
        -- RTT calculation could be added here if needed
    end
end

function NetworkClient:sendPlayerUpdate(state)
    if not self:isConnected() then
        return
    end

    self:_send({
        type = TYPES.STATE,
        playerId = self.playerId,
        state = sanitiseState(state)
    })
end

function NetworkClient:sendWeaponFireRequest(requestData)
    if not self:isConnected() then
        return
    end

    self:_send({
        type = TYPES.WEAPON_FIRE_REQUEST,
        playerId = self.playerId,
        request = requestData
    })
end

return NetworkClient
