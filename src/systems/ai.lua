local Util = require("src.core.util")
local AIComponent = require("src.components.ai")
local Sound = require("src.core.sound")

local AISystem = {}

-- Constants for AI behavior (now mostly handled by intelligence levels)
local ORBIT_TOLERANCE = 100  -- Tolerance around orbit distance
local TURN_RATE = 3.0        -- Turn rate in radians per second

-- Events system for damage detection
local Events = require("src.core.events")

-- Damage reaction handler
local function onEntityDamaged(eventData)
    local entity = eventData.entity
    local source = eventData.source
    local damage = eventData.damage

    -- Check if the damaged entity has AI
    if entity and entity.components and entity.components.ai then
        local ai = entity.components.ai

        -- Only react to damage from players or other entities (not self-damage)
        if source and source ~= entity and damage > 0 then
            -- Force set the attacker as the target
            ai.target = source

            -- Immediately and aggressively react to being attacked
            ai.state = "hunting"
            ai.hasSeenPlayer = true

            -- Store attacker position for immediate pursuit
            if source.components and source.components.position then
                ai.lastPlayerPos = {
                    x = source.components.position.x,
                    y = source.components.position.y
                }
            end

            -- Store damage information for enhanced aggression
            ai.recentDamage = (ai.recentDamage or 0) + damage
            ai.lastDamageTime = love.timer.getTime()

            -- Increase aggression temporarily when damaged
            ai.aggressionLevel = math.min(1.0, ai.aggressionLevel + 0.2)

            -- Enable persistent hunting so AI doesn't give up when damaged
            ai.intelligence.persistentHunting = true

            -- Reset search timer if we're searching
            if ai.state == "searching" then
                ai.searchTimer = 0
            end

            -- Set a flag to prevent visibility cone from overriding damage response
            ai.damagedByPlayer = true
            ai.damageResponseTime = love.timer.getTime()
        end
    end
end

-- Register damage event handler
Events.on(Events.GAME_EVENTS.ENTITY_DAMAGED, onEntityDamaged)

-- #################################################################################
-- ## State Handlers
-- #################################################################################

local function handlePatrollingState(entity, dt)
    local ai = entity.components.ai
    local ex, ey = entity.components.position.x, entity.components.position.y
    local px, py = ai.patrolCenter.x, ai.patrolCenter.y

    -- Debug: Check if patrol center is set correctly
    if not px or not py or (px == 0 and py == 0) then
        print(string.format("AI: Missing patrol center for entity at (%.1f, %.1f), using position", ex, ey))
        px, py = ex, ey
        ai.patrolCenter = {x = px, y = py}
    end

    -- Update patrol timer and angle
    ai.patrolTimer = (ai.patrolTimer or 0) + dt
    local patrolPeriod = 8 + math.random() * 4  -- Change direction every 8-12 seconds

    if ai.patrolTimer >= patrolPeriod then
        ai.patrolTimer = 0
        ai.patrolDirection = -ai.patrolDirection  -- Reverse direction
        ai.patrolAngle = ai.patrolAngle + (math.pi * 0.5 * ai.patrolDirection)  -- Turn 90 degrees
    end

    -- Calculate patrol position (make it more visible)
    local patrolDistance = ai.patrolRadius * 0.6  -- Go further out for more visible movement
    local patrolX = px + math.cos(ai.patrolAngle) * patrolDistance
    local patrolY = py + math.sin(ai.patrolAngle) * patrolDistance

    -- Move towards patrol point
    local distToPatrol = Util.distance(ex, ey, patrolX, patrolY)
    local speed = ai.patrolSpeed or 80
    local maxMoveDist = speed * dt

    if distToPatrol > 15 then  -- Move if not close to patrol point
        local angleToPatrol = Util.angleTo(ex, ey, patrolX, patrolY)

        -- Calculate velocity vector towards patrol point
        local velX = math.cos(angleToPatrol) * speed
        local velY = math.sin(angleToPatrol) * speed

        -- Apply movement to physics body
        local body = entity.components.physics and entity.components.physics.body
        if body then
            body:setVelocity(velX, velY)  -- Set velocity towards patrol point
        else
            entity.components.velocity.x, entity.components.velocity.y = velX, velY
        end

        -- Face movement direction
        if body then
            body.angle = angleToPatrol
        else
            entity.components.position.angle = angleToPatrol
        end
    end
end

local function handleSearchingState(entity, dt)
    local ai = entity.components.ai

    -- Search towards last known player position
    if ai.lastPlayerPos then
        local ex, ey = entity.components.position.x, entity.components.position.y
        local px, py = ai.lastPlayerPos.x, ai.lastPlayerPos.y
        local dist = Util.distance(ex, ey, px, py)

        local speed = ai.chaseSpeed or 150
        local maxMoveDist = speed * dt

        if dist > 50 then
            local angleToTarget = Util.angleTo(ex, ey, px, py)
            local moveX = math.cos(angleToTarget) * math.min(maxMoveDist, dist)
            local moveY = math.sin(angleToTarget) * math.min(maxMoveDist, dist)

            local body = entity.components.physics and entity.components.physics.body
            if body then
                body.vx, body.vy = moveX, moveY
            else
                entity.components.velocity.x, entity.components.velocity.y = moveX, moveY
            end

            -- Face target
            local moveAngle = math.atan2(moveY, moveX)
            if body then
                body.angle = moveAngle
            else
                entity.components.position.angle = moveAngle
            end
        end

        -- Search timer - give up after search duration
        ai.searchTimer = (ai.searchTimer or 0) + dt
        if ai.searchTimer >= ai.searchDuration then
            ai.state = "patrolling"
            ai.searchTimer = 0
            ai.lastPlayerPos = nil
        end
    else
        ai.state = "patrolling"
    end
end

-- Keep the old idle function for backward compatibility
local function handleIdleState(entity, dt)
    local ai = entity.components.ai
    ai.wanderTimer = (ai.wanderTimer or 0) - dt
    if (ai.wanderTimer or 0) <= 0 then
        ai.wanderTimer = 2 + math.random() * 3  -- Wander for 2-5 seconds
        ai.wanderDir = math.random() * math.pi * 2
    end

    -- Simple wandering movement
    local speed = 60  -- Slower when idle
    local moveVx = math.cos(ai.wanderDir or 0) * speed
    local moveVy = math.sin(ai.wanderDir or 0) * speed

    local body = entity.components.physics and entity.components.physics.body
    if body then
        body.vx, body.vy = moveVx, moveVy
    else
        entity.components.velocity.x, entity.components.velocity.y = moveVx, moveVy
    end
end

local function handleHuntingState(entity, dt, world, spawnProjectile)
    local ai = entity.components.ai
    local target = ai.target
    if not target or not target.components or not target.components.position then
        -- Lost target, start searching
        ai.lastPlayerPos = ai.lastPlayerPos or {x = entity.components.position.x, y = entity.components.position.y}
        ai.state = "searching"
        return
    end

    -- Enhanced aggression if recently damaged
    local timeSinceDamage = love.timer.getTime() - (ai.lastDamageTime or 0)
    local isRecentlyDamaged = timeSinceDamage < 3.0  -- 3 seconds of enhanced aggression
    local effectiveSpeed = isRecentlyDamaged and ai.chaseSpeed * 1.5 or ai.chaseSpeed or MAX_SPEED

    local ex, ey = entity.components.position.x, entity.components.position.y
    local px, py = target.components.position.x, target.components.position.y
    local dist = Util.distance(ex, ey, px, py)

    -- Update memory of player position
    ai.lastPlayerPos = {x = px, y = py}
    ai.hasSeenPlayer = true

    -- Calculate angle to target
    local angleToTarget = Util.angleTo(ex, ey, px, py)

    -- Determine movement behavior based on distance and intelligence
    local moveX, moveY = 0, 0
    local engagementRange = ai.intelligence.engagementRange

    if dist > engagementRange + ORBIT_TOLERANCE then
        -- Too far away - chase the target
        moveX = math.cos(angleToTarget) * effectiveSpeed
        moveY = math.sin(angleToTarget) * effectiveSpeed
    elseif dist < engagementRange - ORBIT_TOLERANCE then
        -- Too close - move away from target
        moveX = -math.cos(angleToTarget) * effectiveSpeed
        moveY = -math.sin(angleToTarget) * effectiveSpeed
    else
        -- At engagement distance - orbit around target
        local orbitAngle = angleToTarget + math.pi * 0.5  -- Perpendicular to target
        moveX = math.cos(orbitAngle) * effectiveSpeed * 0.7  -- Slower orbit speed
        moveY = math.sin(orbitAngle) * effectiveSpeed * 0.7
    end

    -- Apply movement
    local body = entity.components.physics and entity.components.physics.body
    if body then
        body.vx, body.vy = moveX, moveY
    else
        entity.components.velocity.x, entity.components.velocity.y = moveX, moveY
    end

    -- Face the target
    local currentAngle = entity.components.position.angle or 0
    local angleDiff = (angleToTarget - currentAngle + math.pi) % (2 * math.pi) - math.pi
    local turnStep = math.max(-TURN_RATE * dt, math.min(TURN_RATE * dt, angleDiff))

    if body then
        body.angle = currentAngle + turnStep
        body.angularVel = 0  -- Prevent wobble
    else
        entity.components.position.angle = currentAngle + turnStep
    end

    -- Enhanced firing logic - check equipment grid for turrets
    if entity.components.equipment and entity.components.equipment.grid then
        for _, slot in ipairs(entity.components.equipment.grid) do
            if slot and slot.module and slot.type == "turret" and slot.enabled ~= false then
                local turret = slot.module
                local maxRange = (turret.optimal or 300) + (turret.falloff or 200)
                local facingTolerance = math.rad(15)  -- More forgiving aim

                -- Check if we should fire
                local shouldFire = dist <= maxRange and math.abs(angleDiff) < facingTolerance

                if shouldFire then
                    -- Ensure turret is in automatic mode and ready to fire
                    if turret.fireMode ~= "automatic" then
                        turret.fireMode = "automatic"
                    end
                    turret.autoFire = true

                    -- Update turret (it will handle firing internally)
                    local worldRef = entity.world or world
                    turret:update(dt, target, false, worldRef)
                else
                    -- If not firing, make sure autoFire is disabled
                    turret.autoFire = false
                end
            end
        end
    end

    -- Check if target is out of detection range, but respect damage response
    local timeSinceDamage = love.timer.getTime() - (ai.lastDamageTime or 0)
    local isInDamageResponse = ai.damagedByPlayer and timeSinceDamage < 10.0

    -- Only switch to searching if not in damage response mode
    if dist > ai.intelligence.detectionRange and not isInDamageResponse then
        ai.state = "searching"
    end
end


local function handleRetreatingState(entity, dt)
    local ai = entity.components.ai
    local target = ai.target
    if not target or not target.components or not target.components.position then
        return
    end
    
    local ex, ey = entity.components.position.x, entity.components.position.y
    local px, py = target.components.position.x, target.components.position.y
    
    -- Move away from target
    local fromTargetAngle = Util.angleTo(px, py, ex, ey)
    local speed = MAX_SPEED * 1.2  -- Retreat faster
    local moveX = math.cos(fromTargetAngle) * speed
    local moveY = math.sin(fromTargetAngle) * speed
    
    local body = entity.components.physics and entity.components.physics.body
    if body then
        body.vx, body.vy = moveX, moveY
    else
        entity.components.velocity.x, entity.components.velocity.y = moveX, moveY
    end
end

-- #################################################################################
-- ## Core AI Logic
-- #################################################################################

local function findTarget(entity, world)
    local players = world:get_entities_with_components("player")
    if #players > 0 then
        return players[1] -- Return first player as the target
    end
    return nil
end

local function updateState(entity, dt, world)
    local ai = entity.components.ai
    local health = entity.components.health
    local target = ai.target

    -- Find target if we don't have one
    if not target or not target.components or not target.components.position or target.dead then
        target = findTarget(entity, world)
        ai.target = target
        if not target then
            -- No target found, keep current state or go to patrolling
            if ai.state == "hunting" or ai.state == "searching" then
                ai.state = "patrolling"
            end
            return
        end
    end

    local ex, ey = entity.components.position.x, entity.components.position.y
    local px, py = target.components.position.x, target.components.position.y
    local dist = Util.distance(ex, ey, px, py)

    -- Health-based retreat (only if very low health)
    local retreatHealthPercent = ai.intelligence.retreatHealthPercent
    if health and health.hp and health.maxHp and health.maxHp > 0 and (health.hp / health.maxHp < retreatHealthPercent) then
        ai.state = "retreating"
        return
    end

    -- Detection and engagement logic
    local detectionRange = ai.intelligence.detectionRange
    local engagementRange = ai.intelligence.engagementRange

    -- If retreating and far enough away, go back to patrolling
    if ai.state == "retreating" and dist > detectionRange then
        ai.state = "patrolling"
        return
    end

    -- Cone-based detection: check if player is within detection cone (more realistic)
    local coneAngle = math.pi / 3  -- 60 degrees total detection cone
    local halfConeAngle = coneAngle / 2

    -- Calculate angle from enemy to player
    local angleToPlayer = Util.angleTo(ex, ey, px, py)

    -- Normalize angles to [0, 2*pi] - forward is local +X (matches renderer)
    local enemyAngle = entity.components.position.angle or 0
    local normalizedEnemyAngle = ((enemyAngle % (math.pi * 2)) + (math.pi * 2)) % (math.pi * 2)

    -- Calculate angle difference
    local angleDiff = angleToPlayer - normalizedEnemyAngle
    angleDiff = ((angleDiff % (math.pi * 2)) + (math.pi * 2)) % (math.pi * 2)
    if angleDiff > math.pi then
        angleDiff = angleDiff - math.pi * 2
    end

    -- Check if player is within detection cone AND range
    local isInDetectionCone = dist <= detectionRange and math.abs(angleDiff) <= halfConeAngle

    -- Check if we're in damage response mode (should override visibility cone)
    local timeSinceDamage = love.timer.getTime() - (ai.damageResponseTime or 0)
    local isInDamageResponse = ai.damagedByPlayer and timeSinceDamage < 10.0  -- 10 seconds of persistent hunting after damage

    -- State transitions based on cone-based detection - but respect damage response
    if isInDetectionCone then
        if ai.state == "patrolling" or ai.state == "searching" or ai.state == "idle" then
            -- Immediately switch to hunting when player is detected in cone - MORE AGGRESSIVE
            ai.state = "hunting"
            ai.hasSeenPlayer = true
            ai.lastPlayerPos = {x = px, y = py}
            ai.searchTimer = 0  -- Reset search timer
            -- Increase aggression when player is detected
            ai.aggressionLevel = math.min(1.0, ai.aggressionLevel + 0.3)
        end
    else
        -- Out of range - check if we should search or go back to patrolling
        -- BUT don't override hunting state if we're in damage response mode
        if ai.state == "hunting" and not isInDamageResponse then
            if ai.intelligence.persistentHunting then
                ai.state = "searching"
            else
                ai.state = "patrolling"
            end
        elseif ai.state == "searching" then
            -- Keep searching for a bit, then go back to patrolling
            ai.searchTimer = (ai.searchTimer or 0) + dt
            if ai.searchTimer >= ai.searchDuration then
                ai.state = "patrolling"
                ai.searchTimer = 0
            end
        end
    end

    -- Store player position for memory/search behavior (cone-based)
    if isInDetectionCone and target then
        ai.lastPlayerPos = {x = px, y = py}
        ai.hasSeenPlayer = true
        ai.searchTimer = 0  -- Reset search timer when we see the player
    end

    -- Clear damage response flag after response period expires
    local timeSinceDamage = love.timer.getTime() - (ai.damageResponseTime or 0)
    if ai.damagedByPlayer and timeSinceDamage > 10.0 then
        ai.damagedByPlayer = false
        ai.damageResponseTime = nil
        -- Reset persistent hunting to intelligence default
        ai.intelligence.persistentHunting = ai.intelligence.defaultPersistentHunting or false
    end
end

function AISystem.update(dt, world, spawnProjectile)
    -- Get all entities with AI component (remove velocity requirement)
    local aiEntities = world:get_entities_with_components("ai", "position")

    for _, entity in ipairs(aiEntities) do
        local ai = entity.components.ai

        -- Energy regeneration for entities with energy
        if entity.components.health and entity.components.health.maxEnergy > 0 then
            local baseRegen = entity.energyRegen or 35
            entity.components.health.energy = math.min(
                entity.components.health.maxEnergy,
                entity.components.health.energy + (baseRegen * dt)
            )
        end

        -- Find target if we don't have one (or if target is dead/invalid)
        if not ai.target or not ai.target.components or not ai.target.components.position or ai.target.dead then
            ai.target = findTarget(entity, world)
        end

        -- Store world reference for damage detection
        entity.world = world

        -- Update AI state
        updateState(entity, dt, world)

        -- Execute state-specific behavior
        if ai.state == "idle" then
            handleIdleState(entity, dt)
        elseif ai.state == "patrolling" then
            handlePatrollingState(entity, dt)
        elseif ai.state == "searching" then
            handleSearchingState(entity, dt)
        elseif ai.state == "hunting" then
            handleHuntingState(entity, dt, world, spawnProjectile)
        elseif ai.state == "retreating" then
            handleRetreatingState(entity, dt)
        end
    end
end

return AISystem