--[[
    Network Server
    Handles server-side networking for multiplayer gameplay
]]

local Log = require("src.core.log")
local Events = require("src.core.events")
local json = require("src.libs.json")

local NetworkServer = {}
NetworkServer.__index = NetworkServer

-- Message types shared with the client
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


function NetworkServer.new(port)
    local self = setmetatable({}, NetworkServer)

    self.port = port or 7777
    self.transport = "none"
    self.fileNetwork = nil

    self.players = {}
    self.nextPlayerId = 1  -- Clients start from ID 1, host is ID 0
    self.isRunning = false

    self.lastCleanup = 0
    self.cleanupInterval = 10.0

    -- Track ENet peers so we can target responses and filter broadcasts
    self.connectedPeers = {}
    self.peerToPlayerId = {}
    self.playerToPeer = {}


    return self
end

function NetworkServer:start()
    if self.isRunning then
        Log.warn("Server already running")
        return false
    end

    Log.info("Starting server on port", self.port)

    -- Try ENet transport first
    local ok, EnetTransport = pcall(require, "src.core.network.transport.enet")
    if ok and EnetTransport and EnetTransport.isAvailable() then
        local server, err = EnetTransport.createServer(self.port)
        if server then
            self.enetServer = server
            self.transport = "enet"
            self.isRunning = true
            self.connectedPeers = {}
            self.peerToPlayerId = {}
            self.playerToPeer = {}
            Log.info("Server started with ENet transport on port", self.port)
            Events.emit("NETWORK_SERVER_STARTED", { port = self.port })
            return true
        else
            Log.error("Failed to create ENet server:", err)
        end
    end

    -- Fallback to file-based networking for local testing
    local ok, FileNetwork = pcall(require, "src.core.network.file_network")
    if ok and FileNetwork then
        local fileNetworkInstance = FileNetwork.new(self.port, true)
        if fileNetworkInstance then
            self.fileNetwork = fileNetworkInstance
            self.transport = "file"
            self.isRunning = true
            self.connectedPeers = {}
            self.peerToPlayerId = {}
            self.playerToPeer = {}
            Log.info("Server started with file-based transport on port", self.port)
            Events.emit("NETWORK_SERVER_STARTED", { port = self.port })
            return true
        else
            Log.error("Failed to create FileNetwork instance")
        end
    else
        Log.error("Failed to load FileNetwork module")
    end

    Log.error("Failed to start server")
    self.transport = "none"
    self.isRunning = false
    return false
end

function NetworkServer:stop()
    if not self.isRunning then
        return
    end

    if self.transport == "enet" and self.enetServer then
        local EnetTransport = require("src.core.network.transport.enet")
        EnetTransport.destroy(self.enetServer)
        self.enetServer = nil
    elseif self.transport == "file" then
        self.fileNetwork = nil
    end

    self.transport = "none"
    self.isRunning = false
    self.players = {}
    self.nextPlayerId = 1
    self.lastCleanup = 0
    self.connectedPeers = {}
    self.peerToPlayerId = {}
    self.playerToPeer = {}

    Log.info("Server stopped")
    Events.emit("NETWORK_SERVER_STOPPED")
end

local function snapshotPlayers(players, excludeId)
    local out = {}
    for id, player in pairs(players) do
        if id ~= excludeId then
            out[#out + 1] = {
                playerId = id,
                name = player.name,
                data = player.data
            }
        end
    end
    return out
end

local function normalizePeer(self, peerOrId)
    if type(peerOrId) == "userdata" then
        return peerOrId
    end

    if type(peerOrId) == "number" then
        return self.playerToPeer[peerOrId]
    end

    if type(peerOrId) == "table" and peerOrId.peer then
        return peerOrId.peer
    end

    return nil
end

local function registerPeerForPlayer(self, playerId, peer)
    if not playerId or not peer or type(peer) ~= "userdata" then
        return
    end

    -- Clear any existing peer mapping for this player to prevent stale disconnect issues
    if self.playerToPeer[playerId] then
        local oldPeer = self.playerToPeer[playerId]
        self.peerToPlayerId[oldPeer] = nil
        self.connectedPeers[oldPeer] = nil
        Log.info("Cleared old peer mapping for player", playerId, "to prevent stale disconnect")
    end

    self.peerToPlayerId[peer] = playerId
    self.playerToPeer[playerId] = peer
    self.connectedPeers[peer] = true
    Log.info("Registered new peer for player", playerId)
end

local function unregisterPeerForPlayer(self, playerId, peer)
    local targetPeer = normalizePeer(self, peer)

    if not targetPeer and playerId then
        targetPeer = self.playerToPeer[playerId]
    end

    if targetPeer then
        local mappedPlayerId = self.peerToPlayerId[targetPeer]
        self.peerToPlayerId[targetPeer] = nil
        self.connectedPeers[targetPeer] = nil
        Log.info("Unregistered peer for player", mappedPlayerId or "unknown")
    end

    if playerId then
        self.playerToPeer[playerId] = nil
        Log.info("Cleared player-to-peer mapping for player", playerId)
    end
end


function NetworkServer:update(dt)
    if not self.isRunning then
        return
    end

    if self.transport == "enet" and self.enetServer then
        local EnetTransport = require("src.core.network.transport.enet")
        local json = require("src.libs.json")

        -- Poll for ENet events
        local event = EnetTransport.service(self.enetServer, 0)
        while event do
            if event.type == "connect" then
                Log.info("Client connected:", event.peer)
                self.connectedPeers[event.peer] = true
            elseif event.type == "receive" then
                local success, message = pcall(json.decode, event.data)
                if success and message then
                    self:handleMessage(message, event.peer)
                end
            elseif event.type == "disconnect" then
                Log.info("Client disconnected:", event.peer)
                local playerId = self.peerToPlayerId[event.peer]
                self.connectedPeers[event.peer] = nil
                if playerId then
                    -- Check if this player is still active on another peer
                    local currentPeer = self.playerToPeer[playerId]
                    if currentPeer and currentPeer ~= event.peer then
                        Log.info("Player", playerId, "is still active on another peer, not removing from server")
                        -- Just unregister the disconnected peer, don't remove the player
                        unregisterPeerForPlayer(self, nil, event.peer)
                    else
                        -- This is the only peer for this player, safe to remove
                        self:handlePlayerLeave({ playerId = playerId }, event.peer)
                    end
                else
                    unregisterPeerForPlayer(self, nil, event.peer)
                end
            end
            event = EnetTransport.service(self.enetServer, 0)
        end
    elseif self.transport == "file" and self.fileNetwork then
        local messages = self.fileNetwork:receiveMessages()
        if messages then
            for _, packet in ipairs(messages) do
                if packet.message then
                    self:handleMessage(packet.message, packet)
                end
            end
            self.fileNetwork:cleanup()
        end
    end

    self.lastCleanup = self.lastCleanup + dt
    if self.lastCleanup >= self.cleanupInterval then
        self:cleanupDisconnectedPlayers()
        self.lastCleanup = 0
    end
end

function NetworkServer:handleMessage(message, peer)
    local playerId = nil

    if type(peer) == "table" and peer.from == "client" then
        playerId = peer.message and peer.message.playerId or nil
    end

    if playerId and self.players[playerId] then
        self.players[playerId].lastSeen = currentTime()
    end

    if message.type == MESSAGE_TYPES.PLAYER_JOIN then
        self:handlePlayerJoin(message, peer)
    elseif message.type == MESSAGE_TYPES.PLAYER_LEAVE then
        self:handlePlayerLeave(message, peer)
    elseif message.type == MESSAGE_TYPES.PLAYER_UPDATE then
        self:handlePlayerUpdate(message, peer)
    elseif message.type == MESSAGE_TYPES.PING then
        self:handlePing(message, peer)
    end
end

function NetworkServer:handlePlayerJoin(message, peer)
    local playerId = self.nextPlayerId
    self.nextPlayerId = self.nextPlayerId + 1

    local playerName = message.playerName or ("Player" .. playerId)

    local player = {
        id = playerId,
        name = playerName,
        lastSeen = currentTime(),
        data = {}
    }

    self.players[playerId] = player
    registerPeerForPlayer(self, playerId, normalizePeer(self, peer))

    -- Acknowledge the new player with their assigned ID and a view of current players.
    self:sendToPeer(peer, {
        type = MESSAGE_TYPES.PLAYER_JOIN,
        playerId = playerId,
        players = snapshotPlayers(self.players, playerId),
        timestamp = currentTime()
    }, true)

    -- Notify other players about the newcomer.
    self:broadcastToOthers(playerId, {
        type = MESSAGE_TYPES.PLAYER_JOIN,
        playerId = playerId,
        playerName = playerName,
        data = player.data
    })

    Log.info("Player joined:", playerName, "(" .. playerId .. ")")
    Log.info("Server now has", self:getPlayerCount(), "players total")
    Events.emit("NETWORK_PLAYER_JOINED", { playerId = playerId, player = player })
end

function NetworkServer:handlePlayerLeave(message, peer)
    local playerId = message.playerId

    if not playerId or not self.players[playerId] then
        unregisterPeerForPlayer(self, playerId, normalizePeer(self, peer))
        return
    end

    local player = self.players[playerId]
    self.players[playerId] = nil
    unregisterPeerForPlayer(self, playerId, normalizePeer(self, peer))

    self:broadcastToOthers(playerId, {
        type = MESSAGE_TYPES.PLAYER_LEAVE,
        playerId = playerId,
        timestamp = currentTime()
    })

    Log.info("Player left:", player.name, "(" .. playerId .. ")")
    Events.emit("NETWORK_PLAYER_LEFT", { playerId = playerId, player = player })
end

function NetworkServer:handlePlayerUpdate(message, peer)
    local playerId = message.playerId

    if not playerId or not self.players[playerId] then
        return
    end

    local player = self.players[playerId]
    registerPeerForPlayer(self, playerId, normalizePeer(self, peer))
    player.data = message.data
    player.lastSeen = currentTime()

    local updatePayload = {
        type = MESSAGE_TYPES.PLAYER_UPDATE,
        playerId = playerId,
        data = message.data,
        timestamp = currentTime()
    }

    self:broadcastToOthers(playerId, updatePayload)

    local snapshot = {}
    if message.data then
        for key, value in pairs(message.data) do
            snapshot[key] = value
        end
    end
    snapshot.playerId = snapshot.playerId or playerId
    if player.name then
        snapshot.playerName = snapshot.playerName or player.name
    end

    Events.emit("NETWORK_PLAYER_UPDATED", {
        playerId = playerId,
        data = snapshot
    })
end


function NetworkServer:handlePing(message, peer)
    local playerId = message.playerId
    if playerId and self.players[playerId] then
        self.players[playerId].lastSeen = currentTime()
    end

    self:sendToPeer(peer, {
        type = MESSAGE_TYPES.PONG,
        timestamp = message.timestamp
    }, false)
end


function NetworkServer:sendToPeer(peer, message, reliable)
    reliable = reliable ~= false

    if self.transport == "enet" and self.enetServer then
        local targetPeer = normalizePeer(self, peer)
        if not targetPeer then
            return false
        end

        local EnetTransport = require("src.core.network.transport.enet")
        local json = require("src.libs.json")
        local data = json.encode(message)
        local success, err = EnetTransport.send({ peer = targetPeer }, data, 0, reliable)
        if not success then
            Log.warn("Failed to send message to peer:", err)
            return false
        end
        return true
    elseif self.transport == "file" and self.fileNetwork then
        return self.fileNetwork:sendMessage(message)
    end
    return false
end

function NetworkServer:broadcast(message, reliable)
    if self.transport == "enet" and self.enetServer then
        self:broadcastToOthers(nil, message, reliable)
    elseif self.transport == "file" and self.fileNetwork then
        self.fileNetwork:sendMessage(message)
    end
end

function NetworkServer:broadcastToOthers(excludePlayerId, message, reliable)
    reliable = reliable ~= false

    if self.transport == "enet" and self.enetServer then
        local EnetTransport = require("src.core.network.transport.enet")
        local json = require("src.libs.json")
        local data = json.encode(message)

        for peer in pairs(self.connectedPeers) do
            local playerId = self.peerToPlayerId[peer]
            if not excludePlayerId or playerId ~= excludePlayerId then
                local success, err = EnetTransport.send({ peer = peer }, data, 0, reliable)
                if not success then
                    Log.warn("Failed to send message to peer:", err)
                end
            end
        end
    elseif self.transport == "file" and self.fileNetwork then
        self.fileNetwork:sendMessage(message)
    end
end

function NetworkServer:cleanupDisconnectedPlayers()
    local now = currentTime()
    local timeout = 30.0

    for playerId, player in pairs(self.players) do
        if now - player.lastSeen > timeout then
            Log.info("Cleaning up stale player:", player.name, "(" .. playerId .. ")")
            self.players[playerId] = nil
            unregisterPeerForPlayer(self, playerId)
            self:broadcastToOthers(playerId, {
                type = MESSAGE_TYPES.PLAYER_LEAVE,
                playerId = playerId,
                timestamp = now
            })
            Events.emit("NETWORK_PLAYER_LEFT", { playerId = playerId, player = player })
        end
    end
end

function NetworkServer:getPlayers()
    return self.players
end

function NetworkServer:getPlayerCount()
    local count = 0
    for playerId, player in pairs(self.players) do
        count = count + 1
    end
    return count
end

function NetworkServer:isRunning()
    return self.isRunning
end

function NetworkServer:addHostPlayer(playerName, initialData)
    if not self.isRunning then
        return
    end
    
    local hostPlayerId = 0  -- Host gets ID 0, clients get 1, 2, 3, etc.
    local player = {
        id = hostPlayerId,
        name = playerName,
        data = initialData or {},
        lastSeen = currentTime()
    }
    
    self.players[hostPlayerId] = player
    Log.info("Added host player to server:", playerName, "ID:", hostPlayerId)
end

function NetworkServer:updateHostPlayer(playerData)
    if not self.isRunning then
        return
    end
    
    -- Find the host player (ID 0)
    local hostPlayerId = 0
    if self.players[hostPlayerId] then
        Log.info("Updating host player data for ID:", hostPlayerId)
        self.players[hostPlayerId].data = playerData
        self.players[hostPlayerId].lastSeen = currentTime()
        
        -- Broadcast the update to all clients
        self:broadcastToOthers(hostPlayerId, {
            type = MESSAGE_TYPES.PLAYER_UPDATE,
            playerId = hostPlayerId,
            data = playerData,
            timestamp = currentTime()
        })
    else
        Log.warn("Host player not found with ID:", hostPlayerId)
    end
end

return NetworkServer
