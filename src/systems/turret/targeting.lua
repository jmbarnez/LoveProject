local CollisionHelpers = require("src.systems.turret.collision_helpers")

local Targeting = {}

-- Calculate lead time for intercepting moving targets
function Targeting.calculateInterceptPoint(shooterX, shooterY, targetX, targetY, targetVelX, targetVelY, projectileSpeed)
    if not projectileSpeed or projectileSpeed <= 0 then
        return targetX, targetY -- No lead for hitscan or invalid speed
    end

    local dx = targetX - shooterX
    local dy = targetY - shooterY

    -- Solve quadratic equation for intercept time
    local a = targetVelX * targetVelX + targetVelY * targetVelY - projectileSpeed * projectileSpeed
    local b = 2 * (dx * targetVelX + dy * targetVelY)
    local c = dx * dx + dy * dy

    local discriminant = b * b - 4 * a * c

    if discriminant < 0 then
        return targetX, targetY -- No intercept possible, aim at current position
    end

    local t1 = (-b - math.sqrt(discriminant)) / (2 * a)
    local t2 = (-b + math.sqrt(discriminant)) / (2 * a)

    -- Use the positive, smaller time
    local t = (t1 > 0 and t1) or (t2 > 0 and t2) or 0

    -- Return predicted position
    return targetX + targetVelX * t, targetY + targetVelY * t
end

-- Check if target is within turret's effective range and arc
function Targeting.canEngageTarget(turret, target, distance)
    if not target or not target.components or not target.components.position then
        return false
    end

    -- Check maximum range
    if turret.maxRange and distance > turret.maxRange then
        return false
    end

    -- Check if target is within turret's arc (if specified)
    if turret.firingArc then
        local ownerAngle = turret.owner.components.position.angle or 0
        local targetAngle = math.atan2(
            target.components.position.y - turret.owner.components.position.y,
            target.components.position.x - turret.owner.components.position.x
        )
        local angleDiff = math.abs(targetAngle - ownerAngle)

        -- Normalize angle difference to [0, π]
        if angleDiff > math.pi then
            angleDiff = 2 * math.pi - angleDiff
        end

        if angleDiff > turret.firingArc / 2 then
            return false
        end
    end

    return true
end

-- Get best target from available options
function Targeting.selectBestTarget(turret, candidates)
    if not candidates or #candidates == 0 then
        return nil
    end

    local ownerX = turret.owner.components.position.x
    local ownerY = turret.owner.components.position.y
    local bestTarget = nil
    local bestScore = -1

    for _, candidate in ipairs(candidates) do
        if candidate.components and candidate.components.position then
            local dx = candidate.components.position.x - ownerX
            local dy = candidate.components.position.y - ownerY
            local distance = math.sqrt(dx * dx + dy * dy)

            if Targeting.canEngageTarget(turret, candidate, distance) then
                -- Scoring factors: closer is better, priority targets get bonus
                local score = 1000 / (1 + distance) -- Distance factor

                -- Bonus for different target types
                if candidate.isEnemy then
                    score = score + 100
                end
                if candidate.components and candidate.components.mineable and turret.kind == "mining_laser" then
                    score = score + 200 -- Mining lasers prefer asteroids
                end
                if candidate.components and candidate.components.wreckage and turret.kind == "salvaging_laser" then
                    score = score + 200 -- Salvaging lasers prefer wrecks
                end

                if score > bestScore then
                    bestScore = score
                    bestTarget = candidate
                end
            end
        end
    end

    return bestTarget
end

-- Check line of sight to target (basic version)
function Targeting.hasLineOfSight(turret, target, world)
    if not target or not target.components or not target.components.position then
        return false
    end

    local ownerX = turret.owner.components.position.x
    local ownerY = turret.owner.components.position.y
    local targetX = target.components.position.x
    local targetY = target.components.position.y

    -- For now, assume clear line of sight
    -- TODO: Implement obstacle checking using world collision detection
    return true
end

-- Calculate optimal firing angle considering spread and target movement
function Targeting.calculateFiringAngle(turret, target)
    if not target or not target.components or not target.components.position then
        return turret.owner.components.position.angle or 0
    end

    local ownerX = turret.owner.components.position.x
    local ownerY = turret.owner.components.position.y
    local targetX = target.components.position.x
    local targetY = target.components.position.y

    -- Get target velocity for lead calculation
    local targetVelX = 0
    local targetVelY = 0
    if target.components.physics and target.components.physics.body then
        targetVelX = target.components.physics.body.vx or 0
        targetVelY = target.components.physics.body.vy or 0
    elseif target.components.velocity then
        targetVelX = target.components.velocity.x or 0
        targetVelY = target.components.velocity.y or 0
    end

    -- Calculate intercept point
    local projectileSpeed = turret.projectileSpeed or 1000
    local interceptX, interceptY = Targeting.calculateInterceptPoint(
        ownerX, ownerY, targetX, targetY, targetVelX, targetVelY, projectileSpeed
    )

    -- Calculate angle to intercept point
    return math.atan2(interceptY - ownerY, interceptX - ownerX)
end

-- Check if target is valid for this turret type
function Targeting.isValidTarget(turret, target)
    if not target or target.dead or not target.components then
        return false
    end

    -- Mining lasers only target mineable objects
    if turret.kind == "mining_laser" then
        return target.components.mineable ~= nil
    end

    -- Salvaging lasers only target wreckage
    if turret.kind == "salvaging_laser" then
        return target.components.wreckage ~= nil or (target.salvageAmount and target.salvageAmount > 0)
    end

    -- Combat weapons target enemies or other collidable objects
    return target.components.collidable ~= nil
end

return Targeting