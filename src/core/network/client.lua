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
    -- Use timestamp and random number to ensure uniqueness across instances
    local timestamp = os.time()
    local random = math.random(1000, 9999)
    return "Player" .. timestamp .. "_" .. random
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

    return self
end

local function formatEndpoint(address, port)
    return string.format("%s:%d", address, port)
end

function NetworkClient:connect(address, port)
    if self.state == CONNECTION_STATES.CONNECTED or self.state == CONNECTION_STATES.CONNECTING then
        Log.warn("Client already attempting or holding a connection")
        return false
    end

    self.serverAddress = address or self.serverAddress
    self.serverPort = port or self.serverPort
    self.state = CONNECTION_STATES.CONNECTING
    self.playerId = nil
    self.players = {}
    self.lastPingTime = 0
    self.ping = 0

    self.pendingJoinPayload = {
        type = MESSAGE_TYPES.PLAYER_JOIN,
        playerName = randomPlayerName(),
        timestamp = currentTime()
    }
    self.localPlayerName = self.pendingJoinPayload.playerName

    Log.info("Connecting to server at", formatEndpoint(self.serverAddress, self.serverPort))

    -- Try ENet transport first
    local ok, EnetTransport = pcall(require, "src.core.network.transport.enet")
    Log.info("ENet transport check - ok:", ok, "EnetTransport:", EnetTransport and "loaded" or "nil")
    if ok and EnetTransport then
        Log.info("ENet transport available:", EnetTransport.isAvailable())
    end
    if ok and EnetTransport and EnetTransport.isAvailable() then
        local client, err = EnetTransport.createClient()
        if client then
            local peer, peerErr = EnetTransport.connect(client, self.serverAddress, self.serverPort)
            if peer then
                self.enetClient = client
                self.transport = "enet"
                self.state = CONNECTION_STATES.CONNECTED
                Log.info("Connected using ENet transport")
                Events.emit("NETWORK_CONNECTED")
                if self.pendingJoinPayload then
                    self:sendMessage(self.pendingJoinPayload)
                    self.pendingJoinPayload = nil
                end
                return true
            else
                Log.error("Failed to connect with ENet:", peerErr)
            end
        else
            Log.error("Failed to create ENet client:", err)
        end
    end

    -- Only use file-based networking for localhost connections
    if self.serverAddress == "localhost" or self.serverAddress == "127.0.0.1" then
        Log.info("Using file-based networking for localhost connection")
        local ok, FileNetwork = pcall(require, "src.core.network.file_network")
        if ok and FileNetwork then
            self.fileNetwork = FileNetwork.new(self.serverPort, false)
            self.transport = "file"
            self.state = CONNECTION_STATES.CONNECTED
            Log.info("Connected using file-based transport (localhost)")
            Events.emit("NETWORK_CONNECTED")
            if self.pendingJoinPayload then
                self:sendMessage(self.pendingJoinPayload)
                self.pendingJoinPayload = nil
            end
            return true
        end
    else
        Log.info("Not using file-based networking for non-localhost address:", self.serverAddress)
    end

    Log.error("No networking transport available for", self.serverAddress)
    return false
end

function NetworkClient:disconnect()
    if self.transport == "enet" and self.enetClient then
        if self.state == CONNECTION_STATES.CONNECTED then
            self:sendMessage({
                type = MESSAGE_TYPES.PLAYER_LEAVE,
                playerId = self.playerId,
                timestamp = currentTime()
            })
        end
        local EnetTransport = require("src.core.network.transport.enet")
        EnetTransport.disconnectClient(self.enetClient)
        EnetTransport.destroy(self.enetClient)
        self.enetClient = nil
    elseif self.transport == "file" then
        if self.state == CONNECTION_STATES.CONNECTED then
            self:sendMessage({
                type = MESSAGE_TYPES.PLAYER_LEAVE,
                playerId = self.playerId,
                timestamp = currentTime()
            })
        end
        self.fileNetwork = nil
    end

    self.transport = "none"
    self.state = CONNECTION_STATES.DISCONNECTED
    self.playerId = nil
    self.players = {}
    self.pendingJoinPayload = nil
    self.localPlayerName = nil
    self.lastPingTime = 0
    self.ping = 0

    Log.info("Disconnected from server")
    Events.emit("NETWORK_DISCONNECTED")
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
    elseif self.transport == "file" and self.fileNetwork then
        local success = self.fileNetwork:sendMessage(message, self.serverAddress, self.serverPort)
        if not success then
            Log.warn("Failed to send message via file transport")
            return false
        end
        return true
    end

    return false
end

function NetworkClient:update(dt)
    if self.state == CONNECTION_STATES.DISCONNECTED then
        return
    end

    if self.transport == "enet" and self.enetClient then
        local EnetTransport = require("src.core.network.transport.enet")
        local json = require("src.libs.json")
        
        -- Poll for ENet events
        local event = EnetTransport.service(self.enetClient, 0)
        while event do
            if event.type == "receive" then
                local success, message = pcall(json.decode, event.data)
                if success and message then
                    self:handleMessage(message)
                end
            elseif event.type == "disconnect" then
                Log.info("Disconnected from server")
                self.state = CONNECTION_STATES.DISCONNECTED
                Events.emit("NETWORK_DISCONNECTED")
                return
            end
            event = EnetTransport.service(self.enetClient, 0)
        end
    elseif self.transport == "file" and self.fileNetwork then
        local messages = self.fileNetwork:receiveMessages()
        for _, packet in ipairs(messages) do
            if packet.message then
                self:handleMessage(packet.message)
            end
        end
        self.fileNetwork:cleanup()
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
                for _, entry in ipairs(message.players) do
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

return NetworkClient
