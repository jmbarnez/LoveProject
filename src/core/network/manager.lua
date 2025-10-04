--[[
    Network Manager
    Central coordinator for multiplayer functionality
]]

local Log = require("src.core.log")
local Events = require("src.core.events")
local json = require("src.libs.json")
local NetworkClient = require("src.core.network.client")
local NetworkServer = require("src.core.network.server")

local NetworkManager = {}
NetworkManager.__index = NetworkManager

function NetworkManager.new()
    local self = setmetatable({}, NetworkManager)

    self.client = NetworkClient.new()
    self.server = NetworkServer.new(7777)
    self._isHost = false
    self._isMultiplayer = false

    self:setupEventListeners()

    return self
end

function NetworkManager:setupEventListeners()
    Events.on("NETWORK_CONNECTED", function()
        Log.info("Connected to multiplayer server")
    end)

    Events.on("NETWORK_DISCONNECTED", function()
        Log.info("Disconnected from multiplayer server")
    end)

    Events.on("NETWORK_PLAYER_JOINED", function(data)
        if data and data.playerId then
            if data.isSelf then
                Log.info("You joined with player ID", data.playerId)
            else
                Log.info("Player joined:", data.playerId, "name:", data.playerName)
            end
        end
    end)

    Events.on("NETWORK_PLAYER_LEFT", function(data)
        if data and data.playerId then
            Log.info("Player left:", data.playerId)
        end
    end)


    Events.on("NETWORK_SEND_PLAYER_UPDATE", function(data)
        if not data then
            return
        end

        if not self._isMultiplayer then
            return
        end

        -- Both host and client should send player updates
        self:sendPlayerUpdate(data)
    end)
end

function NetworkManager:startHost(port)
    if self._isMultiplayer then
        Log.warn("Already in multiplayer mode")
        return false
    end

    port = port or 7777
    self.server = NetworkServer.new(port)

    if self.server:start() then
        self._isHost = true
        self._isMultiplayer = true
        
        -- Add the host player to the server with unique name
        local hostName = "Host_" .. os.time() .. "_" .. math.random(1000, 9999)
        self.server:addHostPlayer(hostName, {
            position = { x = 0, y = 0, angle = 0 },
            velocity = { x = 0, y = 0 },
            health = { hp = 100, maxHp = 100, shield = 0, maxShield = 0 }
        })
        
        Log.info("Started hosting multiplayer game on port", port)
        return true
    end

    Log.error("Failed to start multiplayer server")
    return false
end

function NetworkManager:joinGame(address, port)
    if self._isMultiplayer then
        Log.warn("Already in multiplayer mode")
        return false
    end

    address = address or "localhost"
    port = port or 7777

    Log.info("Attempting to join game at", string.format("%s:%d", address, port))

    if self.client:connect(address, port) then
        self._isHost = false
        self._isMultiplayer = true
        Log.info("Successfully joined multiplayer game")
        return true
    end

    Log.error("Failed to join multiplayer game")
    return false
end

function NetworkManager:leaveGame()
    if not self._isMultiplayer then
        return
    end

    if self._isHost then
        self.server:stop()
    else
        self.client:disconnect()
    end

    self._isHost = false
    self._isMultiplayer = false
    Log.info("Left multiplayer game")
end

function NetworkManager:update(dt)
    if not self._isMultiplayer then
        return
    end

    if self._isHost then
        self.server:update(dt)
    else
        self.client:update(dt)
    end
end

function NetworkManager:sendPlayerUpdate(playerData)
    if not self._isMultiplayer then
        return
    end

    if self._isHost then
        -- Host sends updates to the server
        if self.server and self.server:isRunning() then
            -- Directly update the server's host player data
            Log.info("Host sending player update:", json.encode(playerData))
            self.server:updateHostPlayer(playerData)
        else
            Log.warn("Host server not running, cannot send update")
        end
    else
        -- Client sends updates to the server
        if self.client:isConnected() then
            self.client:sendPlayerUpdate(playerData)
        end
    end
end


function NetworkManager:getPlayers()
    if not self._isMultiplayer then
        return {}
    end

    if self._isHost then
        local normalized = {}
        local serverPlayers = self.server:getPlayers()
        for playerId, player in pairs(serverPlayers) do
            local snapshot = {}
            -- Copy all data from player.data (includes position, velocity, health)
            if player.data then
                for key, value in pairs(player.data) do
                    snapshot[key] = value
                end
            end
            -- Set basic player info
            snapshot.playerId = snapshot.playerId or playerId
            if player.name then
                snapshot.playerName = snapshot.playerName or player.name
            end
            if player.lastSeen then
                snapshot.lastSeen = player.lastSeen
            end
            normalized[playerId] = snapshot
        end
        return normalized
    end

    return self.client:getPlayers()
end

function NetworkManager:getPlayerCount()
    if not self._isMultiplayer then
        return 1
    end

    if self._isHost then
        local count = self.server:getPlayerCount()
        Log.info("Host player count:", count)
        return count
    end

    local count = 1 -- include local player
    local clientPlayers = self.client:getPlayers()
    for playerId, _ in pairs(clientPlayers) do
        count = count + 1
        Log.info("Client sees player:", playerId)
    end
    Log.info("Client player count:", count)
    return count
end

function NetworkManager:getPing()
    if self._isMultiplayer and not self._isHost then
        return self.client:getPing()
    end
    return 0
end

function NetworkManager:isMultiplayer()
    return self._isMultiplayer
end

function NetworkManager:isHost()
    return self._isHost
end

function NetworkManager:isConnected()
    if not self._isMultiplayer then
        return false
    end

    if self._isHost then
        return self.server:isRunning()
    end

    return self.client:isConnected()
end

return NetworkManager
