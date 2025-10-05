--[[
    Network Synchronisation System
    Bridges the multiplayer network layer with the entity world so that each
    client can see other players moving around in real time.
]]

local Events = require("src.core.events")
local Log = require("src.core.log")

local NetworkSync = {}

local POSITION_SEND_INTERVAL = 1 / 15

local remoteEntities = {}
local lastSentSnapshot = nil
local sendAccumulator = 0

function NetworkSync.reset()
    remoteEntities = {}
    lastSentSnapshot = nil
    sendAccumulator = 0
end

local function sanitiseSnapshot(snapshot)
    if type(snapshot) ~= "table" then
        return {
            position = { x = 0, y = 0, angle = 0 },
            velocity = { x = 0, y = 0 },
            health = { hp = 100, maxHP = 100, shield = 0, maxShield = 0, energy = 0, maxEnergy = 0 }
        }
    end

    local position = snapshot.position or {}
    local velocity = snapshot.velocity or {}
    local health = snapshot.health or {}

    return {
        position = {
            x = tonumber(position.x) or 0,
            y = tonumber(position.y) or 0,
            angle = tonumber(position.angle) or 0
        },
        velocity = {
            x = tonumber(velocity.x) or 0,
            y = tonumber(velocity.y) or 0
        },
        health = {
            hp = tonumber(health.hp) or 100,
            maxHP = tonumber(health.maxHP) or 100,
            shield = tonumber(health.shield) or 0,
            maxShield = tonumber(health.maxShield) or 0,
            energy = tonumber(health.energy) or 0,
            maxEnergy = tonumber(health.maxEnergy) or 0
        }
    }
end

local function snapshotsDiffer(a, b)
    if not a or not b then
        return true
    end

    local posA, posB = a.position or {}, b.position or {}
    local velA, velB = a.velocity or {}, b.velocity or {}
    local healthA, healthB = a.health or {}, b.health or {}

    local posDelta = math.abs((posA.x or 0) - (posB.x or 0)) + math.abs((posA.y or 0) - (posB.y or 0))
    local angleDelta = math.abs((posA.angle or 0) - (posB.angle or 0))
    local velDelta = math.abs((velA.x or 0) - (velB.x or 0)) + math.abs((velA.y or 0) - (velB.y or 0))
    
    -- Health changes are significant enough to always send
    local healthChanged = (healthA.hp or 100) ~= (healthB.hp or 100) or
                         (healthA.shield or 0) ~= (healthB.shield or 0) or
                         (healthA.energy or 0) ~= (healthB.energy or 0)

    return posDelta > 1 or angleDelta > 0.01 or velDelta > 0.5 or healthChanged
end

local function ensureRemoteEntity(playerId, playerData, world)
    if not world then
        return nil
    end

    local entity = remoteEntities[playerId]
    if entity then
        return entity
    end

    local EntityFactory = require("src.templates.entity_factory")
    local x = playerData.position and playerData.position.x or 0
    local y = playerData.position and playerData.position.y or 0

    entity = EntityFactory.create("ship", "starter_frigate_basic", x, y)
    if not entity then
        Log.error("Failed to spawn remote entity for player", playerId)
        return nil
    end

    entity.isRemotePlayer = true
    entity.remotePlayerId = playerId
    entity.playerName = playerData.playerName or string.format("Player %s", tostring(playerId))

    world:addEntity(entity)
    remoteEntities[playerId] = entity

    return entity
end

local function updateExactPosition(entity, position)
    if not entity or not position then
        return
    end

    entity.exactPosition = entity.exactPosition or { x = 0, y = 0, angle = 0 }
    entity.exactPosition.x = position.x
    entity.exactPosition.y = position.y
    entity.exactPosition.angle = position.angle

    entity.x = position.x
    entity.y = position.y
    entity.angle = position.angle
end

local function updateEntityFromSnapshot(entity, snapshot)
    if not entity or not snapshot then
        return
    end

    local data = sanitiseSnapshot(snapshot)

    updateExactPosition(entity, data.position)

    if entity.components and entity.components.position then
        entity.components.position.x = data.position.x
        entity.components.position.y = data.position.y
        entity.components.position.angle = data.position.angle
    end

    if entity.components and entity.components.velocity then
        entity.components.velocity.x = data.velocity.x
        entity.components.velocity.y = data.velocity.y
    end

    -- Apply health data to remote player entities
    if entity.components and entity.components.health and data.health then
        entity.components.health.hp = data.health.hp
        entity.components.health.maxHP = data.health.maxHP
        entity.components.health.shield = data.health.shield
        entity.components.health.maxShield = data.health.maxShield
        entity.components.health.energy = data.health.energy
        entity.components.health.maxEnergy = data.health.maxEnergy
    end

    if entity.components and entity.components.physics and entity.components.physics.body then
        local body = entity.components.physics.body
        if body.setPosition then
            body:setPosition(data.position.x, data.position.y)
        else
            body.x = data.position.x
            body.y = data.position.y
        end
        if body.setVelocity then
            body:setVelocity(data.velocity.x, data.velocity.y)
        else
            body.vx = data.velocity.x
            body.vy = data.velocity.y
        end
        body.angle = data.position.angle
    end

    if entity.components and entity.components.physics then
        entity.components.physics.x = data.position.x
        entity.components.physics.y = data.position.y
        entity.components.physics.rotation = data.position.angle
    end
end

local function removeRemoteEntity(world, playerId)
    local entity = remoteEntities[playerId]
    if not entity then
        return
    end

    if world then
        world:removeEntity(entity)
    end

    remoteEntities[playerId] = nil
end

Events.on("NETWORK_PLAYER_LEFT", function(payload)
    local playerId = payload and payload.playerId
    if playerId then
        removeRemoteEntity(require("src.game").world, playerId)
    end
end)

Events.on("NETWORK_DISCONNECTED", function()
    NetworkSync.reset()
end)

Events.on("NETWORK_SERVER_STOPPED", function()
    NetworkSync.reset()
end)

function NetworkSync.update(dt, player, world, networkManager)
    if not networkManager or not networkManager:isMultiplayer() then
        return
    end

    sendAccumulator = sendAccumulator + (dt or 0)

    if player and player.components and player.components.position then
        local position = player.components.position
        local velocity = player.components.velocity
        local health = player.components.health

        local snapshot = {
            position = { x = position.x, y = position.y, angle = position.angle or 0 },
            velocity = velocity and { x = velocity.x or 0, y = velocity.y or 0 } or { x = 0, y = 0 },
            health = health and {
                hp = health.hp or 100,
                maxHP = health.maxHP or 100,
                shield = health.shield or 0,
                maxShield = health.maxShield or 0,
                energy = health.energy or 0,
                maxEnergy = health.maxEnergy or 0
            } or { hp = 100, maxHP = 100, shield = 0, maxShield = 0, energy = 0, maxEnergy = 0 }
        }

        if sendAccumulator >= POSITION_SEND_INTERVAL or snapshotsDiffer(snapshot, lastSentSnapshot) then
            networkManager:sendPlayerUpdate(snapshot)
            lastSentSnapshot = snapshot
            sendAccumulator = 0
        end
    end

    local players = networkManager:getPlayers() or {}
    local localId = networkManager.getLocalPlayerId and networkManager:getLocalPlayerId() or nil

    for id, playerInfo in pairs(players) do
        if id ~= localId then
            local entity = ensureRemoteEntity(id, playerInfo.state or {}, world)
            if entity then
                entity.playerName = playerInfo.playerName or entity.playerName
                updateEntityFromSnapshot(entity, playerInfo.state)
            end
        end
    end

    for id, entity in pairs(remoteEntities) do
        if not players[id] or id == localId then
            removeRemoteEntity(world, id)
        end
    end
end

function NetworkSync.getRemotePlayers()
    return remoteEntities
end

function NetworkSync.getRemotePlayerSnapshots()
    -- NOTE: This is a placeholder. The snapshot logic is not yet implemented.
    return {}
end

return NetworkSync
