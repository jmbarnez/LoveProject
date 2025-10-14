-- Simple Turret AI Component
-- A straightforward turret AI that scans for enemies and fires at them

local SimpleTurretAI = {}
SimpleTurretAI.__index = SimpleTurretAI

function SimpleTurretAI.new(config)
    local self = setmetatable({}, SimpleTurretAI)
    
    -- Configuration
    self.scanRange = config.scanRange or 600
    if config.fireRange == nil then
        self.fireRange = 500
    else
        self.fireRange = config.fireRange
    end
    self.turnSpeed = config.turnSpeed or 3.0
    self.scanInterval = config.scanInterval or 0.2 -- Scan every 200ms
    self.lastScanTime = 0
    
    -- State
    self.currentTarget = nil
    self.currentAngle = 0
    self.desiredAngle = 0
    self.isAimed = false
    self.aimTolerance = math.rad(10) -- 10 degrees tolerance
    
    -- Scanning behavior
    self.scanAngle = 0 -- Current scanning angle
    self.scanSpeed = 0.5 -- Radians per second when scanning
    self.scanDirection = 1 -- 1 or -1 for scanning direction
    self.currentDistance = math.huge
    
    return self
end

function SimpleTurretAI:update(dt, entity, world, player)
    if not entity or not entity.components or not entity.components.position then
        return
    end
    
    local pos = entity.components.position
    self.currentAngle = pos.angle or 0
    
    -- Periodic scanning for targets
    self.lastScanTime = self.lastScanTime + dt
    if self.lastScanTime >= self.scanInterval then
        self:scanForTargets(world, pos, player, entity)
        self.lastScanTime = 0
    end
    
    -- Update targeting and aiming
    if self.currentTarget then
        self:updateTargeting(dt, entity, world)
        self:updateRotation(dt, entity)
    else
        -- No target - do slow scanning rotation
        self:updateScanning(dt, entity)
    end
end

function SimpleTurretAI:scanForTargets(world, turretPos, player, owner)
    if not world or not world.get_entities_with_components then 
        return 
    end
    
    local bestTarget = nil
    local bestDistance = math.huge
    
    -- Look for enemy entities (those with AI component and isEnemy flag)
    local entities = world:get_entities_with_components("ai", "position")
    
    for _, entity in ipairs(entities or {}) do
        -- Skip self, player, and other turrets
        if entity ~= owner and entity ~= player and entity.aiType ~= "turret" and not entity.isTurret then
            -- Check if this is an enemy
            if entity.isEnemy and entity.components and entity.components.position then
                local enemyPos = entity.components.position
                local distance = self:getDistance(turretPos, enemyPos)
                
                if distance <= self.scanRange and distance < bestDistance then
                    bestTarget = entity
                    bestDistance = distance
                end
            end
        end
    end
    
    -- Update target
    if bestTarget then
        self.currentTarget = bestTarget
    elseif self.currentTarget then
        -- Check if current target is still valid
        if not self.currentTarget.components or not self.currentTarget.components.position or self.currentTarget.dead then
            self.currentTarget = nil
        else
            local distance = self:getDistance(turretPos, self.currentTarget.components.position)
            if distance > self.scanRange then
                self.currentTarget = nil
            end
        end
    end
end

function SimpleTurretAI:updateTargeting(dt, entity, world)
    if not self.currentTarget or not self.currentTarget.components or not self.currentTarget.components.position then
        self.currentTarget = nil
        self.currentDistance = math.huge
        return
    end
    
    local targetPos = self.currentTarget.components.position
    local turretPos = entity.components.position
    
    -- Calculate desired angle to target
    self.desiredAngle = math.atan2(targetPos.y - turretPos.y, targetPos.x - turretPos.x)
    
    -- Check if aimed
    local angleDiff = math.abs(self:normalizeAngle(self.desiredAngle - self.currentAngle))
    self.isAimed = angleDiff <= self.aimTolerance
    
    -- Check if in range
    local distance = self:getDistance(turretPos, targetPos)
    local inRange = (not self.fireRange) or (distance <= self.fireRange)
    self.currentDistance = distance
    
    -- Update turret state for firing system
    if entity.components.ai then
        entity.components.ai.turretState = {
            hasTarget = true,
            isAimed = self.isAimed,
            inRange = inRange,
            distance = distance,
            targetPosition = {x = targetPos.x, y = targetPos.y}
        }
    end
end

function SimpleTurretAI:updateScanning(dt, entity)
    -- Slow scanning rotation when no target
    self.scanAngle = self.scanAngle + self.scanSpeed * self.scanDirection * dt
    self.currentDistance = math.huge
    
    -- Reverse direction when reaching limits (180 degrees each way)
    if self.scanAngle > math.pi then
        self.scanAngle = math.pi
        self.scanDirection = -1
    elseif self.scanAngle < -math.pi then
        self.scanAngle = -math.pi
        self.scanDirection = 1
    end
    
    -- Update entity rotation to scanning angle
    if entity.components.position then
        entity.components.position.angle = self.scanAngle
        self.currentAngle = self.scanAngle
    end
end

function SimpleTurretAI:updateRotation(dt, entity)
    if not self.currentTarget then 
        return 
    end
    
    -- Smooth rotation towards desired angle
    local angleDiff = self:normalizeAngle(self.desiredAngle - self.currentAngle)
    local maxTurn = self.turnSpeed * dt
    
    if math.abs(angleDiff) <= maxTurn then
        self.currentAngle = self.desiredAngle
    else
        local sign = angleDiff > 0 and 1 or -1
        self.currentAngle = self.currentAngle + sign * maxTurn
    end
    
    -- Update entity rotation
    if entity.components.position then
        entity.components.position.angle = self.currentAngle
    end
end

function SimpleTurretAI:getDistance(pos1, pos2)
    local dx = pos2.x - pos1.x
    local dy = pos2.y - pos1.y
    return math.sqrt(dx * dx + dy * dy)
end

function SimpleTurretAI:normalizeAngle(angle)
    while angle > math.pi do angle = angle - 2 * math.pi end
    while angle < -math.pi do angle = angle + 2 * math.pi end
    return angle
end

function SimpleTurretAI:getCurrentTarget()
    return self.currentTarget
end

function SimpleTurretAI:canFire()
    if not (self.currentTarget and self.isAimed) then
        return false
    end

    if not self.fireRange then
        return true
    end

    return (self.currentDistance or math.huge) <= self.fireRange
end

function SimpleTurretAI:getDistanceToTarget()
    return self.currentDistance or math.huge
end

return SimpleTurretAI
