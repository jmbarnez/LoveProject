local Util = require("src.core.util")
local AIComponent = require("src.components.ai")
local Log = require("src.core.log")
local SpaceStationSystem = require("src.systems.hub")
local EntityFactory = require("src.templates.entity_factory")

local AISystem = {}

-- Simple constants for basic AI
local PATROL_RADIUS = 200  -- How far enemies patrol from spawn point
local BOSS_MINION_MAX = 3
local BOSS_MINION_INTERVAL_MIN = 4.0
local BOSS_MINION_INTERVAL_MAX = 6.0
local BOSS_MINION_OFFSET = 160

-- Logging throttle to prevent spam
local lastHuntingLog = 0
local lastFiringLog = 0
local LOG_THROTTLE = 2.0  -- Only log every 2 seconds

-- Simple damage reaction handler
local function onEntityDamaged(eventData)
    local entity = eventData.entity
    local source = eventData.source
    local damage = eventData.damage

    -- Check if the damaged entity has AI
    if entity and entity.components and entity.components.ai then
        local ai = entity.components.ai

        -- Only react to damage from players (not self-damage)
        if source and source ~= entity and damage > 0 and source.components and source.components.player then
            -- Mark as damaged by player and start hunting
            ai.damagedByPlayer = true
            ai.lastDamageTime = love.timer.getTime()
            ai.target = source
            ai.isHunting = true
            ai.state = "hunting"
        end
    end
end

local function updateBossMinions(entity, dt, world)
    if not entity or not entity.isBoss or entity.dead then
        return
    end

    if not (entity.components and entity.components.health and entity.components.position) then
        return
    end

    local health = entity.components.health
    local hp = health.hp or health.current or 0
    if hp <= 0 then
        return
    end

    entity._bossMinions = entity._bossMinions or {}
    local active = {}
    for _, minion in ipairs(entity._bossMinions) do
        if minion and not minion.dead and minion.components and minion.components.health then
            local mh = minion.components.health
            local mhp = mh.hp or mh.current or 0
            if mhp > 0 then
                table.insert(active, minion)
            end
        end
    end
    entity._bossMinions = active

    entity._bossMinionTimer = (entity._bossMinionTimer or (math.random() * (BOSS_MINION_INTERVAL_MAX - BOSS_MINION_INTERVAL_MIN) + BOSS_MINION_INTERVAL_MIN)) - dt

    if entity._bossMinionTimer > 0 then
        return
    end

    if #entity._bossMinions >= BOSS_MINION_MAX then
        entity._bossMinionTimer = 1.5
        return
    end

    if not world or not world.addEntity then
        entity._bossMinionTimer = 1.5
        return
    end

    local pos = entity.components.position
    local angle = math.random() * math.pi * 2
    local baseRadius = (entity.components.collidable and entity.components.collidable.radius) or 80
    local distance = baseRadius + BOSS_MINION_OFFSET + math.random() * 80
    local spawnX = pos.x + math.cos(angle) * distance
    local spawnY = pos.y + math.sin(angle) * distance

    local minion = EntityFactory.createEnemy("basic_drone", spawnX, spawnY)
    if minion then
        minion.summonedByBoss = true
        if minion.components and minion.components.ai then
            minion.components.ai.spawnPos = { x = spawnX, y = spawnY }
            minion.components.ai.patrolCenter = { x = spawnX, y = spawnY }
        end
        world:addEntity(minion)
        table.insert(entity._bossMinions, minion)
    end

    entity._bossMinionTimer = math.random() * (BOSS_MINION_INTERVAL_MAX - BOSS_MINION_INTERVAL_MIN) + BOSS_MINION_INTERVAL_MIN
end

-- Check if an enemy is within any station's weapons disabled zone
local function isEnemyInWeaponsDisabledZone(entity, world)
    if not entity or not entity.components or not entity.components.position then
        return false
    end

    local entityPos = entity.components.position

    -- Check the hub station
    local hub = nil
    for _, e in ipairs(world:get_entities_with_components("hub")) do
        hub = e
        break
    end

    if hub and SpaceStationSystem.isInside(hub, entityPos.x, entityPos.y) then
        return true
    end

    -- Check other stations with station component
    local stations = world:get_entities_with_components("station")
    for _, station in ipairs(stations) do
        if SpaceStationSystem.isInside(station, entityPos.x, entityPos.y) then
            return true
        end
    end

    return false
end

-- #################################################################################
-- ## Simple State Handlers
-- #################################################################################

local function handlePatrolling(entity, dt)
    local ai = entity.components.ai
    local pos = entity.components.position
    local body = entity.components.physics and entity.components.physics.body

    -- Simple patrol behavior: move in circles around spawn point
    ai.patrolTimer = (ai.patrolTimer or 0) + dt

    -- Change direction every 10-15 seconds
    if ai.patrolTimer >= 10 + math.random() * 5 then
        ai.patrolTimer = 0
        ai.patrolDirection = -ai.patrolDirection
    end

    -- Calculate patrol position
    local patrolAngle = ai.patrolAngle + (ai.patrolDirection * dt * 0.5)  -- Slow rotation
    ai.patrolAngle = patrolAngle

    local patrolX = ai.patrolCenter.x + math.cos(patrolAngle) * PATROL_RADIUS
    local patrolY = ai.patrolCenter.y + math.sin(patrolAngle) * PATROL_RADIUS

    -- Move towards patrol point
    local dx = patrolX - pos.x
    local dy = patrolY - pos.y
    local distance = math.sqrt(dx * dx + dy * dy)

    if distance > 20 then  -- Minimum distance to keep moving
        local speed = ai.patrolSpeed
        local moveX = (dx / distance) * speed
        local moveY = (dy / distance) * speed

        -- Apply movement
        if body then
            body.vx = moveX
            body.vy = moveY
            body.angle = math.atan2(moveY, moveX)
        else
            entity.components.velocity.x = moveX
            entity.components.velocity.y = moveY
            pos.angle = math.atan2(moveY, moveX)
        end
    end
end

local function handleHunting(entity, dt, player, spawnProjectile, world)
    local ai = entity.components.ai
    local pos = entity.components.position
    local body = entity.components.physics and entity.components.physics.body

    if not player or not player.components or not player.components.position then
        -- Lost target, go back to patrolling
        ai.isHunting = false
        ai.state = "patrolling"
        ai.target = nil
        return
    end

    local playerPos = player.components.position
    local dx = playerPos.x - pos.x
    local dy = playerPos.y - pos.y
    local distance = math.sqrt(dx * dx + dy * dy)

    -- Check if player is still in detection range
    if distance > ai.detectionRange * 1.5 then  -- Give some buffer
        ai.isHunting = false
        ai.state = "patrolling"
        ai.target = nil
        return
    end

    -- Throttled debug logging: Show hunting status (only every 2 seconds)
    local currentTime = love.timer.getTime()
    if currentTime - lastHuntingLog > LOG_THROTTLE then
        Log.debug(string.format("Enemy hunting! Distance: %.1f, Detection range: %.1f", distance, ai.detectionRange))
        lastHuntingLog = currentTime
    end

    -- Orbit around player at optimal turret range
    local optimalRange = 800  -- Default optimal range
    if entity.components.equipment and entity.components.equipment.grid then
        for _, slot in ipairs(entity.components.equipment.grid) do
            if slot and slot.module and slot.type == "turret" then
                optimalRange = slot.module.optimal or optimalRange
                break
            end
        end
    end

    -- Initialize orbit angle if not set
    if not ai.orbitAngle then
        ai.orbitAngle = math.random() * 2 * math.pi
    end

    -- Calculate orbit position
    local orbitX = playerPos.x + math.cos(ai.orbitAngle) * optimalRange
    local orbitY = playerPos.y + math.sin(ai.orbitAngle) * optimalRange

    -- Update orbit angle for continuous orbiting
    ai.orbitAngle = ai.orbitAngle + dt * 0.5  -- Adjust speed as needed

    -- Calculate direction to orbit position
    local orbitDx = orbitX - pos.x
    local orbitDy = orbitY - pos.y
    local orbitDistance = math.sqrt(orbitDx * orbitDx + orbitDy * orbitDy)

    -- Apply separation force to prevent stacking
    local separationX, separationY = 0, 0
    local separationRadius = 50  -- Minimum distance between enemies
    local separationForce = 100  -- Strength of separation

    for _, otherEntity in ipairs(world:get_entities_with_components("ai", "position")) do
        if otherEntity ~= entity and not otherEntity.dead then
            local otherPos = otherEntity.components.position
            local otherDx = otherPos.x - pos.x
            local otherDy = otherPos.y - pos.y
            local otherDistance = math.sqrt(otherDx * otherDx + otherDy * otherDy)

            if otherDistance < separationRadius and otherDistance > 0 then
                -- Apply repulsion force
                local force = (separationRadius - otherDistance) / separationRadius * separationForce
                separationX = separationX - (otherDx / otherDistance) * force
                separationY = separationY - (otherDy / otherDistance) * force
            end
        end
    end

    -- Combine orbit movement with separation
    local totalDx = orbitDx + separationX
    local totalDy = orbitDy + separationY
    local totalDistance = math.sqrt(totalDx * totalDx + totalDy * totalDy)

    local speed = ai.chaseSpeed
    local moveX = (totalDx / totalDistance) * speed
    local moveY = (totalDy / totalDistance) * speed

    -- Apply movement
    if body then
        body.vx = moveX
        body.vy = moveY
        body.angle = math.atan2(moveY, moveX)
    else
        entity.components.velocity.x = moveX
        entity.components.velocity.y = moveY
        pos.angle = math.atan2(moveY, moveX)
    end

    -- Firing logic - check if we can shoot at the player
    local canShoot = false

    -- Check if enemy is in weapons disabled zone
    local stations = world:get_entities_with_components("station")
    local inWeaponsDisabledZone = false
    for _, station in ipairs(stations) do
        if station.components and station.components.position then
            local dx = pos.x - station.components.position.x
            local dy = pos.y - station.components.position.y
            local distSq = dx * dx + dy * dy
            if distSq <= (station.weaponDisableRadius or 0) ^ 2 then
                inWeaponsDisabledZone = true
                break
            end
        end
    end
    entity.weaponsDisabled = inWeaponsDisabledZone

    -- Safety check: make sure we have valid position data
    if pos and pos.x and pos.y and playerPos and not inWeaponsDisabledZone then
        local playerDx = playerPos.x - pos.x
        local playerDy = playerPos.y - pos.y
        local playerDistance = math.sqrt(playerDx * playerDx + playerDy * playerDy)

        if playerDistance <= optimalRange * 1.5 and playerDistance >= 40 then
            -- Check if we're facing the player well enough to shoot
            local angleToPlayer = math.atan2(playerDy, playerDx)
            local entityAngle = pos.angle or 0  -- Default to 0 if angle is nil
            local angleDiff = angleToPlayer - entityAngle
            while angleDiff > math.pi do angleDiff = angleDiff - 2 * math.pi end
            while angleDiff < -math.pi do angleDiff = angleDiff + 2 * math.pi end

            -- Can shoot if roughly facing the player (108 degrees, about 1/3 of a circle)
            canShoot = math.abs(angleDiff) < math.pi * 0.6
        end
    end

    -- Handle turret firing through equipment grid
    if entity.components.equipment and entity.components.equipment.grid then
        for _, slot in ipairs(entity.components.equipment.grid) do
            if slot and slot.module and slot.type == "turret" and slot.enabled ~= false then
                local turret = slot.module

                -- Safety check: make sure turret exists and has required properties
                if turret and turret.update and type(turret.update) == "function" then
                    -- Set turret to automatic fire mode
                    turret.fireMode = "automatic"
                    turret.autoFire = true

                    -- Update turret - pass 'locked' as opposite of 'canShoot'
                    -- When locked=true, turret stops firing; locked=false allows firing
                    local locked = not canShoot
                    turret:update(dt, player, locked, world)

                    -- Throttled debug logging: Print turret firing status (only every 2 seconds)
                    if canShoot and angleDiff and distance and currentTime - lastFiringLog > LOG_THROTTLE then
                        Log.debug(string.format("Enemy turret firing! Distance: %.1f, Angle diff: %.2f rad",
                            distance, math.abs(angleDiff)))
                        lastFiringLog = currentTime
                    end
                end
            end
        end
    else
        -- Debug: No equipment grid found (only log occasionally to avoid spam)
        if math.random() < 0.01 and currentTime - lastFiringLog > LOG_THROTTLE then
            Log.debug("Enemy has no equipment grid!")
            lastFiringLog = currentTime
        end
    end
end


local function handleRetreating(entity, dt, player)
    local ai = entity.components.ai
    local pos = entity.components.position
    local body = entity.components.physics and entity.components.physics.body

    if not player or not player.components or not player.components.position then
        -- Can't retreat from nothing, go back to patrolling
        ai.state = "patrolling"
        return
    end

    local playerPos = player.components.position
    local dx = playerPos.x - pos.x
    local dy = playerPos.y - pos.y
    local distance = math.sqrt(dx * dx + dy * dy)

    -- Move away from player
    local retreatAngle = math.atan2(-dy, -dx)  -- Opposite direction from player
    local speed = ai.chaseSpeed * 1.2  -- Retreat faster than chase
    local moveX = math.cos(retreatAngle) * speed
    local moveY = math.sin(retreatAngle) * speed

    -- Apply movement
    if body then
        body.vx = moveX
        body.vy = moveY
        body.angle = retreatAngle
    else
        entity.components.velocity.x = moveX
        entity.components.velocity.y = moveY
        pos.angle = retreatAngle
    end

    -- Check if far enough to stop retreating
    if distance > ai.detectionRange * 2 then
        ai.state = "patrolling"
    end
end

-- #################################################################################
-- ## Core AI Logic
-- #################################################################################

local function findPlayer(world)
    local players = world:get_entities_with_components("player")
    if #players > 0 then
        return players[1]  -- Return first player
    end
    return nil
end

local function updateAIState(entity, dt, player)
    local ai = entity.components.ai
    local health = entity.components.health

    -- Check if should retreat due to low health
    local retreatHealthPercent = ai.retreatHealthPercent
    if health and health.hp and health.maxHp and health.maxHp > 0 then
        local healthPercent = (health.hp / health.maxHp)
        if healthPercent < retreatHealthPercent then
            ai.state = "retreating"
            return
        end
    end

    -- Check damage response - if damaged by player, start hunting
    if ai.damagedByPlayer and ai:shouldReact(dt) then
        ai.isHunting = true
        ai.state = "hunting"
        ai.target = player
        ai.damagedByPlayer = false  -- Reset flag after reacting
        return
    end

    -- Simple radius-based detection
    if player and player.components and player.components.position then
        local entityPos = entity.components.position
        local playerPos = player.components.position

        if ai:isPlayerInRange(playerPos, entityPos) then
            -- Player entered detection radius, start hunting
            ai.isHunting = true
            ai.state = "hunting"
            ai.target = player
            return
        end
    end

    -- If hunting but target is out of range, stop hunting
    if ai.isHunting and ai.target then
        local entityPos = entity.components.position
        local targetPos = ai.target.components and ai.target.components.position

        if targetPos then
            local dx = targetPos.x - entityPos.x
            local dy = targetPos.y - entityPos.y
            local distance = math.sqrt(dx * dx + dy * dy)

            if distance > ai.detectionRange * 1.5 then
                ai.isHunting = false
                ai.state = "patrolling"
                ai.target = nil
            end
        else
            -- Target is invalid, stop hunting
            ai.isHunting = false
            ai.state = "patrolling"
            ai.target = nil
        end
    end
end

function AISystem.update(dt, world, spawnProjectile)
    -- Get all entities with AI component
    local aiEntities = world:get_entities_with_components("ai", "position")

    for _, entity in ipairs(aiEntities) do
        local ai = entity.components.ai

        updateBossMinions(entity, dt, world)

        -- Find player if we don't have a target
        if not ai.target then
            ai.target = findPlayer(world)
        end

        -- Update AI state (detection, damage response, etc.)
        updateAIState(entity, dt, ai.target)

        -- Execute current state behavior
        if ai.state == "patrolling" then
            handlePatrolling(entity, dt)
        elseif ai.state == "hunting" then
            handleHunting(entity, dt, ai.target, spawnProjectile, world)
        elseif ai.state == "retreating" then
            handleRetreating(entity, dt, ai.target)
        end
    end
end

return AISystem