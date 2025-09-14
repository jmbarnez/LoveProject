--[[
  Multiplayer Manager
  Coordinates networking with game state
]]

-- ENet networking module
local Network = require("src.core.network")
local Log = require("src.core.log")
Log.info("Using ENet networking")
local RemotePlayer = require("src.entities.remote_player")

local Multiplayer = {}

-- State
local remotePlayers = {} -- playerId -> RemotePlayer entity
local world = nil
local localPlayer = nil
local updateTimer = 0
local updateInterval = 1/60 -- Send updates 60 times per second for smooth movement
local debugUpdateCount = 0 -- For debugging first few network updates

-- Initialize multiplayer system
function Multiplayer.init(gameWorld, player)
    world = gameWorld
    localPlayer = player
    Network.init()
    Log.info("Multiplayer system initialized")
end

-- Host a multiplayer game
function Multiplayer.host(port)
    return Network.host(port)
end

-- Join a multiplayer game
function Multiplayer.join(ip, port)
    return Network.join(ip, port)
end

-- Disconnect from multiplayer
function Multiplayer.disconnect()
    -- Remove all remote players from world
    for playerId, remotePlayer in pairs(remotePlayers) do
        if world then
            world:removeEntity(remotePlayer)
        end
    end
    remotePlayers = {}
    
    Network.disconnect()
    Log.info("Multiplayer disconnected")
end

-- Update multiplayer system
function Multiplayer.update(dt)
    if not Network.isConnected() then return end
    
    -- Update networking
    Network.update(dt)
    
    -- Send local player updates
    updateTimer = updateTimer + dt
    if updateTimer >= updateInterval and localPlayer then
        Network.sendPlayerUpdate(localPlayer)
        updateTimer = 0
        
        -- Track update count for potential debugging
        debugUpdateCount = debugUpdateCount + 1
    end
    
    -- Update remote players from network data
    local networkPlayers = Network.getPlayers()
    local localPlayerId = Network.getLocalPlayerId()
    
    local playerCount = 0
    for _ in pairs(networkPlayers) do playerCount = playerCount + 1 end
    
    if playerCount > 1 and debugUpdateCount % 120 == 0 then -- Debug every 2 seconds
        Log.info("Multiplayer:", playerCount, "players in network data")
    end
    
    for playerId, playerData in pairs(networkPlayers) do
        if playerId ~= localPlayerId then
            Multiplayer.updateRemotePlayer(playerId, playerData)
        end
    end
    
    -- Interpolate remote player positions
    for playerId, remotePlayer in pairs(remotePlayers) do
        remotePlayer:interpolate(dt)
        
        -- Remove timed out players
        if remotePlayer:shouldTimeout() then
            Log.warn("Remote player timed out:", playerId)
            if world then
                world:removeEntity(remotePlayer)
            end
            remotePlayers[playerId] = nil
        end
    end
end

-- Update or create remote player
function Multiplayer.updateRemotePlayer(playerId, playerData)
    local remotePlayer = remotePlayers[playerId]
    
    if not remotePlayer then
        -- Create new remote player
        remotePlayer = RemotePlayer.new(playerId, playerData.x or 0, playerData.y or 0)
        if remotePlayer and world then
            remotePlayers[playerId] = remotePlayer
            world:addEntity(remotePlayer)
            Log.info("Added remote player:", playerId)
        end
    else
        -- Update existing remote player
        remotePlayer:updateFromNetwork(playerData)
    end
end

-- Send projectile spawn to network
function Multiplayer.sendProjectileSpawn(projectileData)
    if not Network.isConnected() then return end
    
    local message = {
        type = Network.MessageType.PROJECTILE_SPAWN,
        playerId = Network.getLocalPlayerId(),
        projectile = projectileData,
        timestamp = love.timer.getTime()
    }
    
    if Network.isHost() then
        Network.broadcastToPeers(message)
    else
        Network.sendToServer(message)
    end
end

-- Getter functions
function Multiplayer.isConnected()
    return Network.isConnected()
end

function Multiplayer.isHost()
    return Network.isHost()
end

function Multiplayer.getRemotePlayers()
    return remotePlayers
end

function Multiplayer.getPlayerCount()
    local count = Network.isConnected() and 1 or 0 -- Local player
    for _ in pairs(remotePlayers) do
        count = count + 1
    end
    return count
end

function Multiplayer.getNetworkStats()
    return {
        connected = Network.isConnected(),
        isHost = Network.isHost(),
        playerCount = Multiplayer.getPlayerCount(),
        localPlayerId = Network.getLocalPlayerId(),
        discoveredServers = Network.getDiscoveredServers()
    }
end

return Multiplayer
