--[[
    Remote Enemy Synchronization System
    Handles synchronization of enemy entities from host to clients when
    host-authoritative enemy combat is enabled.
]]

local Events = require("src.core.events")
local Log = require("src.core.log")
local Settings = require("src.core.settings")
local NetworkManager = require("src.core.network.manager")

local RemoteEnemySync = {}

local remoteEnemies = {}
local lastEnemySnapshot = nil
local enemySendAccumulator = 0
local ENEMY_SEND_INTERVAL = 1 / 20  -- 20 Hz for enemy updates

function RemoteEnemySync.reset()
    remoteEnemies = {}
    lastEnemySnapshot = nil
    enemySendAccumulator = 0
end

local function sanitiseEnemySnapshot(snapshot)
    if type(snapshot) ~= "table" then
        return {}
    end

    local sanitised = {}
    for _, enemy in ipairs(snapshot) do
        if type(enemy) == "table" and enemy.id and enemy.type then
            local sanitisedEnemy = {
                id = tostring(enemy.id),
                type = tostring(enemy.type),
                position = {
                    x = tonumber(enemy.position and enemy.position.x) or 0,
                    y = tonumber(enemy.position and enemy.position.y) or 0,
                    angle = tonumber(enemy.position and enemy.position.angle) or 0
                },
                velocity = {
                    x = tonumber(enemy.velocity and enemy.velocity.x) or 0,
                    y = tonumber(enemy.velocity and enemy.velocity.y) or 0
                }
            }

            -- Include health data if available
            if enemy.health then
                sanitisedEnemy.health = {
                    hp = tonumber(enemy.health.hp) or 100,
                    maxHP = tonumber(enemy.health.maxHP) or 100,
                    shield = tonumber(enemy.health.shield) or 0,
                    maxShield = tonumber(enemy.health.maxShield) or 0,
                    energy = tonumber(enemy.health.energy) or 0,
                    maxEnergy = tonumber(enemy.health.maxEnergy) or 0
                }
            end

            -- Include AI state if available
            if enemy.ai then
                sanitisedEnemy.ai = {
                    state = tostring(enemy.ai.state) or "patrolling",
                    target = enemy.ai.target or nil
                }
            end

            table.insert(sanitised, sanitisedEnemy)
        end
    end

    return sanitised
end

local function buildEnemySnapshotFromWorld(world)
    if not world then
        return {}
    end

    local snapshot = {}
    local entities = world:getEntities()

    for _, entity in pairs(entities) do
        -- Only include enemy entities (not players or stations)
        if entity.components and entity.components.ai and entity.components.position and 
           not entity.isPlayer and not entity.isRemotePlayer and not entity.isStation then
            
            local position = entity.components.position
            local velocity = entity.components.velocity
            local health = entity.components.health
            local ai = entity.components.ai

            local enemyData = {
                id = entity.id or tostring(entity),
                type = entity.type or "enemy",
                position = {
                    x = position.x or 0,
                    y = position.y or 0,
                    angle = position.angle or 0
                },
                velocity = {
                    x = velocity and velocity.x or 0,
                    y = velocity and velocity.y or 0
                }
            }

            -- Include health data
            if health then
                enemyData.health = {
                    hp = health.hp or 100,
                    maxHP = health.maxHP or 100,
                    shield = health.shield or 0,
                    maxShield = health.maxShield or 0,
                    energy = health.energy or 0,
                    maxEnergy = health.maxEnergy or 0
                }
            end

            -- Include AI state
            if ai then
                enemyData.ai = {
                    state = ai.state or "patrolling",
                    target = ai.target or nil
                }
            end

            table.insert(snapshot, enemyData)
        end
    end

    return snapshot
end

local function ensureRemoteEnemy(enemyId, enemyData, world)
    if not world then
        return nil
    end

    local entity = remoteEnemies[enemyId]
    if entity then
        return entity
    end

    -- Create a new remote enemy entity
    local EntityFactory = require("src.templates.entity_factory")
    local x = enemyData.position and enemyData.position.x or 0
    local y = enemyData.position and enemyData.position.y or 0

    -- Use the enemy type from the data, fallback to basic_drone
    local enemyType = enemyData.type or "basic_drone"
    entity = EntityFactory.create("enemy", enemyType, x, y)
    
    if not entity then
        Log.error("Failed to spawn remote enemy entity", enemyId, "of type", enemyType)
        return nil
    end

    entity.isRemoteEnemy = true
    entity.remoteEnemyId = enemyId
    entity.enemyType = enemyType

    world:addEntity(entity)
    remoteEnemies[enemyId] = entity

    return entity
end

local function updateEnemyFromSnapshot(entity, enemyData)
    if not entity or not enemyData then
        return
    end

    -- Update position
    if entity.components and entity.components.position and enemyData.position then
        entity.components.position.x = enemyData.position.x
        entity.components.position.y = enemyData.position.y
        entity.components.position.angle = enemyData.position.angle
    end

    -- Update velocity
    if entity.components and entity.components.velocity and enemyData.velocity then
        entity.components.velocity.x = enemyData.velocity.x
        entity.components.velocity.y = enemyData.velocity.y
    end

    -- Update health
    if entity.components and entity.components.health and enemyData.health then
        entity.components.health.hp = enemyData.health.hp
        entity.components.health.maxHP = enemyData.health.maxHP
        entity.components.health.shield = enemyData.health.shield
        entity.components.health.maxShield = enemyData.health.maxShield
        entity.components.health.energy = enemyData.health.energy
        entity.components.health.maxEnergy = enemyData.health.maxEnergy
    end

    -- Update AI state (but don't let it run - it's just for display)
    if entity.components and entity.components.ai and enemyData.ai then
        entity.components.ai.state = enemyData.ai.state
        entity.components.ai.target = enemyData.ai.target
    end

    -- Update physics body
    if entity.components and entity.components.physics and entity.components.physics.body then
        local body = entity.components.physics.body
        if body.setPosition then
            body:setPosition(enemyData.position.x, enemyData.position.y)
        else
            body.x = enemyData.position.x
            body.y = enemyData.position.y
        end
        if body.setVelocity then
            body:setVelocity(enemyData.velocity.x, enemyData.velocity.y)
        else
            body.vx = enemyData.velocity.x
            body.vy = enemyData.velocity.y
        end
        body.angle = enemyData.position.angle
    end
end

local function removeRemoteEnemy(world, enemyId)
    local entity = remoteEnemies[enemyId]
    if not entity then
        return
    end

    if world then
        world:removeEntity(entity)
    end

    remoteEnemies[enemyId] = nil
end

-- Host-side: Send enemy updates to clients
function RemoteEnemySync.updateHost(dt, world, networkManager)
    if not networkManager or not networkManager:isHost() then
        return
    end

    local networkingSettings = Settings.getNetworkingSettings()
    if not networkingSettings or not networkingSettings.host_authoritative_enemies then
        return
    end

    enemySendAccumulator = enemySendAccumulator + (dt or 0)

    if enemySendAccumulator >= ENEMY_SEND_INTERVAL then
        local snapshot = buildEnemySnapshotFromWorld(world)
        local sanitised = sanitiseEnemySnapshot(snapshot)
        
        -- Send enemy update to all clients
        if networkManager.sendEnemyUpdate then
            networkManager:sendEnemyUpdate(sanitised)
        end
        
        lastEnemySnapshot = sanitised
        enemySendAccumulator = 0
    end
end

-- Client-side: Receive and apply enemy updates from host
function RemoteEnemySync.updateClient(dt, world, networkManager)
    if not networkManager or networkManager:isHost() then
        return
    end

    local networkingSettings = Settings.getNetworkingSettings()
    if not networkingSettings or not networkingSettings.host_authoritative_enemies then
        return
    end

    -- This would be called when enemy updates are received from the network
    -- For now, this is a placeholder - the actual network message handling
    -- would be implemented in the network manager
end

function RemoteEnemySync.applyEnemySnapshot(snapshot, world)
    if not snapshot or not world then
        return
    end

    local sanitised = sanitiseEnemySnapshot(snapshot)
    local currentEnemyIds = {}

    -- Update existing enemies and track which ones we've seen
    for _, enemyData in ipairs(sanitised) do
        currentEnemyIds[enemyData.id] = true
        
        local entity = ensureRemoteEnemy(enemyData.id, enemyData, world)
        if entity then
            updateEnemyFromSnapshot(entity, enemyData)
        end
    end

    -- Remove enemies that are no longer in the snapshot
    for enemyId, entity in pairs(remoteEnemies) do
        if not currentEnemyIds[enemyId] then
            removeRemoteEnemy(world, enemyId)
        end
    end
end

function RemoteEnemySync.getRemoteEnemies()
    return remoteEnemies
end

-- Event handlers
Events.on("NETWORK_DISCONNECTED", function()
    RemoteEnemySync.reset()
end)

Events.on("NETWORK_SERVER_STOPPED", function()
    RemoteEnemySync.reset()
end)

return RemoteEnemySync
