--[[
    Network Manager
    Central coordinator for multiplayer functionality
]]

local Log = require("src.core.log")
local Events = require("src.core.events")
local NetworkClient = require("src.core.network.client")
local NetworkServer = require("src.core.network.server")

local NetworkManager = {}
NetworkManager.__index = NetworkManager

function NetworkManager.new()
    local self = setmetatable({}, NetworkManager)
    
    self.client = NetworkClient.new()
    self.server = NetworkServer.new(7777)
    self.isHost = false
    self.isMultiplayer = false
    
    -- Set up event listeners
    self:setupEventListeners()
    
    return self
end

function NetworkManager:setupEventListeners()
    -- Client events
    Events.on("NETWORK_CONNECTED", function(data)
        Log.info("Connected to multiplayer server")
    end)
    
    Events.on("NETWORK_DISCONNECTED", function(data)
        Log.info("Disconnected from multiplayer server")
    end)
    
    Events.on("NETWORK_PLAYER_JOINED", function(data)
        Log.info("Player joined:", data.playerId)
    end)
    
    Events.on("NETWORK_PLAYER_LEFT", function(data)
        Log.info("Player left:", data.playerId)
    end)
    
    Events.on("NETWORK_PLAYER_UPDATED", function(data)
        -- Handle player updates
    end)
    
    Events.on("NETWORK_WORLD_UPDATED", function(data)
        -- Handle world updates
    end)
    
    Events.on("NETWORK_CHAT_MESSAGE", function(data)
        Log.info("Chat from player", data.playerId .. ":", data.message)
    end)
    
    -- Server events
    Events.on("NETWORK_SERVER_STARTED", function(data)
        Log.info("Multiplayer server started on port", data.port)
    end)
    
    Events.on("NETWORK_SERVER_STOPPED", function(data)
        Log.info("Multiplayer server stopped")
    end)
end

function NetworkManager:startHost(port)
    if self.isMultiplayer then
        Log.warn("Already in multiplayer mode")
        return false
    end
    
    port = port or 7777
    self.server = NetworkServer.new(port)
    
    if self.server:start() then
        self.isHost = true
        self.isMultiplayer = true
        Log.info("Started hosting multiplayer game on port", port)
        return true
    else
        Log.error("Failed to start multiplayer server")
        return false
    end
end

function NetworkManager:joinGame(address, port)
    if self.isMultiplayer then
        Log.warn("Already in multiplayer mode")
        return false
    end
    
    address = address or "localhost"
    port = port or 7777
    
    if self.client:connect(address, port) then
        self.isHost = false
        self.isMultiplayer = true
        Log.info("Joined multiplayer game at", address .. ":" .. port)
        return true
    else
        Log.error("Failed to join multiplayer game")
        return false
    end
end

function NetworkManager:leaveGame()
    if not self.isMultiplayer then
        return
    end
    
    if self.isHost then
        self.server:stop()
        self.isHost = false
    else
        self.client:disconnect()
    end
    
    self.isMultiplayer = false
    Log.info("Left multiplayer game")
end

function NetworkManager:update(dt)
    if self.isMultiplayer then
        if self.isHost then
            self.server:update(dt)
        else
            self.client:update(dt)
        end
    end
end

function NetworkManager:sendPlayerUpdate(playerData)
    if self.isMultiplayer and not self.isHost then
        self.client:sendPlayerUpdate(playerData)
    end
end

function NetworkManager:sendChatMessage(message)
    if self.isMultiplayer and not self.isHost then
        self.client:sendChatMessage(message)
    end
end

function NetworkManager:getPlayers()
    if self.isMultiplayer then
        if self.isHost then
            return self.server:getPlayers()
        else
            return self.client:getPlayers()
        end
    end
    return {}
end

function NetworkManager:getPlayerCount()
    if self.isMultiplayer then
        if self.isHost then
            return self.server:getPlayerCount()
        else
            local count = 0
            for _ in pairs(self.client:getPlayers()) do
                count = count + 1
            end
            return count + 1 -- +1 for self
        end
    end
    return 1
end

function NetworkManager:getPing()
    if self.isMultiplayer and not self.isHost then
        return self.client:getPing()
    end
    return 0
end

function NetworkManager:isMultiplayer()
    return self.isMultiplayer
end

function NetworkManager:isHost()
    return self.isHost
end

function NetworkManager:isConnected()
    if self.isMultiplayer then
        if self.isHost then
            return self.server:isRunning()
        else
            return self.client:isConnected()
        end
    end
    return false
end

return NetworkManager
