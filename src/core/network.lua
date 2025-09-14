--[[
  Real ENet Networking Module for DarkOrbitLove
  Client-server networking using ENet
]]

local enet = require("enet")
local Log = require("src.core.log")

local enetAvailable = (enet ~= nil)

local json = require("src.libs.json")

local Network = {}

-- Network state
local isHost = false
local isConnected = false
local localPlayerId = nil
local host = nil
local peers = {} -- Connected peers (ENet peers)
local hostIP = "127.0.0.1"
local hostPort = 25565
local players = {} -- Remote player data
local discoveredServers = {} -- List of discovered LAN servers

-- Message types
Network.MessageType = {
    PLAYER_JOIN = "player_join",
    PLAYER_LEAVE = "player_leave", 
    PLAYER_UPDATE = "player_update",
    PROJECTILE_SPAWN = "projectile_spawn",
    ENTITY_DAMAGE = "entity_damage",
    PING = "ping",
    PONG = "pong",
    SERVER_ANNOUNCE = "server_announce",
    SERVER_DISCOVERY = "server_discovery"
}

-- Initialize networking
function Network.init()
    if not enetAvailable then
        Log.warn("ENet not available. Networking disabled.")
        return false
    end
    
    localPlayerId = "player_" .. math.random(1000, 9999)
    Log.info("ENet Network initialized. Player ID:", localPlayerId)
    Log.info("ENet version:", enet.linked_version())
    return true
end

-- Host a game
function Network.host(port)
    if not enetAvailable then
        Log.warn("Cannot host: ENet not available")
        return false
    end
    
    -- Initialize if not already done
    if not localPlayerId then
        Network.init()
    end
    
    port = port or hostPort
    
    -- Create ENet host
    host = enet.host_create("*:" .. port, 32) -- Allow up to 32 connections
    if not host then
        Log.error("Failed to create ENet host on port", port)
        return false
    end
    
    isHost = true
    isConnected = true
    hostPort = port
    peers = {}
    players = {}
    
    -- Add ourselves as the host player
    players[localPlayerId] = {
        id = localPlayerId,
        x = 2500, y = 2500, angle = 0,
        health = 100,
        lastUpdate = love.timer.getTime(),
        isLocal = true
    }
    
    Log.info("ENet: Hosting game on port", port)
    Log.info("ENet: Host ready for connections")
    Log.info("ENet: Host object:", tostring(host))
    
    return true
end

-- Join a game
function Network.join(ip, port)
    if not enetAvailable then
        Log.warn("Cannot join: ENet not available")
        return false
    end
    
    -- Initialize if not already done
    if not localPlayerId then
        Network.init()
    end
    
    ip = ip or "127.0.0.1"
    port = port or hostPort
    
    -- Create ENet client host
    host = enet.host_create()
    if not host then
        Log.error("Failed to create ENet client")
        return false
    end
    
    -- Connect to server
    local server = host:connect(ip .. ":" .. port)
    if not server then
        Log.error("Failed to create connection to", ip .. ":" .. tostring(port))
        host:destroy()
        host = nil
        return false
    end
    
    isHost = false
    isConnected = false -- Will be set to true when connection is established
    hostIP = ip
    hostPort = port
    peers = {}
    players = {}
    
    -- Store the server peer for reference
    peers[server] = server
    
    Log.info("ENet: Attempting to connect to", ip .. ":" .. tostring(port))
    
    -- Try to establish connection with a timeout
    local timeout = 5000 -- 5 seconds
    local startTime = love.timer.getTime()
    
    while (love.timer.getTime() - startTime) < timeout / 1000 do
        local event = host:service(100) -- 100ms timeout for each service call
        if event then
            Log.info("ENet: Received event:", event.type)
            if event.type == "connect" then
                Log.info("ENet: Connection established!")
                isConnected = true
                return true
            elseif event.type == "disconnect" then
                Log.warn("ENet: Connection refused by server")
                host:destroy()
                host = nil
                return false
            end
        else
            -- print("ENet: No event, still waiting...")
        end
    end
    
    Log.warn("ENet: Connection timeout")
    host:destroy()
    host = nil
    return false
end

-- Disconnect from game
function Network.disconnect()
    if isConnected and host then
        local leaveMsg = {
            type = Network.MessageType.PLAYER_LEAVE,
            playerId = localPlayerId,
            timestamp = love.timer.getTime()
        }
        
        if isHost then
            Network.broadcastToPeers(leaveMsg)
        else
            Network.sendToServer(leaveMsg)
        end
        
        -- Give a moment for message to send
        host:flush()
    end
    
    if host then
        host:destroy()
        host = nil
    end
    
    isHost = false
    isConnected = false
    peers = {}
    players = {}
    
    Log.info("ENet: Disconnected from network")
end

-- Send message to server (client only)
function Network.sendToServer(message)
    if not host or isHost then return false end
    
    local data = json.encode(message)
    for peer in pairs(peers) do
        peer:send(data)
        break -- Should only be one server peer for clients
    end
    
    return true
end

-- Send message to specific peer
function Network.sendToPeer(peer, message)
    if not host or not peer then return false end
    
    local data = json.encode(message)
    peer:send(data)
    
    return true
end

-- Broadcast to all peers (host only)
function Network.broadcastToPeers(message)
    if not isHost or not host then return end
    
    local data = json.encode(message)
    for peer in pairs(peers) do
        peer:send(data)
    end
end

-- Update networking (call every frame)
function Network.update(dt)
    if not host then return end
    
    -- Process ENet events
    local event = host:service(0) -- Non-blocking
    while event do
        if event.type == "connect" then
            Network.handleConnect(event.peer)
        elseif event.type == "receive" then
            Network.handleReceive(event.peer, event.data)
        elseif event.type == "disconnect" then
            Network.handleDisconnect(event.peer)
        end
        
        event = host:service(0)
    end
    
    -- Clean up old players
    local currentTime = love.timer.getTime()
    for playerId, player in pairs(players) do
        if playerId ~= localPlayerId and (currentTime - player.lastUpdate) > 5.0 then
            Log.warn("ENet: Player timed out:", playerId)
            players[playerId] = nil
        end
    end
end

-- Handle ENet connection event
function Network.handleConnect(peer)
    if isHost then
        peers[peer] = peer
        Log.info("ENet: Client connected from", peer:connect_id())
        
        -- Send welcome message with current players
        local welcomeMsg = {
            type = "welcome",
            players = players,
            timestamp = love.timer.getTime()
        }
        Network.sendToPeer(peer, welcomeMsg)
    else
        peers[peer] = peer
        isConnected = true
        Log.info("ENet: Connected to server")
        
        -- Send join message
        local joinMsg = {
            type = Network.MessageType.PLAYER_JOIN,
            playerId = localPlayerId,
            timestamp = love.timer.getTime()
        }
        Network.sendToPeer(peer, joinMsg)
        
        -- Add ourselves as a player
        players[localPlayerId] = {
            id = localPlayerId,
            x = 2500, y = 2500, angle = 0,
            health = 100,
            lastUpdate = love.timer.getTime(),
            isLocal = true
        }
    end
end

-- Handle ENet message received
function Network.handleReceive(peer, data)
    local success, message = pcall(json.decode, data)
    if success then
        Network.handleMessage(message, peer)
    else
        Log.warn("ENet: Failed to decode message:", tostring(data))
    end
end

-- Handle ENet disconnection event
function Network.handleDisconnect(peer)
    -- Find the player ID for this peer
    local disconnectedPlayerId = nil
    for playerId, player in pairs(players) do
        if player.peer == peer then
            disconnectedPlayerId = playerId
            break
        end
    end
    
    if disconnectedPlayerId then
        players[disconnectedPlayerId] = nil
        Log.info("ENet: Player disconnected:", disconnectedPlayerId)
        
        if isHost then
            -- Broadcast leave message to other clients
            local leaveMsg = {
                type = Network.MessageType.PLAYER_LEAVE,
                playerId = disconnectedPlayerId,
                timestamp = love.timer.getTime()
            }
            Network.broadcastToPeers(leaveMsg)
        end
    end
    
    peers[peer] = nil
    
    if not isHost then
        isConnected = false
        Log.info("ENet: Disconnected from server")
    end
end

-- Handle incoming message
function Network.handleMessage(message, peer)
    if not message or not message.type then return end
    
    if message.type == Network.MessageType.PLAYER_JOIN then
        Network.handlePlayerJoin(message, peer)
    elseif message.type == Network.MessageType.PLAYER_LEAVE then
        Network.handlePlayerLeave(message)
    elseif message.type == Network.MessageType.PLAYER_UPDATE then
        Network.handlePlayerUpdate(message)
    elseif message.type == Network.MessageType.PROJECTILE_SPAWN then
        Network.handleProjectileSpawn(message)
    elseif message.type == "welcome" then
        Network.handleWelcome(message)
    end
end

-- Handle player join
function Network.handlePlayerJoin(message, peer)
    local playerId = message.playerId
    
    if isHost then
        -- Add player to game
        players[playerId] = {
            id = playerId,
            peer = peer,
            x = 2500, y = 2500, angle = 0,
            health = 100,
            lastUpdate = love.timer.getTime(),
            isLocal = false
        }
        
        -- Broadcast new player to existing clients
        local joinBroadcast = {
            type = Network.MessageType.PLAYER_JOIN,
            playerId = playerId,
            playerData = players[playerId],
            timestamp = love.timer.getTime()
        }
        Network.broadcastToPeers(joinBroadcast)
        
        Log.info("ENet: Player joined:", playerId)
    else
        -- Client received join notification
        if playerId ~= localPlayerId then
            players[playerId] = message.playerData or {
                id = playerId,
                x = 2500, y = 2500, angle = 0,
                health = 100,
                lastUpdate = love.timer.getTime(),
                isLocal = false
            }
            Log.info("ENet: Player joined the game:", playerId)
        end
    end
end

-- Handle welcome message (client only)
function Network.handleWelcome(message)
    if message.players then
        for playerId, playerData in pairs(message.players) do
            if playerId ~= localPlayerId then
                players[playerId] = playerData
                players[playerId].isLocal = false
            end
        end
        Log.info("ENet: Received welcome message. Players in game:", table.maxn(players))
    end
end

-- Handle player leave
function Network.handlePlayerLeave(message)
    local playerId = message.playerId
    
    if players[playerId] then
        players[playerId] = nil
        Log.info("Player left the game:", playerId)
    end
    
    if isHost and peers[playerId] then
        peers[playerId] = nil
        -- Broadcast leave to other players
        Network.broadcastToPeers(message)
    end
end

-- Handle player update
function Network.handlePlayerUpdate(message)
    local playerId = message.playerId
    if playerId == localPlayerId then return end -- Ignore our own updates
    
    players[playerId] = players[playerId] or {}
    local player = players[playerId]
    
    player.id = playerId
    player.x = message.x
    player.y = message.y
    player.angle = message.angle
    player.vx = message.vx or 0
    player.vy = message.vy or 0
    player.health = message.health or player.health
    player.maxHealth = message.maxHealth or player.maxHealth
    player.energy = message.energy or player.energy
    player.isBoosting = message.isBoosting or false
    player.isLocal = false
    player.lastUpdate = love.timer.getTime()
    
    Log.info("Network: Updated player", playerId, "at (", player.x, ",", player.y, ")")
end

-- Handle projectile spawn
function Network.handleProjectileSpawn(message)
    -- This will be implemented when we sync projectiles
    Log.info("Received projectile spawn from", message.playerId)
end

-- Send our player update
function Network.sendPlayerUpdate(player)
    if not isConnected or not player then return end
    
    -- Get velocity from physics body for smoother prediction
    local vx, vy = 0, 0
    if player.components.physics and player.components.physics.body then
        vx = player.components.physics.body.vx or 0
        vy = player.components.physics.body.vy or 0
    end
    
    local updateMsg = {
        type = Network.MessageType.PLAYER_UPDATE,
        playerId = localPlayerId,
        x = player.components.position.x,
        y = player.components.position.y,
        angle = player.components.position.angle or player.angle or 0,
        vx = vx,
        vy = vy,
        health = player.components.health and player.components.health.current or 100,
        maxHealth = player.components.health and player.components.health.max or 100,
        energy = player.components.energy and player.components.energy.current or 100,
        isBoosting = player.isBoosting or false,
        timestamp = love.timer.getTime()
    }
    
    if isHost then
        Network.broadcastToPeers(updateMsg)
        -- print("Network: Broadcasting update for " .. localPlayerId)
    else
        Network.sendToServer(updateMsg)
        -- print("Network: Sending update to server for " .. localPlayerId)
    end
end

-- Getter functions
function Network.isConnected() return isConnected end
function Network.isHost() return isHost end
function Network.getLocalPlayerId() return localPlayerId end
function Network.getPlayers() return players end
function Network.getPeers() return peers end

-- Server Discovery Functions (simplified for direct connection)
function Network.startServerDiscovery()
    discoveredServers = {}
    Log.info("ENet: Server discovery ready (manual IP connection)")
    return true
end

function Network.stopServerDiscovery()
    Log.info("ENet: Stopped server discovery")
end

function Network.getDiscoveredServers()
    -- Clean up old servers (older than 10 seconds)
    local currentTime = love.timer.getTime()
    for i = #discoveredServers, 1, -1 do
        if (currentTime - discoveredServers[i].lastSeen) > 10 then
            table.remove(discoveredServers, i)
        end
    end
    
    return discoveredServers
end

function Network.refreshServerList()
    Log.info("ENet: Server list refresh (use direct IP connection)")
    Network.startServerDiscovery()
end

return Network
