local Util = require("src.core.util")
local Events = require("src.core.events")
local Log = require("src.core.log")
local EntityFactory = require("src.templates.entity_factory")
local RemoteEnemySync = require("src.systems.remote_enemy_sync")
local RemoteProjectileSync = require("src.systems.remote_projectile_sync")
local Content = require("src.content.content")
local NetworkManager = require("src.core.network.manager")
local NetworkSync = require("src.systems.network_sync")
local TargetUtils = require("src.core.target_utils")

local Session = {}

local state = {
    networkManager = nil,
    isMultiplayer = false,
    isHost = false,
    world = nil,
    player = nil,
    hub = nil,
    syncedWorldEntities = {},
    pendingWorldSnapshot = nil,
    pendingSelfNetworkState = nil,
    worldSyncHandlersRegistered = false,
    networkManagerListenersRegistered = false,
    eventHandlers = {}, -- Track event handlers for cleanup
    -- Performance optimization: Cache world snapshot to avoid expensive rebuilds
    cachedWorldSnapshot = nil,
    lastWorldSnapshotTime = 0,
    worldSnapshotCacheTimeout = 10.0, -- Cache for 10 seconds (reduced frequency)
    lastWorldSnapshotHash = nil, -- Track changes for delta updates
    worldSnapshotSendInterval = 2.0, -- Send snapshots every 2 seconds instead of on every change
    lastWorldSnapshotSend = 0
}

local DEFAULT_PROJECTILE_DAMAGE_MIN = 1
local DEFAULT_PROJECTILE_DAMAGE_MAX = 60
local DEFAULT_BEAM_DPS = 40
local DEFAULT_BEAM_LENGTH = 1600
local MAX_BEAM_LENGTH = 3000

local function sanitiseNumber(value, fallback, minValue, maxValue)
    local number = tonumber(value)
    if not number or number ~= number then
        number = fallback
    end
    if minValue ~= nil then
        number = math.max(minValue, number)
    end
    if maxValue ~= nil then
        number = math.min(maxValue, number)
    end
    return number
end

local function normaliseTurretId(turretId)
    if type(turretId) == "table" then
        return turretId.id or turretId.turretId or turretId.type
    end
    return turretId
end

local function resolveTurretData(player, request)
    local turretInstance = nil
    if player and player.getTurretInSlot and request and request.turretSlot then
        turretInstance = player:getTurretInSlot(request.turretSlot)
    end

    local turretId = request and normaliseTurretId(request.turretId)
    local turretDef = nil
    if type(turretId) == "string" then
        turretDef = Content.getTurret(turretId)
    end

    return turretInstance, turretDef, turretId
end

local function buildDamageConfig(turretInstance, turretDef)
    local minDamage
    local maxDamage
    local skillId

    if turretInstance and turretInstance.damage_range then
        minDamage = turretInstance.damage_range.min
        maxDamage = turretInstance.damage_range.max
        skillId = turretInstance.skillId
    elseif turretDef and turretDef.damage_range then
        minDamage = turretDef.damage_range.min
        maxDamage = turretDef.damage_range.max
        skillId = turretDef.skillId
    end

    if not minDamage or not maxDamage then
        local dps
        local cycle = 1
        if turretInstance and turretInstance.damagePerSecond then
            dps = turretInstance.damagePerSecond
            cycle = turretInstance.cycle or 1
            skillId = skillId or turretInstance.skillId
        elseif turretDef and turretDef.damagePerSecond then
            dps = turretDef.damagePerSecond
            cycle = turretDef.cycle or 1
            skillId = skillId or turretDef.skillId
        end

        if dps then
            local approx = math.max(0, dps * math.max(0.1, cycle))
            minDamage = approx * 0.75
            maxDamage = approx * 1.25
        end
    end

    minDamage = sanitiseNumber(minDamage, DEFAULT_PROJECTILE_DAMAGE_MIN, 0, DEFAULT_PROJECTILE_DAMAGE_MAX)
    maxDamage = sanitiseNumber(maxDamage, DEFAULT_PROJECTILE_DAMAGE_MAX, minDamage, DEFAULT_PROJECTILE_DAMAGE_MAX)

    local damageConfig = {
        min = minDamage,
        max = maxDamage,
    }
    if skillId then
        damageConfig.skill = skillId
    end

    return damageConfig
end

local function buildBeamDamagePerSecond(turretInstance, turretDef)
    local dps
    if turretInstance and turretInstance.damagePerSecond then
        dps = turretInstance.damagePerSecond
    elseif turretDef and turretDef.damagePerSecond then
        dps = turretDef.damagePerSecond
    elseif turretInstance and turretInstance.damage_range then
        dps = (turretInstance.damage_range.min + turretInstance.damage_range.max) * 0.5
    elseif turretDef and turretDef.damage_range then
        dps = (turretDef.damage_range.min + turretDef.damage_range.max) * 0.5
    end

    return sanitiseNumber(dps, DEFAULT_BEAM_DPS, 0, DEFAULT_BEAM_DPS)
end

local function sanitiseAdditionalEffects(effects, turretInstance, turretDef)
    if type(effects) ~= "table" then
        return nil
    end

    local sanitised = {}
    for _, effect in ipairs(effects) do
        if type(effect) == "table" and effect.type == "homing" then
            local maxRange = DEFAULT_BEAM_LENGTH
            if turretInstance and turretInstance.maxRange then
                maxRange = turretInstance.maxRange
            elseif turretDef and turretDef.maxRange then
                maxRange = turretDef.maxRange
            end

            local turnRate
            if turretInstance and turretInstance.missileTurnRate then
                turnRate = turretInstance.missileTurnRate
            elseif turretDef and turretDef.missileTurnRate then
                turnRate = turretDef.missileTurnRate
            end

            local speed
            if turretInstance then
                if turretInstance.projectile and turretInstance.projectile.physics then
                    speed = turretInstance.projectile.physics.speed
                elseif turretInstance.projectileSpeed then
                    speed = turretInstance.projectileSpeed
                end
            end
            if not speed and turretDef and type(turretDef.projectile) == "table" and turretDef.projectile.physics then
                speed = turretDef.projectile.physics.speed
            end

            local sanitisedEffect = {
                type = "homing",
                turnRate = sanitiseNumber(effect.turnRate or turnRate, turnRate or 0, 0, (turnRate or 0) > 0 and turnRate or 5),
                maxRange = sanitiseNumber(effect.maxRange, maxRange, 0, maxRange),
                reacquireDelay = sanitiseNumber(effect.reacquireDelay, 0.1, 0, 5),
                speed = sanitiseNumber(effect.speed or speed, speed or 0, 0, speed or 1200),
            }

            sanitised[#sanitised + 1] = sanitisedEffect
        end
    end

    if #sanitised == 0 then
        return nil
    end

    return sanitised
end

local function applyAdditionalEffectContext(effects, turretInstance, turretDef, player)
    if type(effects) ~= "table" or #effects == 0 then
        return
    end

    local world = state.world
    if not world then
        return
    end

    for _, effect in ipairs(effects) do
        if type(effect) == "table" and effect.type == "homing" then
            effect.world = world

            if not effect.speed or effect.speed <= 0 then
                local speed
                if turretInstance then
                    if turretInstance.projectile and turretInstance.projectile.physics then
                        speed = turretInstance.projectile.physics.speed
                    elseif turretInstance.projectileSpeed then
                        speed = turretInstance.projectileSpeed
                    end
                end

                if not speed and turretDef and type(turretDef.projectile) == "table" and turretDef.projectile.physics then
                    speed = turretDef.projectile.physics.speed
                end

                effect.speed = speed or effect.speed
            end

            local target = turretInstance and turretInstance.lockOnTarget
            if target and TargetUtils.isEnemyTarget(target, player) then
                effect.target = target
            else
                effect.target = nil
            end
        end
    end
end

-- Simple hash function for change detection
local function simpleHash(data)
    if not data or type(data) ~= "table" then
        return tostring(data)
    end
    
    local hash = ""
    for key, value in pairs(data) do
        if type(value) == "table" then
            hash = hash .. tostring(key) .. ":" .. simpleHash(value) .. ";"
        else
            hash = hash .. tostring(key) .. ":" .. tostring(value) .. ";"
        end
    end
    return hash
end

local function sanitisePlayerNetworkState(playerState)
    if type(playerState) ~= "table" then
        return nil
    end

    local position = playerState.position or {}
    local velocity = playerState.velocity or {}
    local health = playerState.health

    local sanitised = {
        position = {
            x = tonumber(position.x) or 0,
            y = tonumber(position.y) or 0,
            angle = tonumber(position.angle) or 0,
        },
        velocity = {
            x = tonumber(velocity.x) or 0,
            y = tonumber(velocity.y) or 0,
        },
    }

    if type(health) == "table" then
        sanitised.health = {
            hp = tonumber(health.hp) or 100,
            maxHP = tonumber(health.maxHP) or 100,
            shield = tonumber(health.shield) or 0,
            maxShield = tonumber(health.maxShield) or 0,
            energy = tonumber(health.energy) or 0,
            maxEnergy = tonumber(health.maxEnergy) or 0,
        }
    end

    return sanitised
end

local function clearSyncedWorldEntities()
    local world = state.world
    if world then
        for _, entity in ipairs(state.syncedWorldEntities) do
            if entity then
                world:removeEntity(entity)
            end
        end
    end

    state.syncedWorldEntities = {}
    state.hub = nil
end

local function spawnEntityFromSnapshot(entry)
    if not entry or not entry.kind or not entry.id then
        return nil
    end

    local extra = {}
    if entry.extra then
        for key, value in pairs(entry.extra) do
            extra[key] = value
        end
    end

    if entry.angle ~= nil then
        extra.angle = entry.angle
    end

    if next(extra) == nil then
        extra = nil
    end

    -- Handle enemy entities specially
    if entry.kind == "enemy" then
        local entity = EntityFactory.createEnemy(entry.type or entry.id, entry.x or 0, entry.y or 0)
        if entity then
            -- Preserve the ID from the snapshot for matching with remote updates
            entity.id = entry.id
            if entry.angle ~= nil then
                entity.components.position.angle = entry.angle
            end
        end
        return entity
    end

    return EntityFactory.create(entry.kind, entry.id, entry.x or 0, entry.y or 0, extra)
end

local function applySelfNetworkStateIfAvailable()
    local player = state.player
    local pendingState = state.pendingSelfNetworkState
    if not player or not pendingState then
        return
    end

    local newPos = pendingState.position
    if newPos and player.components and player.components.position then
        local positionComponent = player.components.position
        positionComponent.x = newPos.x or 0
        positionComponent.y = newPos.y or 0
        positionComponent.angle = newPos.angle or 0

        local physics = player.components.physics
        if physics and physics.body then
            local body = physics.body
            if body.setPosition then
                body:setPosition(positionComponent.x, positionComponent.y)
            else
                body.x = positionComponent.x
                body.y = positionComponent.y
            end
            if body.setAngle then
                body:setAngle(positionComponent.angle)
            else
                body.angle = positionComponent.angle
            end
        end
    end

    local newVel = pendingState.velocity
    if newVel and player.components and player.components.velocity then
        local velocityComponent = player.components.velocity
        velocityComponent.x = newVel.x or 0
        velocityComponent.y = newVel.y or 0

        local physics = player.components.physics
        if physics and physics.body then
            local body = physics.body
            if body.setLinearVelocity then
                body:setLinearVelocity(velocityComponent.x, velocityComponent.y)
            elseif body.setVelocity then
                body:setVelocity(velocityComponent.x, velocityComponent.y)
            else
                body.vx = velocityComponent.x
                body.vy = velocityComponent.y
            end
        end
    end

    if pendingState.health and player.components and player.components.health then
        local healthComponent = player.components.health
        for key, value in pairs(pendingState.health) do
            healthComponent[key] = value
        end
    end

    state.pendingSelfNetworkState = nil
end

local function applyWorldSnapshot(snapshot)
    local world = state.world
    if not snapshot or not world then
        return
    end

    clearSyncedWorldEntities()

    world.width = snapshot.width or world.width
    world.height = snapshot.height or world.height

    for _, entry in ipairs(snapshot.entities or {}) do
        local entity = spawnEntityFromSnapshot(entry)
        if entity then
            entity.isSyncedEntity = true
            if entry.id ~= nil then
                entity.syncedHostId = tostring(entry.id)
            end
            world:addEntity(entity)
            if entry.kind == "station" and entry.id == "hub_station" then
                state.hub = entity
            end
            table.insert(state.syncedWorldEntities, entity)
        else
        end
    end
end

local function queueWorldSnapshot(snapshot)
    if not snapshot then
        return
    end

    if not state.world then
        -- Use shallow copy for pending snapshot since it's temporary
        state.pendingWorldSnapshot = snapshot
        return
    end

    applyWorldSnapshot(snapshot)
    state.pendingWorldSnapshot = nil
end

local function buildWorldSnapshotFromWorld()
    local world = state.world
    if not world then
        return nil
    end

    -- Performance optimization: Use cached snapshot if available and not expired
    local currentTime = love.timer and love.timer.getTime() or os.clock()
    if state.cachedWorldSnapshot and 
       (currentTime - state.lastWorldSnapshotTime) < state.worldSnapshotCacheTimeout then
        return state.cachedWorldSnapshot
    end

    local snapshot = {
        width = world.width or 0,
        height = world.height or 0,
        entities = {},
    }

    -- Performance optimization: Use more efficient entity queries instead of iterating all entities
    -- Get stations first (usually few in number)
    local stationEntities = world:get_entities_with_components("station", "position")
    for _, entity in ipairs(stationEntities) do
        if not entity.isPlayer and not entity.isRemotePlayer and not entity.isSyncedEntity then
            local position = entity.components.position
            local station = entity.components.station or {}
            local entry = {
                kind = "station",
                id = station.type or "station",
                x = position.x or 0,
                y = position.y or 0,
            }
            if position.angle ~= nil then
                entry.angle = position.angle
            end
            snapshot.entities[#snapshot.entities + 1] = entry
        end
    end

    -- Get world objects (mineable/interactable entities)
    local worldObjectEntities = world:get_entities_with_components("mineable", "position")
    for _, entity in ipairs(worldObjectEntities) do
        if not entity.isPlayer and not entity.isRemotePlayer and not entity.isSyncedEntity then
            local position = entity.components.position
            local subtype = entity.subtype or (entity.components.renderable and entity.components.renderable.type) or "world_object"
            local entry = {
                kind = "world_object",
                id = subtype,
                x = position.x or 0,
                y = position.y or 0,
            }
            if position.angle ~= nil then
                entry.angle = position.angle
            end
            snapshot.entities[#snapshot.entities + 1] = entry
        end
    end

    -- Get interactable entities
    local interactableEntities = world:get_entities_with_components("interactable", "position")
    for _, entity in ipairs(interactableEntities) do
        if not entity.isPlayer and not entity.isRemotePlayer and not entity.isSyncedEntity then
            local position = entity.components.position
            local subtype = entity.subtype or (entity.components.renderable and entity.components.renderable.type) or "world_object"
            local entry = {
                kind = "world_object",
                id = subtype,
                x = position.x or 0,
                y = position.y or 0,
            }
            if position.angle ~= nil then
                entry.angle = position.angle
            end
            snapshot.entities[#snapshot.entities + 1] = entry
        end
    end

    -- Get enemy entities only if host-authoritative enemies is enabled
    local Settings = require("src.core.settings")
    local networkingSettings = Settings.getNetworkingSettings()
    if networkingSettings and networkingSettings.host_authoritative_enemies then
        local enemyEntities = world:get_entities_with_components("ai", "position")
        for _, entity in ipairs(enemyEntities) do
            if not entity.isPlayer and not entity.isRemotePlayer and not entity.isSyncedEntity then
                local position = entity.components.position
                local entry = {
                    kind = "enemy",
                    id = entity.id or tostring(entity),
                    type = entity.shipId or "basic_drone",
                    x = position.x or 0,
                    y = position.y or 0,
                }
                if position.angle ~= nil then
                    entry.angle = position.angle
                end
                snapshot.entities[#snapshot.entities + 1] = entry
            end
        end
    end

    -- Cache the snapshot for future use
    state.cachedWorldSnapshot = snapshot
    state.lastWorldSnapshotTime = currentTime

    return snapshot
end

-- Optimized function to build delta world snapshot (only changed entities)
local function buildDeltaWorldSnapshot()
    local world = state.world
    if not world then
        return nil
    end

    local currentTime = love.timer and love.timer.getTime() or os.clock()
    
    -- Check if we should send a snapshot based on time interval
    if (currentTime - state.lastWorldSnapshotSend) < state.worldSnapshotSendInterval then
        return nil -- Too soon to send another snapshot
    end

    local snapshot = {
        width = world.width or 0,
        height = world.height or 0,
        entities = {},
        isDelta = true, -- Mark as delta update
        timestamp = currentTime
    }

    -- Only include entities that have changed since last snapshot
    -- For now, we'll use a simplified approach and only send static entities
    -- Dynamic entities (enemies) are handled by the enemy sync system
    
    -- Get stations (these rarely change)
    local stationEntities = world:get_entities_with_components("station", "position")
    for _, entity in ipairs(stationEntities) do
        if not entity.isPlayer and not entity.isRemotePlayer and not entity.isSyncedEntity then
            local position = entity.components.position
            local station = entity.components.station or {}
            local entry = {
                kind = "station",
                id = station.type or "station",
                x = position.x or 0,
                y = position.y or 0,
            }
            if position.angle ~= nil then
                entry.angle = position.angle
            end
            snapshot.entities[#snapshot.entities + 1] = entry
        end
    end

    -- Get world objects (these rarely change)
    local worldObjectEntities = world:get_entities_with_components("mineable", "position")
    for _, entity in ipairs(worldObjectEntities) do
        if not entity.isPlayer and not entity.isRemotePlayer and not entity.isSyncedEntity then
            local position = entity.components.position
            local subtype = entity.subtype or (entity.components.renderable and entity.components.renderable.type) or "world_object"
            local entry = {
                kind = "world_object",
                id = subtype,
                x = position.x or 0,
                y = position.y or 0,
            }
            if position.angle ~= nil then
                entry.angle = position.angle
            end
            snapshot.entities[#snapshot.entities + 1] = entry
        end
    end

    -- Update send time
    state.lastWorldSnapshotSend = currentTime

    return snapshot
end

local function invalidateWorldSnapshotCache()
    state.cachedWorldSnapshot = nil
    state.lastWorldSnapshotTime = 0
end

local function broadcastHostWorldSnapshot(peer)
    local manager = state.networkManager
    if not manager or not manager:isHost() then
        return
    end

    -- Use delta snapshot for better performance
    local snapshot = buildDeltaWorldSnapshot()
    if not snapshot then
        return
    end

    -- Check if snapshot has actually changed
    local snapshotHash = simpleHash(snapshot)
    if snapshotHash == state.lastWorldSnapshotHash then
        return -- No changes, skip broadcast
    end
    state.lastWorldSnapshotHash = snapshotHash

    manager:updateWorldSnapshot(snapshot, peer)
end

-- Send full world snapshot (for new players or when explicitly requested)
local function broadcastFullWorldSnapshot(peer)
    local manager = state.networkManager
    if not manager or not manager:isHost() then
        return
    end

    local snapshot = buildWorldSnapshotFromWorld()
    if not snapshot then
        return
    end

    -- Mark as full snapshot
    snapshot.isFullSnapshot = true
    snapshot.timestamp = love.timer and love.timer.getTime() or os.clock()

    manager:updateWorldSnapshot(snapshot, peer)
end

local function ensureRemotePlayerEntity(playerId)
    local world = state.world
    local manager = state.networkManager
    if not world or not manager then
        return nil
    end

    local players = manager:getPlayers()
    local playerInfo = players[playerId]
    if not playerInfo then
        return nil
    end

    local entity = NetworkSync.ensureRemoteEntity(playerId, playerInfo.state or {}, world)
    if entity then
        entity.playerName = playerInfo.playerName or string.format("Player %d", playerId)
    end
    return entity
end

local function resolvePlayerEntityForRequest(playerId)
    local world = state.world
    if not world then
        return nil
    end

    if playerId == 0 then
        return state.player
    end

    local players = world:get_entities_with_components("player")
    for _, candidate in ipairs(players) do
        if candidate.remotePlayerId == playerId then
            return candidate
        end
    end

    return ensureRemotePlayerEntity(playerId)
end

local function handleProjectileRequest(request, playerId)
    local world = state.world
    if not world or not request then
        return
    end

    local player = resolvePlayerEntityForRequest(playerId)
    if not player then
        return
    end

    local turretInstance, turretDef, turretId = resolveTurretData(player, request)

    local projectileId = request.projectileId
    if turretInstance then
        projectileId = turretInstance.projectileId
            or (turretInstance.projectile and turretInstance.projectile.id)
            or projectileId
    elseif turretDef then
        if type(turretDef.projectile) == "table" then
            projectileId = turretDef.projectile.id or projectileId
        elseif type(turretDef.projectile) == "string" then
            projectileId = turretDef.projectile
        end
    end

    if not projectileId then
        return
    end

    local projectileKind = "bullet"
    if turretInstance and turretInstance.kind then
        projectileKind = turretInstance.kind
    elseif turretDef and turretDef.type then
        projectileKind = turretDef.type
    elseif request.kind then
        projectileKind = request.kind
    end

    local damageConfig = buildDamageConfig(turretInstance, turretDef)
    local additionalEffects = sanitiseAdditionalEffects(request.additionalEffects, turretInstance, turretDef)
    applyAdditionalEffectContext(additionalEffects, turretInstance, turretDef, player)

    local playerPos = player.components and player.components.position
    local startX = playerPos and playerPos.x or 0
    local startY = playerPos and playerPos.y or 0

    local angle = sanitiseNumber(request.angle, 0, -math.pi * 2, math.pi * 2)

    local sourcePlayerId = player.remotePlayerId or playerId
    local sourceShipId = player.shipId or (player.ship and player.ship.id)
    local sourceTurretSlot = request.turretSlot
    local sourceTurretType = turretInstance and turretInstance.kind or request.turretType

    local extraConfig = {
        angle = angle,
        friendly = true,
        damage = damageConfig,
        kind = projectileKind,
        additionalEffects = additionalEffects,
        source = player,
        sourcePlayerId = sourcePlayerId,
        sourceShipId = sourceShipId,
        sourceTurretSlot = sourceTurretSlot,
        sourceTurretId = turretId,
        sourceTurretType = sourceTurretType,
    }

    if turretInstance and turretInstance.impact and not additionalEffects then
        extraConfig.impact = turretInstance.impact
    end

    local projectile = EntityFactory.create(
        "projectile",
        projectileId,
        startX,
        startY,
        extraConfig
    )

    if projectile then
        world:addEntity(projectile)
    end
end

local function handleBeamRequest(request, playerId)
    local world = state.world
    if not world or not request then
        return
    end

    local player = resolvePlayerEntityForRequest(playerId)
    if not player then
        return
    end

    local turretInstance, turretDef = resolveTurretData(player, request)

    local maxRange = DEFAULT_BEAM_LENGTH
    if turretInstance and turretInstance.maxRange then
        maxRange = turretInstance.maxRange
    elseif turretDef and turretDef.maxRange then
        maxRange = turretDef.maxRange
    end
    maxRange = math.min(maxRange, MAX_BEAM_LENGTH)

    local playerPos = player.components and player.components.position
    local startX = playerPos and playerPos.x or 0
    local startY = playerPos and playerPos.y or 0

    local angle = sanitiseNumber(request.angle, 0, -math.pi * 2, math.pi * 2)
    local beamLength = sanitiseNumber(request.beamLength, maxRange, 0, maxRange)

    local endX = startX + math.cos(angle) * beamLength
    local endY = startY + math.sin(angle) * beamLength

    -- Set visual beam properties
    player.remoteBeamActive = true
    player.remoteBeamStartX = startX
    player.remoteBeamStartY = startY
    player.remoteBeamEndX = endX
    player.remoteBeamEndY = endY
    player.remoteBeamAngle = angle
    player.remoteBeamLength = beamLength
    player.remoteBeamStartTime = love.timer and love.timer.getTime() or os.clock()

    -- Apply beam damage and collision detection
    local BeamWeapons = require("src.systems.turret.beam_weapons")
    local hitTarget, hitX, hitY = BeamWeapons.performLaserHitscan(startX, startY, endX, endY, { owner = player }, world)

    if hitTarget then
        -- Calculate damage from request
        local damagePerSecond = buildBeamDamagePerSecond(turretInstance, turretDef)

        -- Apply damage using the same system as local beams
        local beamDuration = sanitiseNumber(request.deltaTime, 0.16, 0, 0.25)

        local damageAmount = damagePerSecond * beamDuration
        if damageAmount > 0 then
            local damageMeta
            if turretInstance and turretInstance.damage_range then
                damageMeta = {
                    min = turretInstance.damage_range.min,
                    max = turretInstance.damage_range.max,
                    value = damageAmount,
                    skill = turretInstance.skillId,
                    damagePerSecond = damagePerSecond
                }
            elseif turretDef and turretDef.damage_range then
                damageMeta = {
                    min = turretDef.damage_range.min,
                    max = turretDef.damage_range.max,
                    value = damageAmount,
                    skill = turretDef.skillId,
                    damagePerSecond = damagePerSecond
                }
            else
                damageMeta = { min = 1, max = 2, value = damageAmount, damagePerSecond = damagePerSecond }
            end
            local skillId = nil
            if turretInstance and turretInstance.skillId then
                skillId = turretInstance.skillId
            elseif turretDef and turretDef.skillId then
                skillId = turretDef.skillId
            end

            BeamWeapons.applyLaserDamage(hitTarget, damageAmount, player, skillId, damageMeta)
        end

        -- Create impact effect
        local TurretEffects = require("src.systems.turret.effects")
        TurretEffects.createImpactEffect({ owner = player }, hitX, hitY, hitTarget, "laser")
    end
end

local function handleUtilityBeamRequest(request, playerId)
    local world = state.world
    if not world or not request then
        return
    end

    local player = resolvePlayerEntityForRequest(playerId)
    if not player then
        return
    end

    local beamLength = request.beamLength or 100
    local startX = request.position and request.position.x or 0
    local startY = request.position and request.position.y or 0
    local endX = startX + math.cos(request.angle or 0) * beamLength
    local endY = startY + math.sin(request.angle or 0) * beamLength

    player.remoteUtilityBeamActive = true
    player.remoteUtilityBeamType = request.beamType
    player.remoteUtilityBeamStartX = startX
    player.remoteUtilityBeamStartY = startY
    player.remoteUtilityBeamEndX = endX
    player.remoteUtilityBeamEndY = endY
    player.remoteUtilityBeamAngle = request.angle or 0
    player.remoteUtilityBeamLength = beamLength
    player.remoteUtilityBeamStartTime = love.timer and love.timer.getTime() or os.clock()
end

local function clearEventHandlers()
    for eventName, handler in pairs(state.eventHandlers) do
        if handler and Events.off then
            Events.off(eventName, handler)
        end
    end
    state.eventHandlers = {}
end

local function registerWorldSyncEventHandlers()
    if state.worldSyncHandlersRegistered then
        return
    end

    -- Clear any existing handlers first
    clearEventHandlers()

    -- Register new handlers and track them for cleanup
    state.eventHandlers["NETWORK_WORLD_SNAPSHOT"] = Events.on("NETWORK_WORLD_SNAPSHOT", function(data)
        if state.isHost then
            return
        end

        local snapshot = data and data.snapshot or nil
        if snapshot then
            queueWorldSnapshot(snapshot)
        end
    end)

    state.eventHandlers["NETWORK_DISCONNECTED"] = Events.on("NETWORK_DISCONNECTED", function()
        if state.isHost then
            return
        end

        clearSyncedWorldEntities()
        state.pendingWorldSnapshot = nil
        state.pendingSelfNetworkState = nil
    end)

    state.eventHandlers["NETWORK_SERVER_STOPPED"] = Events.on("NETWORK_SERVER_STOPPED", function()
        if state.isHost then
            return
        end

        clearSyncedWorldEntities()
        state.pendingWorldSnapshot = nil
        state.pendingSelfNetworkState = nil
    end)

    state.eventHandlers["NETWORK_SERVER_STARTED"] = Events.on("NETWORK_SERVER_STARTED", function()
        if not state.isHost or not state.world then
            return
        end

        broadcastFullWorldSnapshot() -- Send full snapshot when server starts
    end)

    state.eventHandlers["NETWORK_ENEMY_UPDATE"] = Events.on("NETWORK_ENEMY_UPDATE", function(data)
        if state.isHost then
            return
        end

        local enemies = data and data.enemies or nil
        if enemies then
            RemoteEnemySync.applyEnemySnapshot(enemies, state.world)
        end
    end)

    state.eventHandlers["NETWORK_PROJECTILE_UPDATE"] = Events.on("NETWORK_PROJECTILE_UPDATE", function(data)
        if state.isHost then
            return
        end

        local projectiles = data and data.projectiles or nil
        if projectiles then
            RemoteProjectileSync.applyProjectileSnapshot(projectiles, state.world)
        end
    end)

    state.eventHandlers["NETWORK_WEAPON_FIRE_REQUEST"] = Events.on("NETWORK_WEAPON_FIRE_REQUEST", function(data)
        if not state.isHost then
            return
        end

        local request = data and data.request or nil
        if not request then
            return
        end

        Session.handleWeaponRequest(request, data.playerId)
    end)

    state.eventHandlers["NETWORK_PLAYER_JOINED"] = Events.on("NETWORK_PLAYER_JOINED", function(data)
        if state.isHost then
            if not state.isMultiplayer and state.networkManager and state.networkManager:isHost() then
                Session.setMode(true, true)
            end
            if state.networkManager and state.networkManager:isHost() then
                broadcastFullWorldSnapshot(data and data.peer) -- Send full snapshot for new players
            end
            return
        end

        if not data or not data.playerId or not data.isSelf then
            return
        end

        local sanitisedState = sanitisePlayerNetworkState(data.data)
        if not sanitisedState then
            return
        end

        state.pendingSelfNetworkState = sanitisedState
        applySelfNetworkStateIfAvailable()
    end)

    state.worldSyncHandlersRegistered = true
end

function Session.load(opts)
    opts = opts or {}

    state.syncedWorldEntities = {}
    state.pendingWorldSnapshot = nil
    state.pendingSelfNetworkState = nil
    state.worldSyncHandlersRegistered = false
    -- Clear world snapshot cache on load
    invalidateWorldSnapshotCache()

    if state.networkManager then
        state.networkManager:leaveGame()
    end

    state.networkManager = NetworkManager.new()

    Session.setMode(opts.multiplayer == true, opts.isHost == true)

    if state.isMultiplayer then
        if state.isHost then
            if not state.networkManager:startHost() then
                Session.setMode(false, false)
                return false, "start_failed"
            end
        else
            local connection = opts.pendingConnection
            if not connection then
                Session.setMode(false, false)
                return false, "No pending connection details found."
            end

            local ok, err = state.networkManager:joinGame(connection.address, connection.port, connection.username)
            if not ok then
                Session.setMode(false, false)
                return false, err
            end
        end
    end

    registerWorldSyncEventHandlers()
    return true
end

function Session.update(dt, context)
    if context then
        Session.setContext(context)
    end

    if state.networkManager then
        state.networkManager:update(dt)
    end

    applySelfNetworkStateIfAvailable()
    
    -- Send periodic delta world snapshots for existing players
    if state.isHost and state.networkManager and state.networkManager:isHost() then
        broadcastHostWorldSnapshot() -- This will use delta snapshots with time-based throttling
    end
end

function Session.setContext(context)
    context = context or {}

    if context.world and context.world ~= state.world then
        state.world = context.world
        state.syncedWorldEntities = {}
        if state.pendingWorldSnapshot then
            queueWorldSnapshot(state.pendingWorldSnapshot)
        end
    end

    if context.player ~= nil then
        state.player = context.player
        applySelfNetworkStateIfAvailable()
    end

    if context.hub ~= nil then
        state.hub = context.hub
    end
end

function Session.applySnapshot(snapshot)
    queueWorldSnapshot(snapshot)
end

function Session.handleWeaponRequest(request, playerId)
    if not request then
        return
    end

    if request.type == "beam_weapon_fire_request" then
        handleBeamRequest(request, playerId)
    elseif request.type == "utility_beam_weapon_fire_request" then
        handleUtilityBeamRequest(request, playerId)
    else
        handleProjectileRequest(request, playerId)
    end
end

function Session.toggleHosting()
    local manager = state.networkManager
    if not manager then
        return false, "no_network"
    end

    if manager:isMultiplayer() then
        if manager:isHost() then
            manager:leaveGame()
            Session.setMode(false, false)
            return true, "lan_closed"
        else
            manager:leaveGame()
            Session.setMode(false, false)
            return true, "client_left"
        end
    end

    Session.setMode(true, true)

    if not manager:startHost() then
        Session.setMode(false, false)
        return false, "start_failed"
    end

    registerWorldSyncEventHandlers()
    return true, "lan_opened"
end

function Session.setupEventHandlers()
    -- Only setup network manager listeners if not already registered
    if state.networkManager and state.networkManager.setupEventListeners and not state.networkManagerListenersRegistered then
        state.networkManager:setupEventListeners()
        state.networkManagerListenersRegistered = true
    end
    registerWorldSyncEventHandlers()
end

function Session.resetEventHandlers()
    state.worldSyncHandlersRegistered = false
    state.networkManagerListenersRegistered = false
end

function Session.teardown()
    clearSyncedWorldEntities()
    clearEventHandlers()

    if state.networkManager then
        state.networkManager:leaveGame()
        state.networkManager = nil
    end

    state.isMultiplayer = false
    state.isHost = false
    state.world = nil
    state.player = nil
    state.hub = nil
    state.pendingWorldSnapshot = nil
    state.pendingSelfNetworkState = nil
    state.worldSyncHandlersRegistered = false
    state.networkManagerListenersRegistered = false
    -- Clear world snapshot cache
    invalidateWorldSnapshotCache()
end

function Session.setMode(multiplayer, host)
    state.isMultiplayer = multiplayer and true or false
    state.isHost = host and true or false
end

function Session.isMultiplayer()
    return state.isMultiplayer
end

function Session.isHost()
    return state.isHost
end

function Session.getManager()
    return state.networkManager
end

function Session.getHub()
    return state.hub
end

function Session.getPendingSelfNetworkState()
    return state.pendingSelfNetworkState
end

function Session.invalidateWorldSnapshotCache()
    invalidateWorldSnapshotCache()
end

return Session
