--[[
    Remote Enemy Synchronization System
    Handles synchronization of enemy entities from host to clients when
    host-authoritative enemy combat is enabled.
]]

local Events = require("src.core.events")
local Settings = require("src.core.settings")

local RemoteEnemySync = {}

local remoteEnemies = {}
local pendingEnemySnapshots = {}
local currentWorld = nil
local lastEnemySnapshot = nil
local enemySendAccumulator = 0
local ENEMY_SEND_INTERVAL = 1 / 30  -- 30 Hz for enemy updates

local function removeRemoteEnemy(world, enemyId)
    local id = enemyId and tostring(enemyId) or nil
    local entity = id and remoteEnemies[id] or nil
    if not entity then
        return
    end

    if world then
        world:removeEntity(entity)
    end

    if id then
        remoteEnemies[id] = nil
        pendingEnemySnapshots[id] = nil
    end
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
    pendingEnemySnapshots = {}
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
            if enemy.hull then
                sanitisedEnemy.hull = {
                    hp = tonumber(enemy.hull.hp) or 100,
                    maxHP = tonumber(enemy.hull.maxHP) or 100,
                    energy = tonumber(enemy.hull.energy) or 0,
                    maxEnergy = tonumber(enemy.hull.maxEnergy) or 0
                }
            end
            -- Enemies don't have shields

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
            local hull = entity.components.hull
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

            -- Include hull data
            if hull then
                enemyData.hull = {
                    hp = hull.hp or 100,
                    maxHP = hull.maxHP or 100,
                    energy = hull.energy or 0,
                    maxEnergy = hull.maxEnergy or 0
                }
            end
            -- Enemies don't have shields

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
    if not world or not enemyId then
        return nil
    end

    local id = tostring(enemyId)
    if id == "" then
        return nil
    end

    local entity = remoteEnemies[id]
    if entity then
        if not entity.id or world:getEntity(entity.id) ~= entity then
            remoteEnemies[id] = nil
        else
            return entity
        end
    end

    local function matchesHostId(candidate)
        if not candidate then
            return false
        end

        local hostId = candidate.syncedHostId
        if hostId == nil and candidate.remoteEnemyId then
            hostId = candidate.remoteEnemyId
        end
        if hostId == nil and candidate.isSyncedEntity and candidate.id then
            hostId = candidate.id
        end

        if hostId == nil then
            return false
        end

        return tostring(hostId) == id
    end

    local syncedEntities = world:get_entities_with_components("ai", "position")
    for _, existingEntity in ipairs(syncedEntities) do
        if matchesHostId(existingEntity) then
            existingEntity.syncedHostId = id
            existingEntity.isRemoteEnemy = true
            existingEntity.remoteEnemyId = id
            remoteEnemies[id] = existingEntity
            return existingEntity
        end
    end

    for _, existingEntity in pairs(world:getEntities()) do
        if matchesHostId(existingEntity) then
            existingEntity.syncedHostId = id
            existingEntity.isRemoteEnemy = true
            existingEntity.remoteEnemyId = id
            remoteEnemies[id] = existingEntity
            return existingEntity
        end
    end

    -- Fallback: Create new enemy entity if no existing entity found
    -- This handles enemies that spawn after clients have connected
    local EntityFactory = require("src.templates.entity_factory")
    local x = 0
    local y = 0
    
    -- Try to get position from enemy data if available
    if enemyData and enemyData.position then
        x = enemyData.position.x or 0
        y = enemyData.position.y or 0
    end
    
    -- Use the enemy type from the data, fallback to basic_drone
    local enemyType = (enemyData and enemyData.type) or "basic_drone"
    local entity = EntityFactory.createEnemy(enemyType, x, y)
    
    if not entity then
        return nil
    end

    entity.isRemoteEnemy = true
    entity.remoteEnemyId = id
    entity.syncedHostId = id
    entity.enemyType = enemyType

    world:addEntity(entity)
    remoteEnemies[id] = entity

    return entity
end

local function updateEnemyFromSnapshot(entity, enemyData)
    if not entity or not enemyData then
        return
    end

    local now = love.timer and love.timer.getTime() or os.clock()

    if entity.components and entity.components.position and enemyData.position then
        local pos = entity.components.position

        entity._interpStartPos = entity._interpStartPos or { x = pos.x or 0, y = pos.y or 0, angle = pos.angle or 0 }
        entity._interpTargetPos = entity._interpTargetPos or { x = pos.x or 0, y = pos.y or 0, angle = pos.angle or 0 }

        if not entity._interpInitialized then
            pos.x = enemyData.position.x
            pos.y = enemyData.position.y
            pos.angle = enemyData.position.angle

            entity._interpStartPos.x = pos.x
            entity._interpStartPos.y = pos.y
            entity._interpStartPos.angle = pos.angle or 0
            entity._interpTargetPos.x = pos.x
            entity._interpTargetPos.y = pos.y
            entity._interpTargetPos.angle = pos.angle or 0
            entity._interpInitialized = true
        else
            entity._interpStartPos.x = pos.x or enemyData.position.x
            entity._interpStartPos.y = pos.y or enemyData.position.y
            entity._interpStartPos.angle = pos.angle or 0
            entity._interpTargetPos.x = enemyData.position.x
            entity._interpTargetPos.y = enemyData.position.y
            entity._interpTargetPos.angle = enemyData.position.angle or 0
        end

        entity._interpStartTime = now
        local interval = enemyData.updateInterval or ENEMY_SEND_INTERVAL
        entity._interpDuration = math.max(interval, 1 / 120)
    end

    -- Update velocity target for smoothing
    entity._targetVelocity = entity._targetVelocity or { x = 0, y = 0 }
    entity._targetVelocity.x = enemyData.velocity and enemyData.velocity.x or 0
    entity._targetVelocity.y = enemyData.velocity and enemyData.velocity.y or 0

    if entity.components and entity.components.velocity and enemyData.velocity then
        entity.components.velocity.x = enemyData.velocity.x
        entity.components.velocity.y = enemyData.velocity.y
    end

    -- Update health
    if entity.components and entity.components.hull and enemyData.hull then
        entity.components.hull.hp = enemyData.hull.hp
        entity.components.hull.maxHP = enemyData.hull.maxHP
        entity.components.hull.energy = enemyData.hull.energy
        entity.components.hull.maxEnergy = enemyData.hull.maxEnergy
    end
    -- Enemies don't have shields

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

    -- Ensure the physics body matches the initial snapshot immediately
    if entity.components and not entity._physicsInitialised and enemyData.position then
        -- Handle Windfield physics
        if entity.components.windfield_physics then
            local PhysicsSystem = require("src.systems.physics")
            local manager = PhysicsSystem.getManager()
            if manager then
                local collider = manager:getCollider(entity)
                if collider then
                    collider:setPosition(enemyData.position.x, enemyData.position.y)
                    if enemyData.velocity then
                        collider:setLinearVelocity(enemyData.velocity.x or 0, enemyData.velocity.y or 0)
                    end
                end
            end
        -- Handle legacy physics
        elseif entity.components.physics and entity.components.physics.body then
            local body = entity.components.physics.body
            if body.setPosition then
                body:setPosition(enemyData.position.x, enemyData.position.y)
            else
                body.x = enemyData.position.x
                body.y = enemyData.position.y
            end
            if enemyData.velocity then
                if body.setVelocity then
                    body:setVelocity(enemyData.velocity.x, enemyData.velocity.y)
                else
                    body.vx = enemyData.velocity.x
                    body.vy = enemyData.velocity.y
                end
            end
            body.angle = enemyData.position.angle or 0
            entity._physicsInitialised = true
        end
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
    for _, entity in pairs(remoteEnemies) do
        if entity and entity.components then
            local pos = entity.components.position
            local startPos = entity._interpStartPos
            local targetPos = entity._interpTargetPos
            local startTime = entity._interpStartTime
            if pos and startPos and targetPos and startTime then
                local duration = entity._interpDuration or ENEMY_SEND_INTERVAL
                if duration <= 0 then
                    duration = ENEMY_SEND_INTERVAL
                end

                local elapsed = currentTime - startTime
                local t = math.max(0, math.min(1, elapsed / duration))
                local smoothT = t * t * (3 - 2 * t) -- Smoothstep for gentle easing

                local newX = startPos.x + (targetPos.x - startPos.x) * smoothT
                local newY = startPos.y + (targetPos.y - startPos.y) * smoothT
                local newAngle = startPos.angle + (targetPos.angle - startPos.angle) * smoothT

                pos.x = newX
                pos.y = newY
                pos.angle = newAngle

                -- Handle Windfield physics
                if entity.components.windfield_physics then
                    local PhysicsSystem = require("src.systems.physics")
                    local manager = PhysicsSystem.getManager()
                    if manager then
                        local collider = manager:getCollider(entity)
                        if collider then
                            collider:setPosition(newX, newY)
                            collider:setAngle(newAngle)
                        end
                    end
                -- Handle legacy physics
                elseif entity.components.physics and entity.components.physics.body then
                    local body = entity.components.physics.body
                    if body.setPosition then
                        body:setPosition(newX, newY)
                    else
                        body.x = newX
                        body.y = newY
                    end
                    body.angle = newAngle

                    local targetVelocity = entity._targetVelocity
                    if targetVelocity then
                        if body.setVelocity then
                            body:setVelocity(targetVelocity.x, targetVelocity.y)
                        else
                            body.vx = targetVelocity.x
                            body.vy = targetVelocity.y
                        end
                    end
                end
            end

            if entity.components.velocity and entity._targetVelocity then
                entity.components.velocity.x = entity._targetVelocity.x
                entity.components.velocity.y = entity._targetVelocity.y
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
        local enemyId = enemyData.id
        currentEnemyIds[enemyId] = true

        local entity = ensureRemoteEnemy(enemyId, enemyData, world)
        if entity then
            updateEnemyFromSnapshot(entity, enemyData)
            pendingEnemySnapshots[enemyId] = nil
        else
            pendingEnemySnapshots[enemyId] = enemyData
        end
    end

    if next(pendingEnemySnapshots) then
        for enemyId, enemyData in pairs(pendingEnemySnapshots) do
            local entity = ensureRemoteEnemy(enemyId, enemyData, world)
            if entity then
                updateEnemyFromSnapshot(entity, enemyData)
                pendingEnemySnapshots[enemyId] = nil
                currentEnemyIds[enemyId] = true
            end
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
