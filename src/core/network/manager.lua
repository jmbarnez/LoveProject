--[[
    Network Manager
    High level facade that coordinates the multiplayer session and exposes
    normalised state to gameplay systems.
]]

local Log = require("src.core.log")
local Events = require("src.core.events")
local json = require("src.libs.json")
local NetworkClient = require("src.core.network.client")
local NetworkServer = require("src.core.network.server")
local Util = require("src.core.util")

local NetworkManager = {}
NetworkManager.__index = NetworkManager

local function shallowCopy(source)
    local out = {}
    for key, value in pairs(source) do
        out[key] = value
    end
    return out
end

function NetworkManager.new()
    local self = setmetatable({}, NetworkManager)

    self.client = NetworkClient.new()
    self.server = nil
    self._isHost = false
    self._isMultiplayer = false
    self._players = {}
    self._localPlayerId = nil
    self._worldSnapshot = nil
    self._pendingWorldSnapshot = nil
    self._eventListenersSetup = false
    self._lastPlayerUpdate = 0

    self:setupEventListeners()

    return self
end

function NetworkManager:setupEventListeners()
    -- Prevent duplicate event listener registration
    if self._eventListenersSetup then
        return
    end
    self._eventListenersSetup = true

    Events.on("NETWORK_CONNECTED", function()
        Log.info("Connected to multiplayer server")
    end)

    Events.on("NETWORK_DISCONNECTED", function()
        Log.info("Disconnected from multiplayer server")
        self._players = {}
        self._localPlayerId = nil
        self._worldSnapshot = nil
    end)

    Events.on("NETWORK_PLAYER_JOINED", function(data)
        if not data or not data.playerId then
            return
        end

        local id = data.playerId
        self._players[id] = self._players[id] or { state = {} }
        self._players[id].playerId = id
        self._players[id].playerName = data.playerName or self._players[id].playerName
        if data.data then
            self._players[id].state = data.data
        end
        if data.isSelf then
            self._localPlayerId = id
        end

        Log.info("Player joined:", id, data.playerName or "")
    end)

    Events.on("NETWORK_PLAYER_LEFT", function(data)
        if not data or not data.playerId then
            return
        end
        self._players[data.playerId] = nil
        Log.info("Player left:", data.playerId)
    end)

    Events.on("NETWORK_PLAYER_UPDATED", function(data)
        if not data or not data.playerId then
            return
        end
        local id = data.playerId
        self._players[id] = self._players[id] or { playerId = id }
        if data.data then
            self._players[id].state = data.data
        end
        if data.playerName then
            self._players[id].playerName = data.playerName
        end
    end)

    Events.on("NETWORK_SEND_PLAYER_UPDATE", function(payload)
        if not payload then
            return
        end
        self:sendPlayerUpdate(payload)
    end)

    Events.on("NETWORK_WORLD_SNAPSHOT", function(data)
        if not data then
            return
        end

        if data.snapshot then
            self._worldSnapshot = Util.deepCopy(data.snapshot)
        else
            self._worldSnapshot = nil
        end
    end)
end

function NetworkManager:startHost(port)
    if self._isMultiplayer then
        return false
    end

    local Constants = require("src.core.constants")
    self.server = NetworkServer.new(port or Constants.NETWORK.DEFAULT_PORT)
    if not self.server:start() then
        return false
    end

    self._isHost = true
    self._isMultiplayer = true
    self._localPlayerId = 0

    local hostName = string.format("Host_%d", os.time())
    -- Generate a proper spawn position for the host (around the hub station)
    local spawnPosition = self.server:_generateSpawnPosition()
    self.server:addHostPlayer(hostName, {
        position = spawnPosition,
        velocity = { x = 0, y = 0 }
    })

    self._players = {}
    self._players[0] = {
        playerId = 0,
        playerName = hostName,
        state = {
            position = spawnPosition,
            velocity = { x = 0, y = 0 }
        }
    }

    if self._pendingWorldSnapshot then
        self.server:updateWorldSnapshot(self._pendingWorldSnapshot)
    end

    Events.emit("NETWORK_PLAYER_JOINED", {
        playerId = 0,
        playerName = hostName,
        isSelf = true,
        data = self._players[0].state
    })

    Log.info("Started hosting multiplayer game")
    return true
end

function NetworkManager:joinGame(address, port)
    if self._isMultiplayer then
        return false, "Already in multiplayer"
    end

    -- Reset connection attempts for fresh connection attempt
    if self.client then
        self.client:resetConnectionAttempts()
    end

    local Constants = require("src.core.constants")
    local ok, err = self.client:connect(address or "localhost", port or Constants.NETWORK.DEFAULT_PORT)
    if not ok then
        return false, err
    end

    self._isHost = false
    self._isMultiplayer = true
    self._players = {}
    self._localPlayerId = nil

    Log.info("Attempting to join host", address or "localhost", port or Constants.NETWORK.DEFAULT_PORT)
    return true
end

function NetworkManager:leaveGame()
    if not self._isMultiplayer then
        return
    end

    if self._isHost and self.server then
        self.server:stop()
    elseif self.client then
        self.client:disconnect()
    end

    self._isHost = false
    self._isMultiplayer = false
    self._players = {}
    self._localPlayerId = nil
    self._worldSnapshot = nil

    Log.info("Left multiplayer session")
end

function NetworkManager:update(dt)
    if not self._isMultiplayer then
        return
    end

    if self._isHost then
        if self.server then
            self.server:update(dt)
            for _, event in ipairs(self.server:pullEvents()) do
                if event.type == "state" then
                    local payload = event.payload or {}
                    if payload.playerId ~= nil then
                        self._players[payload.playerId] = self._players[payload.playerId] or {}
                        self._players[payload.playerId].playerId = payload.playerId
                        self._players[payload.playerId].playerName = payload.name or self._players[payload.playerId].playerName
                        self._players[payload.playerId].state = payload.state or self._players[payload.playerId].state
                    end
                elseif event.type == "joined" then
                    local payload = event.payload or {}
                    if payload.playerId ~= nil then
                        self._players[payload.playerId] = {
                            playerId = payload.playerId,
                            playerName = payload.name,
                            state = payload.state
                        }
                    end
                elseif event.type == "left" then
                    local payload = event.payload or {}
                    if payload.playerId ~= nil then
                        self._players[payload.playerId] = nil
                    end
                elseif event.type == "world_snapshot" then
                    local payload = event.payload or {}
                    if payload.snapshot then
                        self._worldSnapshot = Util.deepCopy(payload.snapshot)
                    else
                        self._worldSnapshot = nil
                    end
                end
            end
        end
    else
        if self.client then
            -- Check connection health and attempt reconnection if needed
            if not self.client:isConnected() and self.client:getConnectionState() == "disconnected" then
                if self.client:canAttemptConnection() then
                    Log.info("Attempting to reconnect to server...")
                    local ok, err = self.client:connect()
                    if not ok then
                        Log.warn("Reconnection failed:", err)
                    end
                end
            end
            
            self.client:update(dt)
            -- Only update players every 0.1 seconds instead of every frame
            local currentTime = love.timer.getTime()
            if currentTime - self._lastPlayerUpdate > 0.1 then
                self._players = shallowCopy(self.client:getPlayers())
                self._lastPlayerUpdate = currentTime
            end
            if self.client.playerId then
                self._localPlayerId = self.client.playerId
            end
        end
    end
end

function NetworkManager:updateWorldSnapshot(snapshot, peer)
    if snapshot ~= nil then
        self._pendingWorldSnapshot = Util.deepCopy(snapshot)
    else
        self._pendingWorldSnapshot = nil
    end

    if not self._isHost or not self.server then
        return
    end

    self.server:updateWorldSnapshot(snapshot, peer)
end

function NetworkManager:getWorldSnapshot()
    if not self._worldSnapshot then
        return nil
    end

    return Util.deepCopy(self._worldSnapshot)
end

function NetworkManager:sendPlayerUpdate(playerData)
    if not self._isMultiplayer then
        return
    end

    if self._isHost then
        if self.server then
            self.server:updateHostState(playerData)
            self._players[0] = self._players[0] or {}
            self._players[0].playerId = 0
            self._players[0].playerName = self._players[0].playerName or "Host"
            self._players[0].state = playerData
        end
    else
        if self.client and self.client:isConnected() then
            self.client:sendPlayerUpdate(playerData)
        end
    end
end

function NetworkManager:sendEnemyUpdate(enemyData)
    if not self._isMultiplayer or not self._isHost then
        return
    end

    if self.server then
        -- Send enemy updates to all connected clients
        self.server:broadcastEnemyUpdate(enemyData)
    end
end

function NetworkManager:sendProjectileUpdate(projectileData)
    if not self._isMultiplayer or not self._isHost then
        return
    end

    if self.server then
        -- Send projectile updates to all connected clients
        self.server:broadcastProjectileUpdate(projectileData)
    end
end

function NetworkManager:sendWeaponFireRequest(requestData)
    if not self._isMultiplayer or self._isHost then
        return
    end

    if self.client and self.client:isConnected() then
        -- Send weapon fire request to host
        self.client:sendWeaponFireRequest(requestData)
    end
end

function NetworkManager:getPlayers()
    return self._players
end

function NetworkManager:getPlayerCount()
    local count = 0
    for _ in pairs(self._players) do
        count = count + 1
    end
    return count > 0 and count or 1
end

function NetworkManager:getPing()
    if self._isHost then
        return 0
    end
    if self.client then
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
        return self.server ~= nil
    end

    return self.client and self.client:isConnected() or false
end

function NetworkManager:getLocalPlayerId()
    return self._localPlayerId
end

return NetworkManager
