--[[
    Network Client
    Handles client-side networking for multiplayer gameplay
]]

local Log = require("src.core.log")
local Events = require("src.core.events")

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
    WORLD_UPDATE = "world_update",
    CHAT_MESSAGE = "chat_message",
    PING = "ping",
    PONG = "pong"
}

function NetworkClient.new()
    local self = setmetatable({}, NetworkClient)
    
    self.state = CONNECTION_STATES.DISCONNECTED
    self.socket = nil
    self.serverAddress = "localhost"
    self.serverPort = 7777
    self.playerId = nil
    self.players = {} -- Connected players
    self.lastPingTime = 0
    self.ping = 0
    self.isHost = false
    
    return self
end

function NetworkClient:connect(address, port)
    if self.state == CONNECTION_STATES.CONNECTED then
        Log.warn("Already connected to server")
        return false
    end
    
    self.serverAddress = address or self.serverAddress
    self.serverPort = port or self.serverPort
    self.state = CONNECTION_STATES.CONNECTING
    
    Log.info("Connecting to server at", self.serverAddress .. ":" .. self.serverPort)
    
    -- Try to load luasocket
    local socket = require("socket")
    if not socket then
        Log.error("Failed to load luasocket - networking not available")
        self.state = CONNECTION_STATES.ERROR
        return false
    end
    
    self.socket = socket.udp()
    if not self.socket then
        Log.error("Failed to create UDP socket")
        self.state = CONNECTION_STATES.ERROR
        return false
    end
    
    self.socket:settimeout(0) -- Non-blocking
    
    -- Send connection request
    local success = self:sendMessage({
        type = MESSAGE_TYPES.PLAYER_JOIN,
        playerName = "Player" .. math.random(1000, 9999),
        timestamp = love.timer.getTime()
    })
    
    if success then
        self.state = CONNECTION_STATES.CONNECTED
        Log.info("Connected to server")
        Events.emit("NETWORK_CONNECTED")
        return true
    else
        self.state = CONNECTION_STATES.ERROR
        Log.error("Failed to connect to server")
        return false
    end
end

function NetworkClient:disconnect()
    if self.socket then
        self:sendMessage({
            type = MESSAGE_TYPES.PLAYER_LEAVE,
            playerId = self.playerId,
            timestamp = love.timer.getTime()
        })
        self.socket:close()
        self.socket = nil
    end
    
    self.state = CONNECTION_STATES.DISCONNECTED
    self.playerId = nil
    self.players = {}
    Log.info("Disconnected from server")
    Events.emit("NETWORK_DISCONNECTED")
end

function NetworkClient:sendMessage(message)
    if not self.socket or self.state ~= CONNECTION_STATES.CONNECTED then
        return false
    end
    
    local json = require("src.libs.json")
    local data = json.encode(message)
    local success, err = self.socket:sendto(data, self.serverAddress, self.serverPort)
    
    if not success then
        Log.warn("Failed to send message:", err)
        return false
    end
    
    return true
end

function NetworkClient:update(dt)
    if not self.socket or self.state ~= CONNECTION_STATES.CONNECTED then
        return
    end
    
    -- Receive messages
    local data, ip, port = self.socket:receivefrom()
    if data then
        local json = require("src.libs.json")
        local success, message = pcall(json.decode, data)
        
        if success and message then
            self:handleMessage(message)
        else
            Log.warn("Failed to decode network message")
        end
    end
    
    -- Send ping every 5 seconds
    self.lastPingTime = self.lastPingTime + dt
    if self.lastPingTime >= 5.0 then
        self:sendMessage({
            type = MESSAGE_TYPES.PING,
            timestamp = love.timer.getTime()
        })
        self.lastPingTime = 0
    end
end

function NetworkClient:handleMessage(message)
    if message.type == MESSAGE_TYPES.PLAYER_JOIN then
        self.playerId = message.playerId
        Log.info("Assigned player ID:", self.playerId)
        Events.emit("NETWORK_PLAYER_JOINED", { playerId = self.playerId })
        
    elseif message.type == MESSAGE_TYPES.PLAYER_LEAVE then
        if self.players[message.playerId] then
            self.players[message.playerId] = nil
            Log.info("Player left:", message.playerId)
            Events.emit("NETWORK_PLAYER_LEFT", { playerId = message.playerId })
        end
        
    elseif message.type == MESSAGE_TYPES.PLAYER_UPDATE then
        if message.playerId ~= self.playerId then
            self.players[message.playerId] = message.data
            Events.emit("NETWORK_PLAYER_UPDATED", { 
                playerId = message.playerId, 
                data = message.data 
            })
        end
        
    elseif message.type == MESSAGE_TYPES.WORLD_UPDATE then
        Events.emit("NETWORK_WORLD_UPDATED", { data = message.data })
        
    elseif message.type == MESSAGE_TYPES.CHAT_MESSAGE then
        Events.emit("NETWORK_CHAT_MESSAGE", { 
            playerId = message.playerId,
            message = message.message 
        })
        
    elseif message.type == MESSAGE_TYPES.PONG then
        self.ping = (love.timer.getTime() - message.timestamp) * 1000
        Events.emit("NETWORK_PING_UPDATED", { ping = self.ping })
    end
end

function NetworkClient:sendPlayerUpdate(playerData)
    self:sendMessage({
        type = MESSAGE_TYPES.PLAYER_UPDATE,
        playerId = self.playerId,
        data = playerData,
        timestamp = love.timer.getTime()
    })
end

function NetworkClient:sendChatMessage(message)
    self:sendMessage({
        type = MESSAGE_TYPES.CHAT_MESSAGE,
        playerId = self.playerId,
        message = message,
        timestamp = love.timer.getTime()
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
