--[[
    Network Client
    Handles client-side networking for multiplayer gameplay
]]

local Log = require("src.core.log")
local Events = require("src.core.events")
local json = require("src.libs.json")

local NetworkClient = {}
NetworkClient.__index = NetworkClient

-- Connection states
local CONNECTION_STATES = {
    DISCONNECTED = "disconnected",
    CONNECTING = "connecting",
    CONNECTED = "connected",
    ERROR = "error"
}

-- Message types
local MESSAGE_TYPES = {
    PLAYER_JOIN = "player_join",
    PLAYER_LEAVE = "player_leave",
    PLAYER_UPDATE = "player_update",
    PING = "ping",
    PONG = "pong"
}

local function currentTime()
    if love and love.timer and love.timer.getTime then
        return love.timer.getTime()
    end
    return os.clock()
end

local function randomPlayerName()
    -- Use timestamp, random number, and process ID to ensure uniqueness across instances
    local timestamp = os.time()
    local random = math.random(1000, 9999)
    local pid = (love and love.timer and love.timer.getTime and math.floor(love.timer.getTime() * 1000)) or math.random(100000, 999999)
    return "Player_" .. timestamp .. "_" .. random .. "_" .. pid
end

local function mergePlayerSnapshot(store, playerId, snapshot, playerName)
    if not playerId then
        return nil
    end

    local entry = store[playerId] or {}

    if snapshot then
        for key, value in pairs(snapshot) do
            entry[key] = value
        end
    end

    entry.playerId = entry.playerId or playerId
    if playerName then
        entry.playerName = playerName
    end

    store[playerId] = entry
    return entry
end

function NetworkClient.new()
    local self = setmetatable({}, NetworkClient)

    self.state = CONNECTION_STATES.DISCONNECTED
    self.serverAddress = "localhost"
    self.serverPort = 7777
    self.playerId = nil
    self.players = {}
    self.lastPingTime = 0
    self.ping = 0

    self.transport = "none"
    self.fileNetwork = nil
    self.pendingJoinPayload = nil
    self.localPlayerName = nil
    self.pendingEnetEvents = nil
    self.lastError = nil

    return self
end

function NetworkClient:_cleanupTransport(emitEvents)
    if self.transport == "enet" and self.enetClient then
        local EnetTransport = require("src.core.network.transport.enet")
        EnetTransport.disconnectClient(self.enetClient)
        EnetTransport.destroy(self.enetClient)
        self.enetClient = nil
    end

    self.transport = "none"
    self.state = CONNECTION_STATES.DISCONNECTED
    self.playerId = nil
    self.players = {}
    self.pendingJoinPayload = nil
    self.localPlayerName = nil
    self.pendingEnetEvents = nil
    self.lastPingTime = 0
    self.ping = 0

    if emitEvents then
        Log.info("Disconnected from server")
        Events.emit("NETWORK_DISCONNECTED")
    end
end

local function formatEndpoint(address, port)
    return string.format("%s:%d", address, port)
end

local function pollTimeoutSeconds(options)
    local defaultTimeout = 5

    if not options then
        return defaultTimeout
    end

    if options.handshakeTimeout == 0 or options.timeout == 0 then
        return 0
    end

    local timeout = options.handshakeTimeout or options.timeout or defaultTimeout
    if type(timeout) ~= "number" then
        return defaultTimeout
    end

    if timeout < 0 then
        return defaultTimeout
    end

    return timeout == 0 and 0 or timeout
end

local function clampTimeout(timeout)
    if not timeout or timeout <= 0 then
        return 0
    end
    -- Prevent excessively long blocking periods; ENet has its own internal timeout
    return math.min(timeout, 10)
end

local function milliseconds(value)
    if not value or value <= 0 then
        return 0
    end
    return math.floor(value * 1000)
end

local function captureTime()
    if love and love.timer and love.timer.getTime then
        return love.timer.getTime()
    end
    return os.clock()
end

function NetworkClient:connect(address, port, options)
    if self.state == CONNECTION_STATES.CONNECTED or self.state == CONNECTION_STATES.CONNECTING then
        Log.warn("Client already attempting or holding a connection")
        self.lastError = "Client already attempting or holding a connection."
        return false, self.lastError
    end

    self.serverAddress = address or self.serverAddress
    self.serverPort = port or self.serverPort
    self.state = CONNECTION_STATES.CONNECTING
    self.playerId = nil
    self.players = {}
    self.lastPingTime = 0
    self.ping = 0
    self.pendingEnetEvents = nil
    self.lastError = nil

    self.pendingJoinPayload = {
        type = MESSAGE_TYPES.PLAYER_JOIN,
        playerName = randomPlayerName(),
        data = {
            position = { x = 0, y = 0, angle = 0 },
            velocity = { x = 0, y = 0 },
            health = { hp = 100, maxHp = 100, shield = 0, maxShield = 0 }
        },
        timestamp = currentTime()
    }
    self.localPlayerName = self.pendingJoinPayload.playerName

    Log.info("Connecting to server at", formatEndpoint(self.serverAddress, self.serverPort))

    -- Try ENet transport first
    local ok, EnetTransport = pcall(require, "src.core.network.transport.enet")
    Log.info("ENet transport check - ok:", ok, "EnetTransport:", EnetTransport and "loaded" or "nil")
    if ok and EnetTransport then
        Log.info("ENet transport available:", EnetTransport.isAvailable())
        if not EnetTransport.isAvailable() then
            Log.warn("ENet transport loaded but not available - lua-enet library may not be compiled")
        end
    else
        Log.warn("Failed to load ENet transport - lua-enet library not available")
    end
    if ok and EnetTransport and EnetTransport.isAvailable() then
        Log.info("ENet is available, attempting to create client")
        local client, err = EnetTransport.createClient()
        if client then
            Log.info("ENet client created, attempting to connect to", self.serverAddress, self.serverPort)
            local peer, peerErr = EnetTransport.connect(client, self.serverAddress, self.serverPort)
            if peer then
                self.enetClient = client
                self.transport = "enet"

                local handshakeTimeout = clampTimeout(pollTimeoutSeconds(options))
                local deadline = handshakeTimeout > 0 and (captureTime() + handshakeTimeout) or nil
                local connected = false
                self.pendingEnetEvents = {}

                while true do
                    local waitMs = 100
                    if deadline then
                        local remaining = deadline - captureTime()
                        if remaining <= 0 then
                            break
                        end
                        waitMs = math.max(10, math.min(milliseconds(remaining), 250))
                    end

                    local event = EnetTransport.service(self.enetClient, waitMs)
                    if event then
                        if event.type == "connect" then
                            connected = true
                            break
                        elseif event.type == "disconnect" then
                            self.lastError = "Server rejected connection request."
                            break
                        else
                            table.insert(self.pendingEnetEvents, event)
                        end
                    elseif not deadline then
                        -- No events and no deadline specified; treat as immediate failure
                        break
                    end
                end

                if connected then
                    self.state = CONNECTION_STATES.CONNECTED
                    self.lastError = nil
                    Log.info("Connected using ENet transport")
                    Events.emit("NETWORK_CONNECTED")
                    if self.pendingJoinPayload then
                        self:sendMessage(self.pendingJoinPayload)
                        self.pendingJoinPayload = nil
                    end

                    if self.pendingEnetEvents and #self.pendingEnetEvents > 0 then
                        for _, pendingEvent in ipairs(self.pendingEnetEvents) do
                            self:_processEnetEvent(pendingEvent)
                        end
                    end
                    self.pendingEnetEvents = nil

                    return true
                end

                if not self.lastError then
                    local timeoutMessage = string.format("Connection attempt to %s:%d timed out.", self.serverAddress, self.serverPort)
                    if deadline then
                        timeoutMessage = timeoutMessage .. string.format(" (%.1fs)", handshakeTimeout)
                    end
                    self.lastError = timeoutMessage
                end

                self:_cleanupTransport(false)
                return false, self.lastError
            else
                Log.error("Failed to connect with ENet:", peerErr)
                self.lastError = peerErr and tostring(peerErr) or "Failed to initiate connection."
                self:_cleanupTransport(false)
                return false, self.lastError
            end
        else
            Log.error("Failed to create ENet client:", err)
            self.lastError = err and tostring(err) or "Unable to create network client."
            return false, self.lastError
        end
    else
        Log.error("ENet transport not available - ok:", ok, "EnetTransport:", EnetTransport and "loaded" or "nil")
        if EnetTransport then
            Log.error("ENet isAvailable:", EnetTransport.isAvailable())
        end
        self.lastError = "Network transport unavailable."
    end

    Log.error("No networking transport available for", self.serverAddress)
    return false, self.lastError
end

function NetworkClient:disconnect()
    if self.transport == "enet" and self.enetClient and self.state == CONNECTION_STATES.CONNECTED then
        self:sendMessage({
            type = MESSAGE_TYPES.PLAYER_LEAVE,
            playerId = self.playerId,
            timestamp = currentTime()
        })
    end

    self:_cleanupTransport(true)
end

function NetworkClient:sendMessage(message)
    if self.state ~= CONNECTION_STATES.CONNECTED then
        return false
    end

    if self.transport == "enet" and self.enetClient then
        local EnetTransport = require("src.core.network.transport.enet")
        local json = require("src.libs.json")
        local data = json.encode(message)
        local success, err = EnetTransport.send(self.enetClient, data, 0, true)
        if not success then
            Log.warn("Failed to send message via ENet transport:", err)
            return false
        end
        return true
    end

    return false
end

function NetworkClient:_processEnetEvent(event)
    if not event then
        return
    end

    if event.type == "connect" then
        Log.info("Received ENet connect event")
        if self.state ~= CONNECTION_STATES.CONNECTED then
            self.state = CONNECTION_STATES.CONNECTED
            self.lastError = nil
            Events.emit("NETWORK_CONNECTED")
            if self.pendingJoinPayload then
                self:sendMessage(self.pendingJoinPayload)
                self.pendingJoinPayload = nil
            end
        end
        return
    end

    if event.type == "disconnect" then
        Log.info("Disconnected from server")
        self.state = CONNECTION_STATES.DISCONNECTED
        self.lastError = "Disconnected from server"
        Events.emit("NETWORK_DISCONNECTED")
        return
    end

    if event.type == "receive" then
        local success, message = pcall(json.decode, event.data)
        if success and message then
            self:handleMessage(message)
        end
    end
end

function NetworkClient:update(dt)
    if self.state == CONNECTION_STATES.DISCONNECTED then
        return
    end

    if self.transport == "enet" and self.enetClient then
        local EnetTransport = require("src.core.network.transport.enet")
        if self.pendingEnetEvents and #self.pendingEnetEvents > 0 then
            for _, pendingEvent in ipairs(self.pendingEnetEvents) do
                self:_processEnetEvent(pendingEvent)
            end
            self.pendingEnetEvents = nil
        end

        -- Poll for ENet events
        local event = EnetTransport.service(self.enetClient, 0)
        while event do
            self:_processEnetEvent(event)
            event = EnetTransport.service(self.enetClient, 0)
        end
    end

    if self.state == CONNECTION_STATES.CONNECTED then
        self.lastPingTime = self.lastPingTime + dt
        if self.lastPingTime >= 5.0 then
            self:sendMessage({
                type = MESSAGE_TYPES.PING,
                timestamp = currentTime()
            })
            self.lastPingTime = 0
        end
    end
end

function NetworkClient:handleMessage(message)
    if message.type == MESSAGE_TYPES.PLAYER_JOIN then
        if not self.playerId then
            self.playerId = message.playerId
            Log.info("Assigned player ID:", self.playerId)

            if message.players then
                Log.info("Client received", #message.players, "existing players from server")
                for _, entry in ipairs(message.players) do
                    Log.info("Processing existing player:", entry.playerId, "name:", entry.name)
                    mergePlayerSnapshot(self.players, entry.playerId, entry.data, entry.name)
                    Events.emit("NETWORK_PLAYER_JOINED", {
                        playerId = entry.playerId,
                        playerName = entry.name,
                        isSelf = false
                    })
                end
            end

            Events.emit("NETWORK_PLAYER_JOINED", {
                playerId = self.playerId,
                playerName = self.localPlayerName,
                isSelf = true
            })
        elseif message.playerId and message.playerId ~= self.playerId then
            if not self.players[message.playerId] then
                Log.info("Player joined:", message.playerName or message.playerId)
            end
            mergePlayerSnapshot(self.players, message.playerId, message.data, message.playerName)
            Events.emit("NETWORK_PLAYER_JOINED", {
                playerId = message.playerId,
                playerName = message.playerName,
                isSelf = false
            })
        end

    elseif message.type == MESSAGE_TYPES.PLAYER_LEAVE then
        if self.players[message.playerId] then
            self.players[message.playerId] = nil
            Log.info("Player left:", message.playerId)
            Events.emit("NETWORK_PLAYER_LEFT", { playerId = message.playerId })
        end

    elseif message.type == MESSAGE_TYPES.PLAYER_UPDATE then
        if message.playerId ~= self.playerId then
            local snapshot = mergePlayerSnapshot(self.players, message.playerId, message.data)
            Events.emit("NETWORK_PLAYER_UPDATED", {
                playerId = message.playerId,
                data = snapshot
            })
        end


    elseif message.type == MESSAGE_TYPES.PONG then
        self.ping = (currentTime() - message.timestamp) * 1000
        Events.emit("NETWORK_PING_UPDATED", { ping = self.ping })
    end
end

function NetworkClient:sendPlayerUpdate(playerData)
    if not self.playerId then
        return
    end

    self:sendMessage({
        type = MESSAGE_TYPES.PLAYER_UPDATE,
        playerId = self.playerId,
        data = playerData,
        timestamp = currentTime()
    })
end


function NetworkClient:getState()
    return self.state
end

function NetworkClient:getPlayers()
    return self.players
end

function NetworkClient:getPing()
    return self.ping
end

function NetworkClient:isConnected()
    return self.state == CONNECTION_STATES.CONNECTED
end

function NetworkClient:getLastError()
    return self.lastError
end

return NetworkClient
