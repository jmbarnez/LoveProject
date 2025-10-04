--[[
    Network Synchronization System
    Handles sending and receiving player position updates in multiplayer
]]

local Events = require("src.core.events")
local Log = require("src.core.log")
local json = require("src.libs.json")

local NetworkSync = {}

local storeRemoteSnapshot
local updateRemotePlayer
local createRemotePlayer

-- Remote players storage
local remotePlayers = {}
local remotePlayerSnapshots = {}
local lastSentPosition = { x = 0, y = 0, angle = 0 }
local positionUpdateTimer = 0
local POSITION_UPDATE_INTERVAL = 1/20 -- 20 times per second

local function canonicalizePlayerId(playerId)
    if playerId == nil then
        return nil
    end
    if type(playerId) == "string" then
        return playerId
    end
    if type(playerId) == "number" then
        return tostring(playerId)
    end
    return tostring(playerId)
end

local function normalizePlayerDataId(data, fallbackId)
    if type(data) == "table" then
        if data.playerId ~= nil then
            return canonicalizePlayerId(data.playerId)
        end
        if data.data and data.data.playerId ~= nil then
            return canonicalizePlayerId(data.data.playerId)
        end
    end
    return canonicalizePlayerId(fallbackId)
end

-- Function definitions
storeRemoteSnapshot = function(playerId, data)
    local canonicalId = canonicalizePlayerId(playerId)
    if not canonicalId or not data then return end

    local payload = data
    if type(payload) == "table" and type(payload.data) == "table" then
        payload = payload.data
    end

    local snapshot = remotePlayerSnapshots[canonicalId] or { playerId = canonicalId }

    if type(payload.playerId) ~= "nil" then
        snapshot.playerId = payload.playerId
    elseif type(data.playerId) ~= "nil" then
        snapshot.playerId = data.playerId
    end

    if payload.playerName then
        snapshot.playerName = payload.playerName
    elseif data.playerName then
        snapshot.playerName = data.playerName
    end

    if payload.position then
        snapshot.position = snapshot.position or {}
        if payload.position.x ~= nil then
            snapshot.position.x = payload.position.x
        end
        if payload.position.y ~= nil then
            snapshot.position.y = payload.position.y
        end
        if payload.position.angle ~= nil then
            snapshot.position.angle = payload.position.angle
        end
    end

    if payload.velocity then
        snapshot.velocity = snapshot.velocity or {}
        if payload.velocity.x ~= nil then
            snapshot.velocity.x = payload.velocity.x
        end
        if payload.velocity.y ~= nil then
            snapshot.velocity.y = payload.velocity.y
        end
    end

    if payload.health then
        snapshot.health = snapshot.health or {}
        if payload.health.hp ~= nil then
            snapshot.health.hp = payload.health.hp
        end
        if payload.health.maxHp ~= nil then
            snapshot.health.maxHp = payload.health.maxHp
        elseif payload.health.maxHP ~= nil then
            snapshot.health.maxHp = payload.health.maxHP
        end
        if payload.health.shield ~= nil then
            snapshot.health.shield = payload.health.shield
        end
        if payload.health.maxShield ~= nil then
            snapshot.health.maxShield = payload.health.maxShield
        end
    end

    remotePlayerSnapshots[canonicalId] = snapshot
end

updateRemotePlayer = function(playerId, data, world)
    if not world then return end

    local canonicalId = canonicalizePlayerId(playerId)
    if not canonicalId then return end

    storeRemoteSnapshot(playerId, data)

    local remotePlayer = remotePlayers[canonicalId]

    if remotePlayer and data.playerName and remotePlayer.playerName ~= data.playerName then
        remotePlayer.playerName = data.playerName
    end

    -- Create remote player if it doesn't exist
    if not remotePlayer then
        Log.info("Creating remote player:", playerId)
        remotePlayer = createRemotePlayer(canonicalId, data, world)
        if remotePlayer then
            remotePlayers[canonicalId] = remotePlayer
        end
        return
    end

    -- Update existing remote player
    if remotePlayer.components and remotePlayer.components.position and data.position then
        -- Smooth position interpolation
        local pos = remotePlayer.components.position
        local targetPos = data.position
        
        -- Simple linear interpolation for smooth movement
        pos.x = pos.x + (targetPos.x - pos.x) * 0.3
        pos.y = pos.y + (targetPos.y - pos.y) * 0.3
        pos.angle = targetPos.angle or 0

        -- Update velocity if available
        if remotePlayer.components.velocity and data.velocity then
            remotePlayer.components.velocity.x = data.velocity.x
            remotePlayer.components.velocity.y = data.velocity.y
        end

        -- Update health if available
        if remotePlayer.components.health and data.health then
            local health = remotePlayer.components.health
            health.hp = data.health.hp
            health.maxHP = data.health.maxHp
            health.shield = data.health.shield
            health.maxShield = data.health.maxShield
        end
    end
end

createRemotePlayer = function(playerId, data, world)
    local EntityFactory = require("src.templates.entity_factory")

    local canonicalId = canonicalizePlayerId(playerId)

    -- Create a basic ship for the remote player
    local x = data.position and data.position.x or 0
    local y = data.position and data.position.y or 0

    local remotePlayer = EntityFactory.create("ship", "starter_frigate_basic", x, y)
    if not remotePlayer then
        Log.error("Failed to create remote player entity")
        return nil
    end

    -- Mark as remote player
    remotePlayer.isRemotePlayer = true
    remotePlayer.remotePlayerId = data.playerId or canonicalId
    remotePlayer.remotePlayerKey = canonicalId
    remotePlayer.playerName = data.playerName or ("Player " .. playerId)

    -- Set initial position
    if data.position then
        remotePlayer.components.position.x = data.position.x
        remotePlayer.components.position.y = data.position.y
        remotePlayer.components.position.angle = data.position.angle or 0
    end

    -- Set initial velocity
    if data.velocity and remotePlayer.components.velocity then
        remotePlayer.components.velocity.x = data.velocity.x
        remotePlayer.components.velocity.y = data.velocity.y
    end

    -- Set initial health
    if data.health and remotePlayer.components.health then
        local health = remotePlayer.components.health
        health.hp = data.health.hp
        health.maxHP = data.health.maxHp
        health.shield = data.health.shield
        health.maxShield = data.health.maxShield
    end

    -- Add to world
    world:addEntity(remotePlayer)
    
    Log.info("Created remote player:", playerId, "at", x, y)
    return remotePlayer
end

-- Listen for incoming player updates
Events.on("NETWORK_PLAYER_UPDATED", function(data)
    Log.info("NETWORK_PLAYER_UPDATED received:", data and data.playerId or "nil")
    if data and data.playerId and data.data then
        storeRemoteSnapshot(data.playerId, data.data)

        -- Store the player data for processing in the update loop
        local world = require("src.game").world
        if world then
            updateRemotePlayer(data.playerId, data.data, world)
        end
    end
end)

function NetworkSync.update(dt, player, world, networkManager)
    if not networkManager then
        return
    end
    
    if not networkManager:isMultiplayer() then
        return
    end

    -- Update position send timer
    positionUpdateTimer = positionUpdateTimer + dt


    -- Send player position updates
    if player and player.components and player.components.position then
        local pos = player.components.position
        local currentPos = { x = pos.x, y = pos.y, angle = pos.angle or 0 }
        
        -- Check if position has changed significantly or enough time has passed
        local dx = currentPos.x - lastSentPosition.x
        local dy = currentPos.y - lastSentPosition.y
        local distance = math.sqrt(dx * dx + dy * dy)
        
        if distance > 5 or positionUpdateTimer >= POSITION_UPDATE_INTERVAL then
            -- Send position update using the existing event system
            local updateData = {
                position = currentPos,
                velocity = player.components.velocity and {
                    x = player.components.velocity.x or 0,
                    y = player.components.velocity.y or 0
                } or { x = 0, y = 0 },
                health = player.components.health and {
                    hp = player.components.health.hp or 100,
                    maxHp = player.components.health.maxHP or 100,
                    shield = player.components.health.shield or 0,
                    maxShield = player.components.health.maxShield or 0
                } or nil
            }
            Log.info("Sending position update:", json.encode(updateData))
            Events.emit("NETWORK_SEND_PLAYER_UPDATE", updateData)
            
            lastSentPosition = currentPos
            positionUpdateTimer = 0
        end
    else
        Log.info("No player or position component available for position updates")
    end

    -- Update remote players
    local players = networkManager:getPlayers()
    local playerCount = 0
    for _ in pairs(players) do playerCount = playerCount + 1 end
    Log.info("NetworkSync: Found", playerCount, "players from network manager")
    
    for playerId, playerData in pairs(players) do
        local canonicalId = normalizePlayerDataId(playerData, playerId)
        local snapshot = playerData
        Log.info("Processing player:", canonicalId, "has position:", snapshot and snapshot.position ~= nil)
        Log.info("Player data structure:", json.encode(playerData))
        if snapshot and snapshot.position then
            updateRemotePlayer(canonicalId, snapshot, world)
        elseif snapshot and snapshot.data and snapshot.data.position then
            updateRemotePlayer(canonicalId, snapshot.data, world)
        else
            -- Even if we don't yet have full position data, keep the latest identifiers around
            storeRemoteSnapshot(canonicalId, playerData)
        end
    end

    -- Clean up disconnected remote players
    for playerId, remotePlayer in pairs(remotePlayers) do
        local stillConnected = false
        for id, playerData in pairs(players) do
            if normalizePlayerDataId(playerData, id) == playerId then
                stillConnected = true
                break
            end
        end
        
        if not stillConnected then
            Log.info("Removing disconnected remote player:", playerId)
            if world then
                world:removeEntity(remotePlayer)
            end
            remotePlayers[playerId] = nil
            remotePlayerSnapshots[playerId] = nil
        end
    end
end

function NetworkSync.getRemotePlayers()
    return remotePlayers
end

function NetworkSync.getRemotePlayer(playerId)
    return remotePlayers[canonicalizePlayerId(playerId)]
end

function NetworkSync.getRemotePlayerSnapshots()
    return remotePlayerSnapshots
end

return NetworkSync
