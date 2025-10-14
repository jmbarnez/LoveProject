-- Modular AI system for drones based on weapon modules
-- Drones change behavior based on their equipped weapons

local TurretSystem = require("src.systems.turret.system")

local ModularDroneAI = {}
local updateHealingBehavior
local updateCombatBehavior

local function iterateTurrets(drone, handler)
    local equipment = drone.components and drone.components.equipment
    if not (equipment and equipment.grid) then
        return
    end

    for _, slot in ipairs(equipment.grid) do
        if slot and slot.module and slot.type == "turret" and slot.enabled ~= false then
            handler(slot, slot.module)
        end
    end
end

local function findTurret(drone, predicate)
    local result
    iterateTurrets(drone, function(slot, turret)
        if not result and predicate(turret, slot) then
            result = turret
        end
    end)
    return result
end

local function getTurretRange(turret)
    if not turret then
        return 0
    end

    if turret.maxRange and turret.maxRange > 0 then
        return turret.maxRange
    end

    if turret.optimal and turret.optimal > 0 then
        return turret.optimal
    end

    if turret.projectile and type(turret.projectile) == "table" then
        local proj = turret.projectile
        local speed = proj.physics and proj.physics.speed
        local lifetime = proj.timed_life and proj.timed_life.duration
        if speed and speed > 0 and lifetime and lifetime > 0 then
            return speed * lifetime
        end
    end

    if turret.projectileSpeed and turret.cycle then
        return turret.projectileSpeed * turret.cycle
    end

    return 0
end

local function resolveRange(base, fallback)
    if base and base > 0 then
        return base
    end
    return fallback or 0
end

-- Calculate orbit position around a target
local function calculateOrbitPosition(target, drone, orbitRadius, orbitSpeed, dt)
    local targetPos = target.components.position
    local dronePos = drone.components.position
    
    if not targetPos or not dronePos then return nil, nil end
    
    -- Initialize orbit angle if not set
    if not drone.orbitAngle then
        drone.orbitAngle = math.random() * math.pi * 2
    end
    
    -- Update orbit angle
    drone.orbitAngle = drone.orbitAngle + (orbitSpeed or 0) * dt
    
    -- Calculate orbit position
    local orbitX = targetPos.x + math.cos(drone.orbitAngle) * orbitRadius
    local orbitY = targetPos.y + math.sin(drone.orbitAngle) * orbitRadius
    
    return orbitX, orbitY
end

-- Move towards a target position using physics system
local function moveTowards(entity, targetX, targetY, dt, tolerance)
    local pos = entity.components.position
    if not pos then return end
    
    local dx = targetX - pos.x
    local dy = targetY - pos.y
    local distance = math.sqrt(dx * dx + dy * dy)
    
    local stopDistance = tolerance
    if not stopDistance then
        -- Check Windfield physics first
        if entity.components.windfield_physics then
            stopDistance = entity.components.windfield_physics.radius or 0
        -- Check legacy physics
        elseif entity.components.physics and entity.components.physics.body then
            local body = entity.components.physics.body
            stopDistance = (body and body.radius) or 0
        else
            stopDistance = 0
        end
    end

    if distance > (stopDistance or 0) then
        local ux = dx / distance
        local uy = dy / distance
        
        -- Handle Windfield physics
        if entity.components.windfield_physics then
            local PhysicsSystem = require("src.systems.physics")
            local manager = PhysicsSystem.getManager()
            if manager then
                local collider = manager:getCollider(entity)
                if collider then
                    local mass = entity.components.windfield_physics.mass or 1
                    local thrustPower = 100000 -- Default thrust power
                    
                    if thrustPower > 0 then
                        local accel = (thrustPower / mass) * dt
                        local vx, vy = collider:getLinearVelocity()
                        
                        local newVx = vx + ux * accel
                        local newVy = vy + uy * accel
                        
                        local maxSpeed = 500 -- Default max speed
                        local newSpeed = math.sqrt(newVx * newVx + newVy * newVy)
                        if newSpeed > maxSpeed then
                            local scale = maxSpeed / newSpeed
                            newVx, newVy = newVx * scale, newVy * scale
                        end
                        
                        collider:setLinearVelocity(newVx, newVy)
                    end
                end
            end
        -- Handle legacy physics
        elseif entity.components.physics and entity.components.physics.body then
            local physics = entity.components.physics
            local body = physics.body
            local thrustPower = body.thrusterPower and body.thrusterPower.main
            local mass = body.mass or 1

            if thrustPower and thrustPower > 0 then
                local accel = (thrustPower / mass) * dt

                local newVx = body.vx + ux * accel
                local newVy = body.vy + uy * accel

                local maxSpeed = body.maxSpeed
                if maxSpeed and maxSpeed > 0 then
                    local newSpeed = math.sqrt(newVx * newVx + newVy * newVy)
                    if newSpeed > maxSpeed then
                        local scale = maxSpeed / newSpeed
                        newVx, newVy = newVx * scale, newVy * scale
                    end
                end

                body.vx = newVx
                body.vy = newVy
            end
        end
    end
end

local function isHealingTurret(turret)
    return turret
        and (turret.kind == "healing_laser" or turret.type == "healing_laser")
end

local function computePatrolRadius(drone)
    local ai = drone.components.ai
    if ai and ai.patrolRadius then
        return ai.patrolRadius
    end

    local body = drone.components.physics and drone.components.physics.body
    if body and body.radius then
        return body.radius * 6
    end

    return 0
end

local function resetPatrol(drone, radius)
    local pos = drone.components.position
    if not pos then
        return
    end

    local angle = math.random() * math.pi * 2
    drone.patrolTarget = {
        x = pos.x + math.cos(angle) * radius,
        y = pos.y + math.sin(angle) * radius,
    }
    drone.patrolTimer = 0
end

local function getPatrolResetInterval(drone)
    local ai = drone.components.ai
    if ai and ai.targetMemory then
        return ai.targetMemory
    end

    return 0
end

local function findInjuredAlly(world, healer, searchRange)
    local healerPos = healer.components.position
    if not (healerPos and searchRange and searchRange > 0) then
        return nil
    end

    local bestTarget
    local bestDistance = math.huge
    local rangeSq = searchRange * searchRange
    local entities = world:get_entities_with_components("hull", "position")

    for _, entity in ipairs(entities) do
        if entity ~= healer and not entity.dead then
            local hull = entity.components.hull
            local pos = entity.components.position

            if hull and pos and hull.hp and hull.maxHP and hull.hp < hull.maxHP then
                local dx = pos.x - healerPos.x
                local dy = pos.y - healerPos.y
                local distSq = dx * dx + dy * dy

                if distSq <= rangeSq and distSq < bestDistance then
                    bestTarget = entity
                    bestDistance = distSq
                end
            end
        end
    end

    if bestTarget and bestDistance then
        return bestTarget, math.sqrt(bestDistance)
    end

    return nil
end

local function findEnemyTarget(world, attacker, searchRange)
    local attackerPos = attacker.components.position
    if not (attackerPos and searchRange and searchRange > 0) then
        return nil
    end

    local bestTarget
    local bestDistance = math.huge
    local rangeSq = searchRange * searchRange
    local entities = world:get_entities_with_components("ai", "position")

    for _, entity in ipairs(entities) do
        if entity ~= attacker and not entity.dead and entity.components and entity.components.ai then
            local pos = entity.components.position
            if pos then
                local dx = pos.x - attackerPos.x
                local dy = pos.y - attackerPos.y
                local distSq = dx * dx + dy * dy

                if distSq <= rangeSq and distSq < bestDistance then
                    bestTarget = entity
                    bestDistance = distSq
                end
            end
        end
    end

    if bestTarget and bestDistance then
        return bestTarget, math.sqrt(bestDistance)
    end

    return nil
end

local function getRoleConfig(drone, role)
    local ai = drone.components.ai
    if not ai then
        return nil
    end

    local behavior = ai.behavior or ai.behaviour or ai.roles
    if type(behavior) == "table" then
        local roleConfig = behavior[role]
        if type(roleConfig) == "table" then
            return roleConfig
        end
    end

    local direct = ai[role]
    if type(direct) == "table" then
        return direct
    end

    return nil
end

local function getMaxTurretRange(drone, predicate)
    local best = 0
    iterateTurrets(drone, function(_, turret)
        if not predicate or predicate(turret) then
            local range = getTurretRange(turret)
            if range > best then
                best = range
            end
        end
    end)
    return best
end

local function updateTurrets(drone, dt, world, target, predicate, shouldFire)
    iterateTurrets(drone, function(_, turret)
        local matches = predicate(turret)
        if matches then
            turret.fireMode = "automatic"
            turret.autoFire = shouldFire
            local locked = not (shouldFire and target)
            TurretSystem.update(turret, dt, target, locked, world)
        else
            turret.autoFire = false
        end
    end)
end

updateHealingBehavior = function(drone, dt, world)
    local healingTurret = findTurret(drone, isHealingTurret)
    if not healingTurret then
        return updateCombatBehavior(drone, dt, world)
    end

    local ai = drone.components.ai
    local roleConfig = getRoleConfig(drone, "healer") or {}

    local searchRange = resolveRange(roleConfig.searchRange, getTurretRange(healingTurret))
    searchRange = resolveRange(searchRange, ai and ai.detectionRange)

    local target, distance = findInjuredAlly(world, drone, searchRange)
    local shouldFire = false

    if target then
        drone.healingTarget = target

        local orbitRadius = resolveRange(roleConfig.orbitRadius, healingTurret.optimal)
        orbitRadius = resolveRange(orbitRadius, searchRange)

        local orbitAngularSpeed = roleConfig.orbitAngularSpeed
        if not orbitAngularSpeed then
            local chaseSpeed = ai and ai.chaseSpeed
            if chaseSpeed and chaseSpeed > 0 and orbitRadius and orbitRadius > 0 then
                orbitAngularSpeed = chaseSpeed / orbitRadius
            else
                orbitAngularSpeed = 0
            end
        end

        local orbitX, orbitY = calculateOrbitPosition(target, drone, orbitRadius, orbitAngularSpeed, dt)
        if orbitX and orbitY then
            moveTowards(drone, orbitX, orbitY, dt, roleConfig.approachTolerance)
        end

        if distance and orbitRadius and orbitRadius > 0 then
            local fireRange = orbitRadius * (roleConfig.fireRangeMultiplier or 1.0)
            shouldFire = distance <= fireRange
        end
    else
        drone.healingTarget = nil

        local patrolRadius = resolveRange(roleConfig.patrolRadius, computePatrolRadius(drone))
        if not drone.patrolTarget and patrolRadius > 0 then
            resetPatrol(drone, patrolRadius)
        end

        drone.patrolTimer = (drone.patrolTimer or 0) + dt
        local resetInterval = resolveRange(roleConfig.patrolResetInterval, getPatrolResetInterval(drone))
        if resetInterval > 0 and drone.patrolTimer >= resetInterval then
            drone.patrolTarget = nil
        end

        if drone.patrolTarget then
            moveTowards(drone, drone.patrolTarget.x, drone.patrolTarget.y, dt, roleConfig.approachTolerance)
        end
    end

    local fireTarget = shouldFire and drone.healingTarget or nil
    updateTurrets(drone, dt, world, fireTarget, isHealingTurret, shouldFire)
end

-- Combat behavior (for weapon equipped drones)
updateCombatBehavior = function(drone, dt, world)
    local ai = drone.components.ai
    local roleConfig = getRoleConfig(drone, "combat") or {}

    local weaponRange = getMaxTurretRange(drone, function(turret)
        return not isHealingTurret(turret)
    end)

    local detection = resolveRange(roleConfig.searchRange, weaponRange)
    detection = resolveRange(detection, ai and ai.detectionRange)

    local target, distance = findEnemyTarget(world, drone, detection)
    local shouldFire = false

    if target then
        drone.combatTarget = target

        local engagementRange = resolveRange(roleConfig.engagementRange, ai and ai.attackRange)
        engagementRange = resolveRange(engagementRange, weaponRange)

        if engagementRange > 0 and distance then
            if distance > engagementRange then
                local pos = target.components.position
                moveTowards(drone, pos.x, pos.y, dt, roleConfig.approachTolerance)
            end
            shouldFire = distance <= engagementRange
        else
            local pos = target.components.position
            moveTowards(drone, pos.x, pos.y, dt, roleConfig.approachTolerance)
            shouldFire = true
        end
    else
        drone.combatTarget = nil

        local patrolRadius = resolveRange(roleConfig.patrolRadius, computePatrolRadius(drone))
        if not drone.patrolTarget and patrolRadius > 0 then
            resetPatrol(drone, patrolRadius)
        end

        drone.patrolTimer = (drone.patrolTimer or 0) + dt
        local resetInterval = resolveRange(roleConfig.patrolResetInterval, getPatrolResetInterval(drone))
        if resetInterval > 0 and drone.patrolTimer >= resetInterval then
            drone.patrolTarget = nil
        end

        if drone.patrolTarget then
            moveTowards(drone, drone.patrolTarget.x, drone.patrolTarget.y, dt, roleConfig.approachTolerance)
        end
    end

    local fireTarget = shouldFire and drone.combatTarget or nil
    updateTurrets(drone, dt, world, fireTarget, function(turret)
        return not isHealingTurret(turret)
    end, shouldFire)
end

-- Main update function - determines behavior based on weapon modules
function ModularDroneAI.update(drone, dt, world)
    if not drone.components.position or drone.dead then
        return
    end
    
    local ai = drone.components.ai
    if not ai then return end
    
    if findTurret(drone, isHealingTurret) then
        updateHealingBehavior(drone, dt, world)
        return
    end

    updateCombatBehavior(drone, dt, world)
end

return ModularDroneAI
