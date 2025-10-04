--[[
    Network Server
    Handles server-side networking for multiplayer gameplay
]]

local Log = require("src.core.log")
local Events = require("src.core.events")

local NetworkServer = {}
NetworkServer.__index = NetworkServer

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

function NetworkServer.new(port)
    local self = setmetatable({}, NetworkServer)
    
    self.port = port or 7777
    self.socket = nil
    self.players = {} -- Connected players
    self.nextPlayerId = 1
    self.isRunning = false
    self.lastCleanup = 0
    self.cleanupInterval = 10.0 -- Clean up disconnected players every 10 seconds
    
    return self
end

function NetworkServer:start()
    if self.isRunning then
        Log.warn("Server already running")
        return false
    end
    
    Log.info("Starting server on port", self.port)
    
    -- Try to load luasocket
    local socket = require("socket")
    if not socket then
        Log.error("Failed to load luasocket - networking not available")
        return false
    end
    
    -- Check if luasocket is available
    local success, err = pcall(function()
        self.socket = socket.udp()
        if not self.socket then
            error("Failed to create UDP socket")
        end
        
        local bindSuccess, bindErr = self.socket:bind("*", self.port)
        if not bindSuccess then
            error("Failed to bind to port " .. self.port .. ": " .. tostring(bindErr))
        end
    end)
    
    if not success then
        Log.warn("luasocket not available - using simulation mode: " .. tostring(err))
        self.socket = nil
        self.simulationMode = true
    end
    
    if self.socket then
        self.socket:settimeout(0) -- Non-blocking
    end
    
    self.isRunning = true
    
    if self.simulationMode then
        Log.info("Server started in simulation mode on port", self.port)
    else
        Log.info("Server started successfully on port", self.port)
    end
    
    Events.emit("NETWORK_SERVER_STARTED", { port = self.port })
    return true
end

function NetworkServer:stop()
    if not self.isRunning then
        return
    end
    
    if self.socket then
        self.socket:close()
        self.socket = nil
    end
    
    self.isRunning = false
    self.players = {}
    self.nextPlayerId = 1
    
    Log.info("Server stopped")
    Events.emit("NETWORK_SERVER_STOPPED")
end

function NetworkServer:update(dt)
    if not self.isRunning then
        return
    end
    
    -- In simulation mode, just process any queued messages
    if self.simulationMode then
        -- Simulate receiving messages (for testing purposes)
        return
    end
    
    if not self.socket then
        return
    end
    
    -- Receive messages
    local data, ip, port = self.socket:receivefrom()
    if data then
        local json = require("src.libs.json")
        local success, message = pcall(json.decode, data)
        
        if success and message then
            self:handleMessage(message, ip, port)
        else
            Log.warn("Failed to decode network message from", ip .. ":" .. port)
        end
    end
    
    -- Clean up disconnected players
    self.lastCleanup = self.lastCleanup + dt
    if self.lastCleanup >= self.cleanupInterval then
        self:cleanupDisconnectedPlayers()
        self.lastCleanup = 0
    end
end

function NetworkServer:handleMessage(message, ip, port)
    local clientId = ip .. ":" .. port
    
    if message.type == MESSAGE_TYPES.PLAYER_JOIN then
        self:handlePlayerJoin(message, clientId, ip, port)
        
    elseif message.type == MESSAGE_TYPES.PLAYER_LEAVE then
        self:handlePlayerLeave(message, clientId)
        
    elseif message.type == MESSAGE_TYPES.PLAYER_UPDATE then
        self:handlePlayerUpdate(message, clientId)
        
    elseif message.type == MESSAGE_TYPES.CHAT_MESSAGE then
        self:handleChatMessage(message, clientId)
        
    elseif message.type == MESSAGE_TYPES.PING then
        self:handlePing(message, clientId, ip, port)
    end
end

function NetworkServer:handlePlayerJoin(message, clientId, ip, port)
    -- Check if player already exists
    local existingPlayer = nil
    for playerId, player in pairs(self.players) do
        if player.clientId == clientId then
            existingPlayer = player
            break
        end
    end
    
    if existingPlayer then
        -- Player reconnecting, send their ID back
        self:sendToClient(ip, port, {
            type = MESSAGE_TYPES.PLAYER_JOIN,
            playerId = existingPlayer.id,
            timestamp = love.timer.getTime()
        })
        return
    end
    
    -- Create new player
    local playerId = self.nextPlayerId
    self.nextPlayerId = self.nextPlayerId + 1
    
    local player = {
        id = playerId,
        clientId = clientId,
        ip = ip,
        port = port,
        name = message.playerName or ("Player" .. playerId),
        lastSeen = love.timer.getTime(),
        data = {}
    }
    
    self.players[playerId] = player
    
    -- Send player their ID
    self:sendToClient(ip, port, {
        type = MESSAGE_TYPES.PLAYER_JOIN,
        playerId = playerId,
        timestamp = love.timer.getTime()
    })
    
    -- Notify other players
    self:broadcastToOthers(playerId, {
        type = MESSAGE_TYPES.PLAYER_JOIN,
        playerId = playerId,
        playerName = player.name,
        timestamp = love.timer.getTime()
    })
    
    Log.info("Player joined:", player.name, "(" .. playerId .. ") from", ip .. ":" .. port)
    Events.emit("NETWORK_PLAYER_JOINED", { playerId = playerId, player = player })
end

function NetworkServer:handlePlayerLeave(message, clientId)
    local playerId = message.playerId
    if self.players[playerId] then
        local player = self.players[playerId]
        self.players[playerId] = nil
        
        -- Notify other players
        self:broadcastToOthers(playerId, {
            type = MESSAGE_TYPES.PLAYER_LEAVE,
            playerId = playerId,
            timestamp = love.timer.getTime()
        })
        
        Log.info("Player left:", player.name, "(" .. playerId .. ")")
        Events.emit("NETWORK_PLAYER_LEFT", { playerId = playerId, player = player })
    end
end

function NetworkServer:handlePlayerUpdate(message, clientId)
    local playerId = message.playerId
    if self.players[playerId] then
        local player = self.players[playerId]
        player.data = message.data
        player.lastSeen = love.timer.getTime()
        
        -- Broadcast to other players
        self:broadcastToOthers(playerId, {
            type = MESSAGE_TYPES.PLAYER_UPDATE,
            playerId = playerId,
            data = message.data,
            timestamp = love.timer.getTime()
        })
    end
end

function NetworkServer:handleChatMessage(message, clientId)
    local playerId = message.playerId
    if self.players[playerId] then
        -- Broadcast to all players including sender
        self:broadcast({
            type = MESSAGE_TYPES.CHAT_MESSAGE,
            playerId = playerId,
            message = message.message,
            timestamp = love.timer.getTime()
        })
        
        Log.info("Chat from", self.players[playerId].name .. ":", message.message)
    end
end

function NetworkServer:handlePing(message, clientId, ip, port)
    local playerId = message.playerId
    if self.players[playerId] then
        self.players[playerId].lastSeen = love.timer.getTime()
    end
    
    -- Send pong back
    self:sendToClient(ip, port, {
        type = MESSAGE_TYPES.PONG,
        timestamp = message.timestamp
    })
end

function NetworkServer:sendToClient(ip, port, message)
    if not self.socket then return false end
    
    local json = require("src.libs.json")
    local data = json.encode(message)
    local success, err = self.socket:sendto(data, ip, port)
    
    if not success then
        Log.warn("Failed to send message to", ip .. ":" .. port .. ":", err)
        return false
    end
    
    return true
end

function NetworkServer:broadcast(message)
    for playerId, player in pairs(self.players) do
        self:sendToClient(player.ip, player.port, message)
    end
end

function NetworkServer:broadcastToOthers(excludePlayerId, message)
    for playerId, player in pairs(self.players) do
        if playerId ~= excludePlayerId then
            self:sendToClient(player.ip, player.port, message)
        end
    end
end

function NetworkServer:cleanupDisconnectedPlayers()
    local currentTime = love.timer.getTime()
    local timeout = 30.0 -- 30 seconds timeout
    
    for playerId, player in pairs(self.players) do
        if currentTime - player.lastSeen > timeout then
            Log.info("Cleaning up disconnected player:", player.name, "(" .. playerId .. ")")
            
            -- Notify other players
            self:broadcastToOthers(playerId, {
                type = MESSAGE_TYPES.PLAYER_LEAVE,
                playerId = playerId,
                timestamp = currentTime
            })
            
            self.players[playerId] = nil
            Events.emit("NETWORK_PLAYER_LEFT", { playerId = playerId, player = player })
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

function NetworkServer:isRunning()
    return self.isRunning
end

return NetworkServer
