--[[
    Network Synchronization System
    Handles sending and receiving player position updates in multiplayer
]]

local Events = require("src.core.events")
local Log = require("src.core.log")

local NetworkSync = {}

-- Remote players storage
local remotePlayers = {}
local lastSentPosition = { x = 0, y = 0, angle = 0 }
local positionUpdateTimer = 0
local POSITION_UPDATE_INTERVAL = 1/20 -- 20 times per second

-- Listen for incoming player updates
Events.on("NETWORK_PLAYER_UPDATED", function(data)
    if data and data.playerId and data.data then
        -- Store the player data for processing in the update loop
        local world = require("src.game").world
        if world then
            updateRemotePlayer(data.playerId, data.data, world)
        end
    end
end)

function NetworkSync.update(dt, player, world, networkManager)
    if not networkManager or not networkManager.isMultiplayer then
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
            Events.emit("NETWORK_SEND_PLAYER_UPDATE", {
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
            })
            
            lastSentPosition = currentPos
            positionUpdateTimer = 0
        end
    end

    -- Update remote players
    local players = networkManager:getPlayers()
    for playerId, playerData in pairs(players) do
        if playerData and playerData.position then
            updateRemotePlayer(playerId, playerData, world)
        end
    end

    -- Clean up disconnected remote players
    for playerId, remotePlayer in pairs(remotePlayers) do
        local stillConnected = false
        for id, playerData in pairs(players) do
            if id == playerId then
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
        end
    end
end

function updateRemotePlayer(playerId, data, world)
    if not world then return end

    local remotePlayer = remotePlayers[playerId]
    
    -- Create remote player if it doesn't exist
    if not remotePlayer then
        Log.info("Creating remote player:", playerId)
        remotePlayer = createRemotePlayer(playerId, data, world)
        if remotePlayer then
            remotePlayers[playerId] = remotePlayer
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

function createRemotePlayer(playerId, data, world)
    local EntityFactory = require("src.templates.entity_factory")
    
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
    remotePlayer.remotePlayerId = playerId
    remotePlayer.playerName = "Player " .. playerId

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

function NetworkSync.getRemotePlayers()
    return remotePlayers
end

function NetworkSync.getRemotePlayer(playerId)
    return remotePlayers[playerId]
end

return NetworkSync
