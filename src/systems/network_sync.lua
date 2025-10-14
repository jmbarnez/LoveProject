--[[
    Network Synchronisation System
    Bridges the multiplayer network layer with the entity world so that each
    client can see other players moving around in real time.
]]

local Events = require("src.core.events")
local Log = require("src.core.log")
local Radius = require("src.systems.collision.radius")

local NetworkSync = {}

local POSITION_SEND_INTERVAL = 1 / 20  -- Reduced frequency for smoother updates

local remoteEntities = {}
local lastSentSnapshot = nil
local lastSentTimestamp = nil
local sendAccumulator = 0

local MIN_INTERP_DURATION = 1 / 30   -- Increased minimum for smoother interpolation
local MAX_INTERP_DURATION = 0.2      -- Reduced maximum to prevent lag
local MAX_EXTRAPOLATION = 0.3        -- Reduced extrapolation to prevent overshooting

local function now()
    if love and love.timer and love.timer.getTime then
        return love.timer.getTime()
    end

    return os.clock()
end

function NetworkSync.reset()
    remoteEntities = {}
    lastSentSnapshot = nil
    lastSentTimestamp = nil
    sendAccumulator = 0
end

local function sanitiseSnapshot(snapshot)
    if type(snapshot) ~= "table" then
        return {
            position = { x = 0, y = 0, angle = 0 },
            velocity = { x = 0, y = 0 },
            hull = { hp = 100, maxHP = 100, energy = 0, maxEnergy = 0 },
            shield = { shield = 0, maxShield = 0 },
            shieldChannel = false,
            thrusterState = { isThrusting = false, forward = 0, reverse = 0, strafeLeft = 0, strafeRight = 0, boost = 0 },
            timestamp = now(),
            updateInterval = POSITION_SEND_INTERVAL,
        }
    end

    local position = snapshot.position or {}
    local velocity = snapshot.velocity or {}
    local hull = snapshot.hull or {}
    local shield = snapshot.shield or {}
    local shieldChannel = snapshot.shieldChannel
    local thrusterState = snapshot.thrusterState or {}
    local timestamp = tonumber(snapshot.timestamp)
    local updateInterval = tonumber(snapshot.updateInterval)

    local forward = math.max(0, math.min(1, tonumber(thrusterState.forward) or 0))
    local reverse = math.max(0, math.min(1, tonumber(thrusterState.reverse) or 0))
    local strafeLeft = math.max(0, math.min(1, tonumber(thrusterState.strafeLeft) or 0))
    local strafeRight = math.max(0, math.min(1, tonumber(thrusterState.strafeRight) or 0))
    local boost = math.max(0, math.min(1, tonumber(thrusterState.boost) or 0))

    local thrusting = thrusterState.isThrusting == true
    if not thrusting then
        local total = forward + boost + (strafeLeft + strafeRight) * 0.5 + reverse * 0.5
        thrusting = total > 0.01
    end

    local sanitized = {
        position = {
            x = tonumber(position.x) or 0,
            y = tonumber(position.y) or 0,
            angle = tonumber(position.angle) or 0
        },
        velocity = {
            x = tonumber(velocity.x) or 0,
            y = tonumber(velocity.y) or 0
        },
        hull = {
            hp = tonumber(hull.hp) or 100,
            maxHP = tonumber(hull.maxHP) or 100,
            energy = tonumber(hull.energy) or 0,
            maxEnergy = tonumber(hull.maxEnergy) or 0
        },
        shield = {
            shield = tonumber(shield.shield) or 0,
            maxShield = tonumber(shield.maxShield) or 0
        },
        shieldChannel = shieldChannel == true,
        thrusterState = {
            isThrusting = thrusting,
            forward = forward,
            reverse = reverse,
            strafeLeft = strafeLeft,
            strafeRight = strafeRight,
            boost = boost
        },
        timestamp = timestamp or now(),
        updateInterval = math.max(MIN_INTERP_DURATION, math.min(updateInterval or POSITION_SEND_INTERVAL, MAX_INTERP_DURATION))
    }

    return sanitized
end

local function snapshotsDiffer(a, b)
    if not a or not b then
        return true
    end

    local posA, posB = a.position or {}, b.position or {}
    local velA, velB = a.velocity or {}, b.velocity or {}
    local hullA, hullB = a.hull or {}, b.hull or {}
    local shieldA, shieldB = a.shield or {}, b.shield or {}
    local energyA, energyB = a.energy or {}, b.energy or {}
    local thrusterA, thrusterB = a.thrusterState or {}, b.thrusterState or {}

    local posDelta = math.abs((posA.x or 0) - (posB.x or 0)) + math.abs((posA.y or 0) - (posB.y or 0))
    local angleDelta = math.abs((posA.angle or 0) - (posB.angle or 0))
    local velDelta = math.abs((velA.x or 0) - (velB.x or 0)) + math.abs((velA.y or 0) - (velB.y or 0))

    -- Health changes are significant enough to always send
    local hullChanged = (hullA.hp or 100) ~= (hullB.hp or 100) or
                       (hullA.maxHP or 100) ~= (hullB.maxHP or 100)
    local energyChanged = (energyA.energy or 0) ~= (energyB.energy or 0) or
                         (energyA.maxEnergy or 100) ~= (energyB.maxEnergy or 100)
    local shieldChanged = (shieldA.shield or 0) ~= (shieldB.shield or 0) or
                         (shieldA.maxShield or 0) ~= (shieldB.maxShield or 0)

    local shieldChannelChanged = (a.shieldChannel or false) ~= (b.shieldChannel or false)

    local thrusterThreshold = 0.02
    local thrusterChanged = (thrusterA.isThrusting or false) ~= (thrusterB.isThrusting or false)
        or math.abs((thrusterA.forward or 0) - (thrusterB.forward or 0)) > thrusterThreshold
        or math.abs((thrusterA.reverse or 0) - (thrusterB.reverse or 0)) > thrusterThreshold
        or math.abs((thrusterA.strafeLeft or 0) - (thrusterB.strafeLeft or 0)) > thrusterThreshold
        or math.abs((thrusterA.strafeRight or 0) - (thrusterB.strafeRight or 0)) > thrusterThreshold
        or math.abs((thrusterA.boost or 0) - (thrusterB.boost or 0)) > thrusterThreshold

    return posDelta > 1 or angleDelta > 0.01 or velDelta > 0.5 or hullChanged or shieldChanged or energyChanged or shieldChannelChanged or thrusterChanged
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
        return nil
    end

    entity.isRemotePlayer = true
    entity.remotePlayerId = playerId
    entity.playerName = playerData.playerName or string.format("Player %s", tostring(playerId))
    entity.shipId = playerData.shipId or entity.shipId or "starter_frigate_basic"
    
    -- Ensure remote players have the player component for proper collision detection
    if not entity.components.player then
        entity.components.player = {}
    end

    -- Ensure remote players have engine trail components
    if not entity.components.engine_trail then
        local EngineTrail = require("src.components.engine_trail")
        local engineColors = {
            color1 = {0.0, 0.0, 1.0, 0.8},  -- Blue primary
            color2 = {0.0, 0.0, 0.5, 0.4},  -- Blue secondary
            size = 1.0,
            offset = 15
        }
        entity.components.engine_trail = EngineTrail.new(engineColors)
    end

    world:addEntity(entity)
    remoteEntities[playerId] = entity

    return entity
end

local function ensureInterpState(entity, currentPosition)
    entity._netSync = entity._netSync or {
        startPos = { x = currentPosition.x or 0, y = currentPosition.y or 0, angle = currentPosition.angle or 0 },
        targetPos = { x = currentPosition.x or 0, y = currentPosition.y or 0, angle = currentPosition.angle or 0 },
        lastVelocity = { x = 0, y = 0 },
        startTime = now(),
        duration = POSITION_SEND_INTERVAL,
        lastTimestamp = 0,
        lastHeard = now()
    }

    return entity._netSync
end

local function updateEntityFromSnapshot(entity, snapshot)
    if not entity or not snapshot then
        return
    end

    local data = sanitiseSnapshot(snapshot)
    local posComponent = entity.components and entity.components.position or nil

    local isMovementStale = false

    if posComponent then
        local interp = ensureInterpState(entity, posComponent)

        if interp.lastTimestamp and data.timestamp and data.timestamp <= interp.lastTimestamp then
            isMovementStale = true
        end

        if not isMovementStale then
            -- Use current interpolated position as start point for smoother transitions
            local currentX = posComponent.x or data.position.x
            local currentY = posComponent.y or data.position.y
            local currentAngle = posComponent.angle or data.position.angle
            
            -- If we're currently interpolating, use the interpolated position as start
            if interp.initialised and interp.startTime then
                local currentTime = now()
                local elapsed = currentTime - interp.startTime
                local duration = interp.duration or POSITION_SEND_INTERVAL
                if elapsed < duration then
                    local t = math.max(0, math.min(1, elapsed / duration))
                    local smoothT = t < 0.5 and 4 * t * t * t or 1 - (-2 * t + 2)^3 / 2
                    currentX = interp.startPos.x + (interp.targetPos.x - interp.startPos.x) * smoothT
                    currentY = interp.startPos.y + (interp.targetPos.y - interp.startPos.y) * smoothT
                    currentAngle = interp.startPos.angle + (interp.targetPos.angle - interp.startPos.angle) * smoothT
                end
            end
            
            interp.startPos.x = currentX
            interp.startPos.y = currentY
            interp.startPos.angle = currentAngle

            interp.targetPos.x = data.position.x
            interp.targetPos.y = data.position.y
            interp.targetPos.angle = data.position.angle

            interp.lastVelocity.x = data.velocity.x
            interp.lastVelocity.y = data.velocity.y
            interp.startTime = now()

            local duration = data.updateInterval or POSITION_SEND_INTERVAL
            if interp.lastTimestamp > 0 and data.timestamp then
                duration = math.max(duration, data.timestamp - interp.lastTimestamp)
            end
            interp.duration = math.max(MIN_INTERP_DURATION, math.min(duration, MAX_INTERP_DURATION))
            interp.lastTimestamp = data.timestamp or now()
            interp.lastHeard = now()
            interp.initialised = true
        end
    end

    -- Store velocity for extrapolation but don't apply it during interpolation
    if not isMovementStale and entity.components and entity.components.velocity then
        -- Only update velocity if we're not currently interpolating
        local interp = entity._netSync
        if not interp or not interp.initialised or (now() - (interp.startTime or 0)) > (interp.duration or POSITION_SEND_INTERVAL) then
            entity.components.velocity.x = data.velocity.x
            entity.components.velocity.y = data.velocity.y
        end
    end

    -- Apply hull and shield data to remote player entities
    local invalidateRadius = false

    if entity.components and entity.components.hull and data.hull then
        local hull = entity.components.hull
        local oldHP = hull.hp

        hull.hp = data.hull.hp
        hull.maxHP = data.hull.maxHP

        -- Detect damage for remote players and show overhead bars (only on hull decrease, not healing)
        if entity.isRemotePlayer then
            local hpDecreased = (oldHP or 0) > (hull.hp or 0)
            
            if hpDecreased then
                if love and love.timer and love.timer.getTime then
                    entity._hudDamageTime = love.timer.getTime()
                else
                    entity._hudDamageTime = os.clock()
                end
            end
        end
    end

    if entity.components and entity.components.shield and data.shield then
        local shield = entity.components.shield
        local oldShield = shield.shield
        local oldMaxShield = shield.maxShield

        shield.shield = data.shield.shield
        shield.maxShield = data.shield.maxShield

        -- Detect shield damage for remote players
        if entity.isRemotePlayer then
            local shieldDecreased = (oldShield or 0) > (shield.shield or 0)
            
            if shieldDecreased then
                if love and love.timer and love.timer.getTime then
                    entity._hudDamageTime = love.timer.getTime()
                else
                    entity._hudDamageTime = os.clock()
                end
            end
        end

        if (oldShield or 0) ~= (shield.shield or 0) or (oldMaxShield or 0) ~= (shield.maxShield or 0) then
            invalidateRadius = true
        end
    end

    if entity.components and entity.components.energy and data.energy then
        local energy = entity.components.energy
        energy.energy = data.energy.energy
        energy.maxEnergy = data.energy.maxEnergy
    end

    if data.shieldChannel ~= nil then
        local previousChannel = entity.shieldChannel
        entity.shieldChannel = data.shieldChannel
        if previousChannel ~= entity.shieldChannel then
            invalidateRadius = true
        end
    end

    if invalidateRadius then
        Radius.invalidateCache(entity)
    end

    -- Update engine trail if thruster state is provided
    if data.thrusterState and entity.components and entity.components.engine_trail then
        local trail = entity.components.engine_trail
        local thrusterState = data.thrusterState
        
        -- Calculate intensity from thruster inputs (same logic as in engine_trail.lua)
        local intensity = (thrusterState.forward or 0)
            + (thrusterState.boost or 0)
            + ((thrusterState.strafeLeft or 0) + (thrusterState.strafeRight or 0)) * 0.5
            + (thrusterState.reverse or 0) * 0.5
        
        local isThrusting = thrusterState.isThrusting or (intensity > 0)
        local normalizedIntensity = math.max(0, math.min(1, intensity))
        
        -- Update trail state
        if isThrusting and normalizedIntensity > 0.05 then
            trail:updateThrustState(true, normalizedIntensity)
        else
            trail:updateThrustState(false, 0)
        end
        
        -- Update trail position
        trail:updatePosition(data.position.x, data.position.y, data.position.angle or 0)
    end
end

local function applyRemotePlayerSmoothing()
    local currentTime = now()

    for _, entity in pairs(remoteEntities) do
        if entity and entity.components then
            local pos = entity.components.position
            local interp = entity._netSync

            if pos and interp and interp.initialised then
                local duration = math.max(MIN_INTERP_DURATION, interp.duration or POSITION_SEND_INTERVAL)
                local elapsed = currentTime - (interp.startTime or currentTime)
                local t = math.max(0, math.min(1, elapsed / duration))
                
                -- Use smoother interpolation curve (ease-in-out cubic)
                local smoothT = t < 0.5 and 4 * t * t * t or 1 - (-2 * t + 2)^3 / 2

                local newX, newY, newAngle

                if elapsed <= duration then
                    newX = interp.startPos.x + (interp.targetPos.x - interp.startPos.x) * smoothT
                    newY = interp.startPos.y + (interp.targetPos.y - interp.startPos.y) * smoothT
                    newAngle = interp.startPos.angle + (interp.targetPos.angle - interp.startPos.angle) * smoothT
                else
                    local sinceHeard = currentTime - (interp.lastHeard or currentTime)
                    local extrapTime = math.min(sinceHeard, MAX_EXTRAPOLATION)
                    
                    -- Use velocity-based extrapolation with damping to prevent overshooting
                    local dampFactor = math.max(0.1, 1 - (extrapTime / MAX_EXTRAPOLATION))
                    newX = interp.targetPos.x + interp.lastVelocity.x * extrapTime * dampFactor
                    newY = interp.targetPos.y + interp.lastVelocity.y * extrapTime * dampFactor
                    newAngle = interp.targetPos.angle

                    -- Prepare for smooth catch-up when the next packet arrives
                    interp.startPos.x = newX
                    interp.startPos.y = newY
                    interp.startPos.angle = newAngle
                end

                pos.x = newX
                pos.y = newY
                pos.angle = newAngle

                -- Only update velocity if we're not interpolating (to avoid conflicts)
                if elapsed > duration and entity.components.velocity then
                    entity.components.velocity.x = interp.lastVelocity.x
                    entity.components.velocity.y = interp.lastVelocity.y
                end

                -- Update Windfield collider position smoothly
                if entity.components.windfield_physics then
                    local PhysicsSystem = require("src.systems.physics")
                    local manager = PhysicsSystem.getManager()
                    if manager then
                        local collider = manager:getCollider(entity)
                        if collider then
                            collider:setPosition(newX, newY)
                            collider:setAngle(newAngle)
                            if elapsed > duration then
                                collider:setLinearVelocity(interp.lastVelocity.x, interp.lastVelocity.y)
                            end
                        end
                    end
                end
            end
        end
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
        local hull = player.components.hull
        local shield = player.components.shield
        local energy = player.components.energy


        -- Get thruster state for engine trail synchronization
        local playerState = player.components.player_state
        local thrusterState = (playerState and playerState.thruster_state) or { isThrusting = false }
        
        local snapshot = {
            position = { x = position.x, y = position.y, angle = position.angle or 0 },
            velocity = velocity and { x = velocity.x or 0, y = velocity.y or 0 } or { x = 0, y = 0 },
            hull = hull and {
                hp = hull.hp or 100,
                maxHP = hull.maxHP or 100
            } or { hp = 100, maxHP = 100 },
            energy = energy and {
                energy = energy.energy or 0,
                maxEnergy = energy.maxEnergy or 100
            } or { energy = 0, maxEnergy = 100 },
            shield = shield and {
                shield = shield.shield or 0,
                maxShield = shield.maxShield or 0
            } or { shield = 0, maxShield = 0 },
            shieldChannel = player.shieldChannel or false,
            thrusterState = {
                isThrusting = thrusterState.isThrusting or false,
                forward = thrusterState.forward or 0,
                reverse = thrusterState.reverse or 0,
                strafeLeft = thrusterState.strafeLeft or 0,
                strafeRight = thrusterState.strafeRight or 0,
                boost = thrusterState.boost or 0
            }
        }

        local currentTimestamp = now()
        snapshot.timestamp = currentTimestamp
        snapshot.updateInterval = lastSentTimestamp and (currentTimestamp - lastSentTimestamp) or POSITION_SEND_INTERVAL

        if sendAccumulator >= POSITION_SEND_INTERVAL or snapshotsDiffer(snapshot, lastSentSnapshot) then
            networkManager:sendPlayerUpdate(snapshot)
            lastSentSnapshot = snapshot
            lastSentTimestamp = currentTimestamp
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

    applyRemotePlayerSmoothing()
end

function NetworkSync.getRemotePlayers()
    return remoteEntities
end

function NetworkSync.getRemotePlayerSnapshots()
    -- NOTE: This is a placeholder. The snapshot logic is not yet implemented.
    return {}
end

function NetworkSync.ensureRemoteEntity(playerId, playerData, world)
    return ensureRemoteEntity(playerId, playerData, world)
end

return NetworkSync
