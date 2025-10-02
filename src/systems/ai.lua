local Util = require("src.core.util")
local AIComponent = require("src.components.ai")
local Log = require("src.core.log")
local SpaceStationSystem = require("src.systems.hub")
local EntityFactory = require("src.templates.entity_factory")

local AISystem = {}

-- Simple constants for basic AI
local PATROL_RADIUS = 400  -- How far enemies patrol from spawn point
local BOSS_MINION_MAX = 3
local BOSS_MINION_INTERVAL_MIN = 4.0
local BOSS_MINION_INTERVAL_MAX = 6.0
local BOSS_MINION_OFFSET = 160

-- Weapon-based behavior constants
local WEAPON_BEHAVIORS = {
    -- Long range weapons (rockets, snipers) - keep distance
    long_range = {
        optimal_range_multiplier = 1.2,  -- Stay at 120% of optimal range
        approach_threshold = 0.8,        -- Only approach when below 80% of optimal
        retreat_threshold = 1.5,         -- Retreat when closer than 150% of optimal
        speed_multiplier = 0.8,          -- Slower, more deliberate movement
        behavior_name = "kiting"
    },
    -- Medium range weapons (guns, lasers) - balanced approach
    medium_range = {
        optimal_range_multiplier = 1.0,  -- Stay at optimal range
        approach_threshold = 0.7,        -- Approach when below 70% of optimal
        retreat_threshold = 1.3,         -- Retreat when closer than 130% of optimal
        speed_multiplier = 1.0,          -- Normal speed
        behavior_name = "orbiting"
    },
    -- Short range weapons (shotguns, close combat) - aggressive approach
    short_range = {
        optimal_range_multiplier = 0.8,  -- Get closer than optimal range
        approach_threshold = 1.2,        -- Always try to get closer
        retreat_threshold = 0.6,         -- Only retreat when very close
        speed_multiplier = 1.3,          -- Faster, more aggressive movement
        behavior_name = "rushing"
    },
    -- Mixed weapons - use most common behavior
    mixed = {
        optimal_range_multiplier = 1.0,
        approach_threshold = 0.8,
        retreat_threshold = 1.2,
        speed_multiplier = 1.0,
        behavior_name = "adaptive"
    }
}

-- Logging throttle to prevent spam

-- Analyze enemy weapons and determine appropriate behavior
local function analyzeWeaponBehavior(entity)
    if not entity or not entity.components or not entity.components.equipment then
        return WEAPON_BEHAVIORS.medium_range -- Default behavior
    end
    
    local equipment = entity.components.equipment
    if not equipment.grid then
        return WEAPON_BEHAVIORS.medium_range
    end
    
    local weapons = {}
    local totalOptimalRange = 0
    local weaponCount = 0
    
    -- Analyze all equipped turrets
    for _, slot in ipairs(equipment.grid) do
        if slot and slot.module and slot.type == "turret" and slot.enabled ~= false then
            local turret = slot.module
            if turret.optimal then
                local weaponType = turret.type or "gun"
                local optimalRange = turret.optimal
                
                table.insert(weapons, {
                    type = weaponType,
                    optimal = optimalRange,
                    maxRange = turret.maxRange or optimalRange * 2
                })
                
                totalOptimalRange = totalOptimalRange + optimalRange
                weaponCount = weaponCount + 1
            end
        end
    end
    
    if weaponCount == 0 then
        return WEAPON_BEHAVIORS.medium_range
    end
    
    -- Calculate average optimal range
    local avgOptimalRange = totalOptimalRange / weaponCount
    
    -- Check for special weapon types first
    local hasRockets = false
    local hasLasers = false
    local hasGuns = false
    
    for _, weapon in ipairs(weapons) do
        if weapon.type == "missile" or weapon.type == "rocket" then
            hasRockets = true
        elseif weapon.type == "laser" then
            hasLasers = true
        elseif weapon.type == "gun" then
            hasGuns = true
        end
    end
    
    -- Special behaviors for specific weapon combinations
    if hasRockets and not hasGuns and not hasLasers then
        -- Pure rocket loadout - extreme kiting
        return {
            optimal_range_multiplier = 1.5,  -- Stay at 150% of optimal range
            approach_threshold = 0.6,        -- Only approach when very far
            retreat_threshold = 2.0,         -- Retreat when closer than 200% of optimal
            speed_multiplier = 0.7,          -- Slower, more deliberate
            behavior_name = "rocket_kiting"
        }
    elseif hasLasers and not hasRockets and not hasGuns then
        -- Pure laser loadout - precise positioning
        return {
            optimal_range_multiplier = 0.9,  -- Stay just under optimal range
            approach_threshold = 0.8,        -- Approach when below 80% of optimal
            retreat_threshold = 1.1,         -- Retreat when closer than 110% of optimal
            speed_multiplier = 1.1,          -- Slightly faster for positioning
            behavior_name = "laser_precision"
        }
    elseif hasGuns and not hasRockets and not hasLasers then
        -- Pure gun loadout - aggressive brawling
        return {
            optimal_range_multiplier = 0.7,  -- Get closer than optimal
            approach_threshold = 1.3,        -- Always try to get closer
            retreat_threshold = 0.5,         -- Only retreat when very close
            speed_multiplier = 1.4,          -- Fast and aggressive
            behavior_name = "gun_brawling"
        }
    end
    
    -- Determine behavior based on average range for mixed loadouts
    if avgOptimalRange >= 1200 then
        return WEAPON_BEHAVIORS.long_range
    elseif avgOptimalRange <= 600 then
        return WEAPON_BEHAVIORS.short_range
    else
        return WEAPON_BEHAVIORS.medium_range
    end
end

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

    -- Initialize patrol state if not present
    ai.patrolTimer = (ai.patrolTimer or 0) + dt
    ai.patrolPauseTimer = ai.patrolPauseTimer or 0
    ai.patrolTarget = ai.patrolTarget or {x = ai.patrolCenter.x, y = ai.patrolCenter.y}

    -- Check if we need to pause or change direction
    if ai.patrolPauseTimer > 0 then
        -- Pause for a moment (idle behavior)
        ai.patrolPauseTimer = ai.patrolPauseTimer - dt
        if body then
            body.vx = 0
            body.vy = 0
        else
            entity.components.velocity.x = 0
            entity.components.velocity.y = 0
        end
        return
    end

    -- Change direction or pause every 8-15 seconds
    if ai.patrolTimer >= 8 + math.random() * 7 then
        ai.patrolTimer = 0
        
        -- 30% chance to pause instead of changing direction
        if math.random() < 0.3 then
            ai.patrolPauseTimer = 2 + math.random() * 3  -- Pause for 2-5 seconds
            return
        end
        
        -- Change direction or pick new target
        if math.random() < 0.6 then
            -- 60% chance to change direction
            ai.patrolDirection = -ai.patrolDirection
        else
            -- 40% chance to pick a new random target within patrol radius
            local angle = math.random() * math.pi * 2
            local radius = math.random() * PATROL_RADIUS * 0.8  -- Use 80% of max radius
            ai.patrolTarget.x = ai.patrolCenter.x + math.cos(angle) * radius
            ai.patrolTarget.y = ai.patrolCenter.y + math.sin(angle) * radius
        end
    end

    -- Calculate patrol position
    local patrolX, patrolY
    
    if ai.patrolTarget then
        -- Move towards specific target
        patrolX = ai.patrolTarget.x
        patrolY = ai.patrolTarget.y
    else
        -- Circular patrol around center
        local patrolAngle = ai.patrolAngle + (ai.patrolDirection * dt * 0.3)  -- Slower rotation
        ai.patrolAngle = patrolAngle
        patrolX = ai.patrolCenter.x + math.cos(patrolAngle) * PATROL_RADIUS
        patrolY = ai.patrolCenter.y + math.sin(patrolAngle) * PATROL_RADIUS
    end

    -- Move towards patrol point
    local dx = patrolX - pos.x
    local dy = patrolY - pos.y
    local distance = math.sqrt(dx * dx + dy * dy)

    if distance > 30 then  -- Minimum distance to keep moving
        local speed = ai.patrolSpeed * (0.8 + math.random() * 0.4)  -- Vary speed slightly
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
    else
        -- Reached target, pick a new one
        ai.patrolTarget = nil
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


    -- Get weapon-based behavior configuration
    local weaponBehavior = analyzeWeaponBehavior(entity)
    local ai = entity.components.ai
    
    -- Calculate optimal range based on weapon behavior
    local optimalRange = 800  -- Default fallback
    if entity.components.equipment and entity.components.equipment.grid then
        local totalOptimalRange = 0
        local weaponCount = 0
        for _, slot in ipairs(entity.components.equipment.grid) do
            if slot and slot.module and slot.type == "turret" and slot.enabled ~= false then
                local turret = slot.module
                if turret.optimal then
                    totalOptimalRange = totalOptimalRange + turret.optimal
                    weaponCount = weaponCount + 1
                end
            end
        end
        if weaponCount > 0 then
            optimalRange = (totalOptimalRange / weaponCount) * weaponBehavior.optimal_range_multiplier
        end
    end

    -- Determine movement strategy based on weapon behavior
    local targetX, targetY = playerPos.x, playerPos.y
    local currentRange = distance
    
    -- Calculate desired range based on weapon behavior
    local desiredRange = optimalRange
    local approachThreshold = desiredRange * weaponBehavior.approach_threshold
    local retreatThreshold = desiredRange * weaponBehavior.retreat_threshold
    
    -- Adjust movement based on current range vs desired range
    if currentRange < retreatThreshold then
        -- Too close - retreat while maintaining angle
        local retreatAngle = math.atan2(dy, dx) + math.pi -- Opposite direction
        targetX = pos.x + math.cos(retreatAngle) * (retreatThreshold - currentRange)
        targetY = pos.y + math.sin(retreatAngle) * (retreatThreshold - currentRange)
    elseif currentRange > approachThreshold then
        -- Too far - approach player
        targetX = playerPos.x
        targetY = playerPos.y
    else
        -- In good range - orbit around player
        if not ai.orbitAngle then
            ai.orbitAngle = math.random() * 2 * math.pi
        end
        
        -- Update orbit angle for continuous orbiting
        local orbitSpeed = 0.3 * weaponBehavior.speed_multiplier
        ai.orbitAngle = ai.orbitAngle + dt * orbitSpeed
        
        -- Calculate orbit position
        targetX = playerPos.x + math.cos(ai.orbitAngle) * desiredRange
        targetY = playerPos.y + math.sin(ai.orbitAngle) * desiredRange
    end

    -- Calculate direction to target position
    local orbitDx = targetX - pos.x
    local orbitDy = targetY - pos.y
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

    local speed = ai.chaseSpeed * weaponBehavior.speed_multiplier
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
            -- Enemies can shoot in any direction - no facing restrictions
            canShoot = true
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

                end
            end
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
        local distance = math.sqrt((playerPos.x - entityPos.x)^2 + (playerPos.y - entityPos.y)^2)

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

    -- Clear target if not hunting and not in range
    if not ai.isHunting and ai.target then
        ai.target = nil
    end
end

function AISystem.update(dt, world, spawnProjectile)
    -- Get all entities with AI component
    local aiEntities = world:get_entities_with_components("ai", "position")

    -- Cache player reference - only look it up once per frame
    local player = findPlayer(world)

    for _, entity in ipairs(aiEntities) do
        local ai = entity.components.ai

        updateBossMinions(entity, dt, world)
        
        -- Update AI state (detection, damage response, etc.)
        updateAIState(entity, dt, player)

        -- Execute current state behavior
        if ai.state == "patrolling" then
            handlePatrolling(entity, dt)
        elseif ai.state == "hunting" then
            -- Only hunt if we have a valid target
            if ai.target and ai.target.components and ai.target.components.position then
                handleHunting(entity, dt, ai.target, spawnProjectile, world)
            else
                -- Invalid target, go back to patrolling
                ai.state = "patrolling"
                ai.isHunting = false
                ai.target = nil
                handlePatrolling(entity, dt)
            end
        elseif ai.state == "retreating" then
            handleRetreating(entity, dt, ai.target)
        end
    end
end

return AISystem