-- AI Component Module
-- Provides AI functionality for entities and turrets

local AI = {}
AI.__index = AI

-- Simple AI configuration - no complex intelligence levels
AI.BASIC_CONFIG = {
    detectionRange = 2000,   -- Detection range for all enemies
    chaseSpeed = 150,        -- Speed when actively chasing
    patrolSpeed = 60,        -- Speed when patrolling
    retreatHealthPercent = 0.25,  -- Retreat when health drops below 25%
    reactionTime = 0.5,      -- Time before reacting to damage
}

function AI.new(args)
    local ai = {}
    setmetatable(ai, AI)

    -- Simple basic configuration
    local config = AI.BASIC_CONFIG
    ai.detectionRange = (args and args.detectionRange) or config.detectionRange
    ai.chaseSpeed = config.chaseSpeed
    ai.patrolSpeed = config.patrolSpeed
    ai.retreatHealthPercent = config.retreatHealthPercent
    ai.reactionTime = config.reactionTime

    -- Basic AI state
    ai.state = "patrolling"  -- Start patrolling
    ai.target = nil
    ai.isHunting = false  -- Simple flag instead of complex states

    -- Store spawn position for patrolling
    ai.spawnPos = args.spawnPos or {x = 0, y = 0}
    ai.patrolCenter = args.patrolCenter or ai.spawnPos

    -- Simple patrol behavior
    ai.patrolAngle = math.random() * math.pi * 2
    ai.patrolTimer = 0
    ai.patrolDirection = 1

    -- Damage response
    ai.damagedByPlayer = false
    ai.lastDamageTime = 0

    return ai
end

-- Simple helper functions for basic AI
function AI:shouldReact(dt)
    return (love.timer.getTime() - (self.lastDamageTime or 0)) >= self.reactionTime
end

function AI:isPlayerInRange(playerPos, entityPos)
    local dx = playerPos.x - entityPos.x
    local dy = playerPos.y - entityPos.y
    local distance = math.sqrt(dx * dx + dy * dy)
    return distance <= self.detectionRange
end

-- =============================================================================
-- TURRET AI COMPONENT - Specialized AI for stationary turrets
-- =============================================================================

local TurretAI = {}
TurretAI.__index = TurretAI

-- Turret AI configuration
TurretAI.DEFAULT_CONFIG = {
    scanRange = 800,        -- How far the turret can detect targets
    fireRange = 600,        -- Maximum firing range
    scanAngle = math.pi,    -- 180 degrees scan arc (facing forward)
    turnSpeed = 2.0,        -- Radians per second turning speed
    reacquireTime = 1.0,    -- Time to reacquire target after losing it
    targetTypes = {"enemy", "hostile"}, -- What types of entities to target
    fireMode = "automatic", -- "automatic" or "manual"
    autoFire = true         -- Whether to fire automatically when target acquired
}

function TurretAI.new(args)
    local ai = {}
    setmetatable(ai, TurretAI)

    -- Merge with defaults
    local config = TurretAI.DEFAULT_CONFIG
    for k, v in pairs(config) do
        ai[k] = (args and args[k]) or v
    end

    -- Turret AI state
    ai.currentTarget = nil
    ai.targetLastSeen = 0
    ai.targetLostTime = 0
    ai.isAcquiringTarget = false
    ai.lastScanTime = 0
    ai.scanInterval = 0.1 -- Scan every 100ms

    -- Turret aiming
    ai.desiredAngle = 0
    ai.currentAngle = 0
    ai.isAimed = false
    ai.aimTolerance = math.rad(5) -- 5 degrees tolerance

    -- Target tracking
    ai.targetPosition = nil
    ai.targetVelocity = {x = 0, y = 0}
    ai.lastTargetPos = nil
    ai.targetUpdateTime = 0

    return ai
end

function TurretAI:update(dt, entity, world, player)
    if not entity or not entity.components then return end

    local pos = entity.components.position
    if not pos then return end

    -- Periodic scanning for targets
    self.lastScanTime = self.lastScanTime + dt
    if self.lastScanTime >= self.scanInterval then
        self:scanForTargets(world, pos, player)
        self.lastScanTime = 0
    end

    -- Update target tracking and aiming
    self:updateTargeting(dt, entity, world)

    -- Update turret rotation towards target
    self:updateRotation(dt, entity)
end

function TurretAI:scanForTargets(world, turretPos, player)
    if not world or not world.get_entities_with_components then return end

    local bestTarget = nil
    local bestDistance = math.huge
    local bestPriority = -1

    -- Get potential targets (enemies)
    local enemies = world:get_entities_with_components("ai", "position")

    for _, enemy in ipairs(enemies or {}) do
        if enemy ~= player and enemy.components.ai and enemy.components.position then
            local enemyPos = enemy.components.position
            local distance = self:getDistance(turretPos, enemyPos)

            -- Check if enemy is within scan range
            if distance <= self.scanRange then
                -- Check if enemy is within scan angle (facing direction)
                local angleToEnemy = self:getAngleToTarget(turretPos, enemyPos)
                local angleDiff = math.abs(self:normalizeAngle(angleToEnemy - self.currentAngle))

                if angleDiff <= (self.scanAngle / 2) then
                    -- Prioritize closer targets
                    local priority = 1000 - distance -- Closer = higher priority

                    if priority > bestPriority then
                        bestTarget = enemy
                        bestDistance = distance
                        bestPriority = priority
                    end
                end
            end
        end
    end

    -- Update target acquisition
    if bestTarget then
        self:acquireTarget(bestTarget)
    elseif self.currentTarget then
        -- Check if current target is still valid
        local targetPos = self.currentTarget.components.position
        if targetPos then
            local distance = self:getDistance(turretPos, targetPos)
            if distance > self.scanRange * 1.5 then -- Give some grace distance
                self:loseTarget()
            end
        else
            self:loseTarget()
        end
    end
end

function TurretAI:acquireTarget(target)
    if self.currentTarget ~= target then
        self.currentTarget = target
        self.targetLastSeen = love.timer.getTime()
        self.isAcquiringTarget = true
        -- Log target acquisition if needed
    end
end

function TurretAI:loseTarget()
    if self.currentTarget then
        self.currentTarget = nil
        self.targetLostTime = love.timer.getTime()
        self.targetPosition = nil
        self.isAcquiringTarget = false
        self.isAimed = false
        -- Could add target lost logic here
    end
end

function TurretAI:updateTargeting(dt, entity, world)
    if not self.currentTarget then
        self.isAimed = false
        return
    end

    local targetPos = self.currentTarget.components.position
    if not targetPos then
        self:loseTarget()
        return
    end

    -- Update target position tracking for leading shots if needed
    local currentTime = love.timer.getTime()
    if self.lastTargetPos then
        local timeDiff = currentTime - self.targetUpdateTime
        if timeDiff > 0 then
            self.targetVelocity.x = (targetPos.x - self.lastTargetPos.x) / timeDiff
            self.targetVelocity.y = (targetPos.y - self.lastTargetPos.y) / timeDiff
        end
    end

    self.targetPosition = {x = targetPos.x, y = targetPos.y}
    self.lastTargetPos = {x = targetPos.x, y = targetPos.y}
    self.targetUpdateTime = currentTime
    self.targetLastSeen = currentTime

    -- Calculate desired aim angle
    local turretPos = entity.components.position
    self.desiredAngle = self:getAngleToTarget(turretPos, targetPos)

    -- Check if turret is aimed at target
    local angleDiff = math.abs(self:normalizeAngle(self.desiredAngle - self.currentAngle))
    self.isAimed = angleDiff <= self.aimTolerance

    -- Check if target is in firing range
    local distance = self:getDistance(turretPos, targetPos)
    local inRange = distance <= self.fireRange

    -- Update turret state for firing system
    if entity.components.ai then
        entity.components.ai.turretState = {
            hasTarget = true,
            isAimed = self.isAimed,
            inRange = inRange,
            targetPosition = self.targetPosition,
            targetVelocity = self.targetVelocity
        }
    end
end

function TurretAI:updateRotation(dt, entity)
    if not self.currentTarget then return end

    -- Smooth rotation towards desired angle
    local angleDiff = self:normalizeAngle(self.desiredAngle - self.currentAngle)
    local maxTurn = self.turnSpeed * dt

    if math.abs(angleDiff) <= maxTurn then
        self.currentAngle = self.desiredAngle
    else
        -- Use custom sign function since math.sign doesn't exist in standard Lua
        local sign = angleDiff > 0 and 1 or -1
        self.currentAngle = self.currentAngle + sign * maxTurn
    end

    -- Update entity rotation if it has one
    if entity.components.position then
        entity.components.position.angle = self.currentAngle
    end
end

-- Utility functions
function TurretAI:getDistance(pos1, pos2)
    local dx = pos2.x - pos1.x
    local dy = pos2.y - pos1.y
    return math.sqrt(dx * dx + dy * dy)
end

function TurretAI:getAngleToTarget(fromPos, toPos)
    return math.atan2(toPos.y - fromPos.y, toPos.x - fromPos.x)
end

function TurretAI:normalizeAngle(angle)
    while angle > math.pi do angle = angle - 2 * math.pi end
    while angle < -math.pi do angle = angle + 2 * math.pi end
    return angle
end

-- Query functions for external systems
function TurretAI:hasTarget()
    return self.currentTarget ~= nil
end

function TurretAI:canFire()
    return self:hasTarget() and self.isAimed and self:getDistanceToTarget() <= self.fireRange
end

function TurretAI:getDistanceToTarget()
    if not self.currentTarget or not self.targetPosition then return math.huge end
    return self:getDistance({x = 0, y = 0}, self.targetPosition) -- Would need turret position
end

function TurretAI:getTargetPosition()
    return self.targetPosition
end

function TurretAI:getCurrentAngle()
    return self.currentAngle
end

return AI, TurretAI