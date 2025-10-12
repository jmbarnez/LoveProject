local AIComponent = require("src.components.ai")
local SimpleTurretAI = require("src.components.simple_turret_ai")
local Settings = require("src.core.settings")
local NetworkSession = require("src.core.network.session")

local AISystem = {}

local STATE = AIComponent.STATE
local ZERO_POS = { x = 0, y = 0 }

local function getPosition(entity)
    if entity and entity.components and entity.components.position then
        return entity.components.position
    end
    return ZERO_POS
end

local function getPhysicsBody(entity)
    if not entity or not entity.components then
        return nil
    end
    local physics = entity.components.physics
    return physics and physics.body or nil
end

local function applyMovement(entity, vx, vy)
    if not entity or not entity.components then
        return
    end

    local body = getPhysicsBody(entity)
    if body then
        body.vx = vx
        body.vy = vy
        if (vx ~= 0) or (vy ~= 0) then
            body.angle = math.atan2(vy, vx)
        end
        return
    end

    local velocity = entity.components.velocity
    if velocity then
        velocity.x = vx
        velocity.y = vy
    end

    local pos = entity.components.position
    if pos and ((vx ~= 0) or (vy ~= 0)) then
        pos.angle = math.atan2(vy, vx)
    end
end

local function stopMovement(entity)
    applyMovement(entity, 0, 0)
end

local function normalise(dx, dy)
    local magSq = dx * dx + dy * dy
    if magSq <= 0 then
        return 0, 0, 0
    end
    local mag = math.sqrt(magSq)
    return dx / mag, dy / mag, mag
end

local function gatherPlayers(world)
    local result = {}
    if not (world and world.getEntities) then
        return result
    end

    for _, entity in pairs(world:getEntities()) do
        if entity and (entity.isPlayer or entity.isRemotePlayer) and entity.components and entity.components.position then
            table.insert(result, entity)
        end
    end

    return result
end

local function findClosestPlayer(world, origin)
    local best, bestDistSq = nil, nil
    for _, player in ipairs(gatherPlayers(world)) do
        local pos = player.components.position
        local dx = pos.x - origin.x
        local dy = pos.y - origin.y
        local distSq = dx * dx + dy * dy
        if not bestDistSq or distSq < bestDistSq then
            best = player
            bestDistSq = distSq
        end
    end
    return best
end

local function isValidTarget(target)
    return target
        and not target.dead
        and target.components
        and target.components.position ~= nil
end

local function acquireTarget(world, entity, ai)
    local pos = getPosition(entity)
    local current = ai.target
    local leashDistance = ai.detectionRange + (ai.lossBuffer or 0)
    local leashSq = leashDistance * leashDistance

    if isValidTarget(current) then
        local targetPos = current.components.position
        local dx = targetPos.x - pos.x
        local dy = targetPos.y - pos.y
        local distSq = dx * dx + dy * dy

        if distSq <= leashSq then
            ai.lastKnownTargetPos = ai.lastKnownTargetPos or {}
            ai.lastKnownTargetPos.x = targetPos.x
            ai.lastKnownTargetPos.y = targetPos.y
            ai:rememberTarget()
            return current, distSq
        end
    end

    ai.target = nil

    local best, bestDistSq = nil, nil
    local detectionSq = ai.detectionRange * ai.detectionRange
    for _, player in ipairs(gatherPlayers(world)) do
        local playerPos = player.components.position
        local dx = playerPos.x - pos.x
        local dy = playerPos.y - pos.y
        local distSq = dx * dx + dy * dy

        if distSq <= detectionSq and (not bestDistSq or distSq < bestDistSq) then
            best = player
            bestDistSq = distSq
        end
    end

    if best then
        ai.target = best
        ai.lastKnownTargetPos = ai.lastKnownTargetPos or {}
        ai.lastKnownTargetPos.x = best.components.position.x
        ai.lastKnownTargetPos.y = best.components.position.y
        ai:rememberTarget()
        return best, bestDistSq
    end

    return nil, nil
end

local function chooseState(entity, ai, targetDistSq, dt)
    ai:updateTimers(dt)

    if isValidTarget(ai.target) and targetDistSq then
        local attackRange = ai.attackRange or 0
        local attackRangeSq = attackRange * attackRange
        if attackRange > 0 and targetDistSq <= attackRangeSq then
            ai:setState(STATE.ATTACK)
        else
            ai:setState(STATE.CHASE)
        end
        return
    end

    if ai.lastKnownTargetPos and ai:hasFreshTargetMemory() then
        ai:setState(STATE.CHASE)
        return
    end

    ai:setState(STATE.PATROL)
    ai.lastKnownTargetPos = nil
end

local function ensurePatrolTarget(ai)
    if ai.patrolTarget then
        return
    end

    local angle = math.random() * math.pi * 2
    local radius = (math.random() * 0.6 + 0.2) * (ai.patrolRadius or 200)
    ai.patrolTarget = {
        x = ai.patrolCenter.x + math.cos(angle) * radius,
        y = ai.patrolCenter.y + math.sin(angle) * radius,
    }
    ai.patrolDuration = 2.5 + math.random() * 3.0
    ai.patrolTimer = 0
    ai.patrolHeading = angle
end

local function handlePatrol(entity, ai, dt)
    ai.patrolTimer = (ai.patrolTimer or 0) + dt
    ensurePatrolTarget(ai)

    local pos = getPosition(entity)
    local target = ai.patrolTarget

    local dx = target.x - pos.x
    local dy = target.y - pos.y
    local ux, uy, dist = normalise(dx, dy)

    if dist < 20 or (ai.patrolDuration and ai.patrolTimer >= ai.patrolDuration) then
        ai.patrolTarget = nil
        stopMovement(entity)
        return
    end

    local jitter = (math.random() - 0.5) * 0.3
    local speed = (ai.patrolSpeed or 0) * (1 + jitter)
    applyMovement(entity, ux * speed, uy * speed)
end

local function handleChase(entity, ai, dt)
    local pos = getPosition(entity)
    local goalPos = nil

    if isValidTarget(ai.target) then
        goalPos = ai.target.components.position
        ai.lastKnownTargetPos = ai.lastKnownTargetPos or {}
        ai.lastKnownTargetPos.x = goalPos.x
        ai.lastKnownTargetPos.y = goalPos.y
    elseif ai.lastKnownTargetPos and ai:hasFreshTargetMemory() then
        goalPos = ai.lastKnownTargetPos
    end

    if not goalPos then
        stopMovement(entity)
        return
    end

    local dx = goalPos.x - pos.x
    local dy = goalPos.y - pos.y
    local ux, uy, dist = normalise(dx, dy)

    if not isValidTarget(ai.target) and dist < 25 then
        ai.lastKnownTargetPos = nil
        stopMovement(entity)
        return
    end

    applyMovement(entity, ux * (ai.chaseSpeed or 0), uy * (ai.chaseSpeed or 0))
end

local function handleAttack(entity, ai)
    if not isValidTarget(ai.target) then
        ai:setState(STATE.CHASE)
        return
    end

    local pos = getPosition(entity)
    local targetPos = ai.target.components.position
    ai.lastKnownTargetPos = ai.lastKnownTargetPos or {}
    ai.lastKnownTargetPos.x = targetPos.x
    ai.lastKnownTargetPos.y = targetPos.y

    local dx = targetPos.x - pos.x
    local dy = targetPos.y - pos.y
    local ux, uy, dist = normalise(dx, dy)

    if dist == 0 then
        stopMovement(entity)
        return
    end

    local desired = ai.attackRange or 0
    local speed = (ai.chaseSpeed or 0) * 0.9
    local vx, vy

    if desired <= 0 then
        vx, vy = ux * speed, uy * speed
    elseif dist > desired * 1.15 then
        vx, vy = ux * speed, uy * speed
    elseif dist < desired * 0.7 then
        vx, vy = -ux * speed, -uy * speed
    else
        local dir = ai.attackOrbitDir or 1
        if ai.stateTime and ai.stateTime > 6 then
            dir = -dir
            ai.attackOrbitDir = dir
            ai.stateTime = 0
        end
        vx = -uy * speed * dir
        vy = ux * speed * dir
    end

    applyMovement(entity, vx, vy)
end


local function updateTurretModules(entity, dt, world, target, shouldFire)
    local equipment = entity.components and entity.components.equipment
    if not (equipment and equipment.grid) then
        entity.weaponsDisabled = false
        return
    end

    entity.weaponsDisabled = false
    local locked = not (shouldFire and isValidTarget(target))

    for _, slot in ipairs(equipment.grid) do
        if slot and slot.module and slot.type == "turret" and slot.enabled ~= false then
            local turret = slot.module
            if type(turret.update) == "function" then
                turret.fireMode = "automatic"
                turret.autoFire = shouldFire
                turret:update(dt, target, locked, world)
            end
        end
    end
end

-- Calculate effective maximum range for a weapon based on projectile speed and lifetime
local function calculateWeaponMaxRange(turret)
    if not turret then
        return 0
    end
    
    -- Get projectile speed and lifetime from turret's embedded projectile definition
    local projSpeed = 700 -- Default speed
    local projLifetime = 2.0 -- Default lifetime
    
    if turret.projectile and type(turret.projectile) == "table" then
        if turret.projectile.physics and turret.projectile.physics.speed then
            projSpeed = turret.projectile.physics.speed
        end
        if turret.projectile.timed_life and turret.projectile.timed_life.duration then
            projLifetime = turret.projectile.timed_life.duration
        end
    elseif turret.projectileSpeed then
        projSpeed = turret.projectileSpeed
    end
    
    -- Calculate effective range: speed * lifetime
    local effectiveRange = projSpeed * projLifetime
    
    -- For hitscan weapons (like lasers), use the turret's maxRange if available
    if turret.maxRange and turret.maxRange > 0 then
        effectiveRange = turret.maxRange
    end
    
    return effectiveRange
end

-- Check if any weapon on the entity can effectively hit the target
local function canAnyWeaponHitTarget(entity, target)
    if not isValidTarget(target) then
        return false
    end
    
    local equipment = entity.components and entity.components.equipment
    if not (equipment and equipment.grid) then
        return false
    end
    
    local pos = getPosition(entity)
    local targetPos = target.components.position
    local dx = targetPos.x - pos.x
    local dy = targetPos.y - pos.y
    local distSq = dx * dx + dy * dy
    local distance = math.sqrt(distSq)
    
    -- Check each turret to see if any can reach the target
    for _, slot in ipairs(equipment.grid) do
        if slot and slot.module and slot.type == "turret" and slot.enabled ~= false then
            local turret = slot.module
            local maxRange = calculateWeaponMaxRange(turret)
            
            -- Add a small buffer (10% of range) to account for movement during projectile flight
            local effectiveRange = maxRange * 1.1
            
            if distance <= effectiveRange then
                return true
            end
        end
    end
    
    return false
end

local function updateWeapons(entity, ai, dt, world)
    if not isValidTarget(ai.target) then
        updateTurretModules(entity, dt, world, nil, false)
        return
    end

    -- Check if any weapon can effectively hit the target
    local shouldFire = canAnyWeaponHitTarget(entity, ai.target)

    updateTurretModules(entity, dt, world, ai.target, shouldFire)
end

local function updateShipEnemy(entity, world, dt)
    local ai = entity.components.ai
    if not ai or getmetatable(ai) == SimpleTurretAI then
        return
    end

    if entity.isRemoteEnemy then
        return
    end

    local _, targetDistSq = acquireTarget(world, entity, ai)
    chooseState(entity, ai, targetDistSq, dt)

    if ai.state == STATE.PATROL then
        handlePatrol(entity, ai, dt)
    elseif ai.state == STATE.CHASE then
        handleChase(entity, ai, dt)
    elseif ai.state == STATE.ATTACK then
        handleAttack(entity, ai)
    else
        handlePatrol(entity, ai, dt)
    end

    updateWeapons(entity, ai, dt, world)
end

local function updateTurretEnemy(entity, world, dt)
    local ai = entity.components.ai
    if not (ai and getmetatable(ai) == SimpleTurretAI) then
        return
    end

    local pos = getPosition(entity)
    local closestPlayer = findClosestPlayer(world, pos)

    ai:update(dt, entity, world, closestPlayer)

    local turretTarget = nil
    if type(ai.getCurrentTarget) == "function" then
        turretTarget = ai:getCurrentTarget()
    end

    local canFire = false
    if type(ai.canFire) == "function" then
        canFire = ai:canFire()
    end

    local effectiveTarget = isValidTarget(turretTarget) and turretTarget or closestPlayer
    updateTurretModules(entity, dt, world, effectiveTarget, canFire)
end

function AISystem.update(dt, world)
    if not (world and world.get_entities_with_components) then
        return
    end

    local networkingSettings = Settings.getNetworkingSettings()
    if networkingSettings and networkingSettings.host_authoritative_enemies then
        local manager = NetworkSession.getManager()
        if manager and manager:isMultiplayer() and not manager:isHost() then
            return
        end
    end

    local entities = world:get_entities_with_components("ai", "position")
    for _, entity in ipairs(entities) do
        local ai = entity.components.ai
        if getmetatable(ai) == SimpleTurretAI or entity.aiType == "turret" then
            updateTurretEnemy(entity, world, dt)
        else
            updateShipEnemy(entity, world, dt)
        end
    end
end

return AISystem
