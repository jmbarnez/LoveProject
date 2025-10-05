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
local getLocalPlayerCanonicalId

local resolvePlayerSnapshot

-- Remote players storage
local remotePlayers = {}
local remotePlayerSnapshots = {}
local lastSentPosition = { x = 0, y = 0, angle = 0 }
local positionUpdateTimer = 0
local POSITION_UPDATE_INTERVAL = 1/30 -- 30 times per second

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

local function mergeSnapshotFields(target, source)
    if type(target) ~= "table" or type(source) ~= "table" then
        return target
    end

    if target == source then
        return target
    end

    for key, value in pairs(source) do
        if value ~= nil then
            if type(value) == "table" then
                local existing = target[key]
                if type(existing) ~= "table" then
                    existing = {}
                end
                if existing ~= value then
                    mergeSnapshotFields(existing, value)
                end
                target[key] = existing
            else
                target[key] = value
            end
        end
    end

    return target
end

-- Function definitions
storeRemoteSnapshot = function(playerId, data)
    local canonicalId = canonicalizePlayerId(playerId)
    if not canonicalId then return nil end

    local snapshot = remotePlayerSnapshots[canonicalId]
    if not snapshot then
        snapshot = { playerId = canonicalId }
        remotePlayerSnapshots[canonicalId] = snapshot
    end

    if not data then
        return snapshot
    end

    local payload = data
    if type(payload) == "table" and type(payload.data) == "table" then
        payload = payload.data
    end

    if type(payload) == "table" then
        mergeSnapshotFields(snapshot, payload)
    end

    if type(data) == "table" then
        if data.playerId ~= nil then
            snapshot.playerId = canonicalizePlayerId(data.playerId) or snapshot.playerId or canonicalId
        elseif type(payload) == "table" and payload.playerId ~= nil then
            snapshot.playerId = canonicalizePlayerId(payload.playerId) or snapshot.playerId or canonicalId
        else
            snapshot.playerId = snapshot.playerId or canonicalId
        end

        if data.playerName ~= nil then
            snapshot.playerName = data.playerName
        elseif type(payload) == "table" and payload.playerName ~= nil then
            snapshot.playerName = payload.playerName
        end
    end

    remotePlayerSnapshots[canonicalId] = snapshot
    return snapshot
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
    
    Log.info("Created remote player:", playerId, "at", x, y, "isRemotePlayer:", remotePlayer.isRemotePlayer)
    return remotePlayer
end

getLocalPlayerCanonicalId = function(networkManager)
    if not networkManager then
        return nil
    end

    if networkManager:isHost() then
        return canonicalizePlayerId(0)
    end

    if networkManager.client and networkManager.client.playerId then
        return canonicalizePlayerId(networkManager.client.playerId)
    end

    return nil
end

resolvePlayerSnapshot = function(playerId, playerData)
    local canonicalId = canonicalizePlayerId(playerId)

    if not canonicalId then
        canonicalId = normalizePlayerDataId(playerData, playerId)
    end

    if not canonicalId then
        return nil
    end

    local snapshot = nil

    if playerData ~= nil then
        snapshot = storeRemoteSnapshot(canonicalId, playerData)
    else
        snapshot = remotePlayerSnapshots[canonicalId]
    end

    if not snapshot then
        return nil
    end

    return {
        playerId = canonicalId,
        data = snapshot
    }
end

-- Listen for incoming player updates
Events.on("NETWORK_PLAYER_UPDATED", function(data)
    Log.info("NETWORK_PLAYER_UPDATED received:", data and data.playerId or "nil")
    if not data or not data.playerId then
        return
    end

    local resolved = resolvePlayerSnapshot(data.playerId, data)

    if resolved and resolved.data and resolved.data.position then
        local world = require("src.game").world
        if world then
            updateRemotePlayer(resolved.playerId, resolved.data, world)
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
        
        if distance > 2 or positionUpdateTimer >= POSITION_UPDATE_INTERVAL then
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

    local localCanonicalId = getLocalPlayerCanonicalId(networkManager)

    for playerId, playerData in pairs(players) do
        local canonicalId = normalizePlayerDataId(playerData, playerId)

        if canonicalId and localCanonicalId and canonicalId == localCanonicalId then
            Log.info("Skipping local player from remote sync:", canonicalId)

            -- Ensure we remove any stale remote entity or snapshot that may have been created for the local player
            if remotePlayers[canonicalId] then
                Log.info("Removing stale local remote player entity:", canonicalId)
                if world then
                    world:removeEntity(remotePlayers[canonicalId])
                end
                remotePlayers[canonicalId] = nil
            end
            remotePlayerSnapshots[canonicalId] = nil
        else
            if canonicalId then
                local resolved = resolvePlayerSnapshot(canonicalId, playerData)
                Log.info("Processing player:", canonicalId, "has position:", resolved and resolved.data and resolved.data.position ~= nil)
                Log.info("Player data structure:", json.encode(playerData))

                if resolved and resolved.data and resolved.data.position then
                    updateRemotePlayer(resolved.playerId, resolved.data, world)
                end
            end
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
