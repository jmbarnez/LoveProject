--[[
    Remote Enemy Synchronization System
    Handles synchronization of enemy entities from host to clients when
    host-authoritative enemy combat is enabled.
]]

local Events = require("src.core.events")
local Log = require("src.core.log")
local Settings = require("src.core.settings")

local RemoteEnemySync = {}

local remoteEnemies = {}
local currentWorld = nil
local lastEnemySnapshot = nil
local enemySendAccumulator = 0
local ENEMY_SEND_INTERVAL = 1 / 30  -- 30 Hz for enemy updates

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

function RemoteEnemySync.reset()
    local world = currentWorld
    if world then
        local ids = {}
        for enemyId in pairs(remoteEnemies) do
            ids[#ids + 1] = enemyId
        end

        for _, enemyId in ipairs(ids) do
            removeRemoteEnemy(world, enemyId)
        end
    end

    remoteEnemies = {}
    currentWorld = nil
    lastEnemySnapshot = nil
    enemySendAccumulator = 0
end

local function sanitiseAiTarget(target)
    if target == nil then
        return nil
    end

    local targetId = nil
    local targetType = nil

    if type(target) == "table" then
        if target.isPlayer and target.id then
            targetId = tostring(target.id)
            targetType = "player"
        elseif target.isRemotePlayer and target.remotePlayerId then
            targetId = tostring(target.remotePlayerId)
            targetType = "remote_player"
        elseif target.remoteEnemyId then
            targetId = tostring(target.remoteEnemyId)
            targetType = "enemy"
        elseif target.id then
            targetId = tostring(target.id)
            if type(target.type) == "string" then
                targetType = target.type
            end
        end
    elseif type(target) == "number" or type(target) == "string" then
        targetId = tostring(target)
    end

    if not targetId then
        return nil
    end

    local sanitised = { id = targetId }
    if targetType then
        sanitised.type = targetType
    end

    return sanitised
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
                local aiState = {
                    state = tostring(enemy.ai.state) or "patrolling"
                }

                local target = sanitiseAiTarget(enemy.ai.target)
                if target then
                    aiState.target = target
                end

                sanitisedEnemy.ai = aiState
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
    -- Use the more efficient method to get entities with AI and position components
    local entities = world:get_entities_with_components("ai", "position")

    for _, entity in ipairs(entities) do
        -- Only include enemy entities (not players or stations)
        if not entity.isPlayer and not entity.isRemotePlayer and not entity.isStation then
            
            local position = entity.components.position
            local velocity = entity.components.velocity
            local health = entity.components.health
            local ai = entity.components.ai

            local enemyData = {
                id = entity.id or tostring(entity),
                type = entity.shipId or "basic_drone",
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
                local aiState = {
                    state = ai.state or "patrolling"
                }

                local target = sanitiseAiTarget(ai.target)
                if target then
                    aiState.target = target
                end

                enemyData.ai = aiState
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

    -- Try to find existing synced enemy entity with matching ID
    local syncedEntities = world:get_entities_with_components("ai", "position")
    for _, existingEntity in ipairs(syncedEntities) do
        if existingEntity.isSyncedEntity and (existingEntity.id == enemyId or tostring(existingEntity) == enemyId) then
            -- Found existing synced enemy entity, use it instead of creating a new one
            entity = existingEntity
            entity.isRemoteEnemy = true
            entity.remoteEnemyId = enemyId
            remoteEnemies[enemyId] = entity
            return entity
        end
    end

    -- If no existing entity found, create a new one (fallback for backwards compatibility)
    local EntityFactory = require("src.templates.entity_factory")
    local x = enemyData.position and enemyData.position.x or 0
    local y = enemyData.position and enemyData.position.y or 0

    -- Use the enemy type from the data, fallback to basic_drone
    local enemyType = enemyData.type or "basic_drone"
    entity = EntityFactory.createEnemy(enemyType, x, y)
    
    if not entity then
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

    -- Store previous position for interpolation
    if entity.components and entity.components.position then
        entity._prevPosition = entity._prevPosition or {}
        entity._prevPosition.x = entity.components.position.x
        entity._prevPosition.y = entity.components.position.y
        entity._prevPosition.angle = entity.components.position.angle
        entity._prevPositionTime = entity._prevPositionTime or 0
    end

    -- Update position with interpolation
    if entity.components and entity.components.position and enemyData.position then
        entity.components.position.x = enemyData.position.x
        entity.components.position.y = enemyData.position.y
        entity.components.position.angle = enemyData.position.angle
        entity._lastUpdateTime = love.timer and love.timer.getTime() or os.clock()
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
        local ai = entity.components.ai
        ai.state = enemyData.ai.state
        ai.isHunting = enemyData.ai.state == "hunting"
        ai.targetId = enemyData.ai.target and enemyData.ai.target.id or nil
        ai.targetType = enemyData.ai.target and enemyData.ai.target.type or nil
        
        -- Try to find the actual target entity in the world
        if enemyData.ai.target and enemyData.ai.target.id then
            local world = currentWorld
            if world then
                local entities = world:getEntities()
                for _, targetEntity in pairs(entities) do
                    if (targetEntity.isPlayer or targetEntity.isRemotePlayer) and 
                       (targetEntity.id == enemyData.ai.target.id or tostring(targetEntity) == enemyData.ai.target.id) then
                        ai.target = targetEntity
                        break
                    end
                end
            end
        else
            ai.target = nil
        end
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
        
        -- Always send updates when there are enemies, or when clearing enemies
        local shouldSend = false
        
        if #sanitised > 0 then
            -- Send if we have enemies (always send for now to ensure sync)
            shouldSend = true
        elseif #sanitised == 0 and lastEnemySnapshot and #lastEnemySnapshot > 0 then
            -- Send empty snapshot to clear enemies on clients
            shouldSend = true
        end
        
        if shouldSend then
            -- Send enemy update to all clients
            if networkManager.sendEnemyUpdate then
                networkManager:sendEnemyUpdate(sanitised)
            end
            
            lastEnemySnapshot = sanitised
        end
        
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

    -- Apply interpolation to smooth enemy movements
    local currentTime = love.timer and love.timer.getTime() or os.clock()
    for enemyId, entity in pairs(remoteEnemies) do
        if entity and entity._prevPosition and entity._lastUpdateTime then
            local timeSinceUpdate = currentTime - entity._lastUpdateTime
            local interpolationFactor = math.min(timeSinceUpdate / (1/30), 1.0) -- Interpolate over one update period
            
            if interpolationFactor < 1.0 and entity.components and entity.components.position then
                -- Smooth interpolation between previous and current position
                local pos = entity.components.position
                local prevPos = entity._prevPosition
                
                pos.x = prevPos.x + (pos.x - prevPos.x) * interpolationFactor
                pos.y = prevPos.y + (pos.y - prevPos.y) * interpolationFactor
                pos.angle = prevPos.angle + (pos.angle - prevPos.angle) * interpolationFactor
                
                -- Update physics body with interpolated position
                if entity.components.physics and entity.components.physics.body then
                    local body = entity.components.physics.body
                    if body.setPosition then
                        body:setPosition(pos.x, pos.y)
                    else
                        body.x = pos.x
                        body.y = pos.y
                    end
                    body.angle = pos.angle
                end
            end
        end
    end
end

function RemoteEnemySync.applyEnemySnapshot(snapshot, world)
    if not snapshot or not world then
        return
    end

    currentWorld = world

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
    local enemiesToRemove = {}
    for enemyId, entity in pairs(remoteEnemies) do
        if not currentEnemyIds[enemyId] then
            enemiesToRemove[#enemiesToRemove + 1] = enemyId
        end
    end
    
    for _, enemyId in ipairs(enemiesToRemove) do
        removeRemoteEnemy(world, enemyId)
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
