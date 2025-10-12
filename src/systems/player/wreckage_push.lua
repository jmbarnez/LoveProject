-- Player Wreckage Push System
-- Handles continuous pushing of nearby wreckage pieces
-- Extracted from main PlayerSystem.update()

local PlayerDebug = require("src.systems.player.debug")

local WreckagePushSystem = {}

-- Process wreckage pushing when player is moving
function WreckagePushSystem.processWreckagePush(player, body, inputs, world, dt)
    local ppos = player.components.position
    local isMoving = inputs.w or inputs.s or inputs.a or inputs.d
    
    if not body or not isMoving then
        return
    end
    
    local playerX, playerY = ppos.x, ppos.y
    local playerVx, playerVy = body.vx, body.vy
    local playerSpeed = math.sqrt(playerVx * playerVx + playerVy * playerVy)
    
    -- Only apply continuous pushing if player is moving
    if playerSpeed <= 0.5 then
        return
    end
    
    -- Get all entities with wreckage components
    local wreckageEntities = world:get_entities_with_components("wreckage", "position", "physics")
    local pushCount = 0
    
    for _, wreckage in ipairs(wreckageEntities) do
        if WreckagePushSystem.shouldPushWreckage(wreckage, playerX, playerY) then
            WreckagePushSystem.pushWreckage(wreckage, playerX, playerY, playerSpeed, dt)
            pushCount = pushCount + 1
        end
    end
    
    PlayerDebug.logWreckagePush(#wreckageEntities, playerSpeed, pushCount)
end

-- Check if wreckage should be pushed
function WreckagePushSystem.shouldPushWreckage(wreckage, playerX, playerY)
    if not wreckage or wreckage.dead then
        return false
    end
    
    if not wreckage.components.physics or not wreckage.components.physics.body then
        return false
    end
    
    if not wreckage.components.position then
        return false
    end
    
    -- Calculate distance to wreckage
    local dx = wreckage.components.position.x - playerX
    local dy = wreckage.components.position.y - playerY
    local distance = math.sqrt(dx * dx + dy * dy)
    
    -- Apply continuous pushing within a reasonable range
    return distance > 0 and distance < 100
end

-- Push a single wreckage piece
function WreckagePushSystem.pushWreckage(wreckage, playerX, playerY, playerSpeed, dt)
    local wreckagePos = wreckage.components.position
    local wreckageBody = wreckage.components.physics.body
    
    -- Calculate distance to wreckage
    local dx = wreckagePos.x - playerX
    local dy = wreckagePos.y - playerY
    local distance = math.sqrt(dx * dx + dy * dy)
    
    if distance <= 0 then return end
    
    -- Calculate push force based on distance and player movement
    local pushStrength = 0.3 -- Base push strength
    local distanceFactor = math.max(0.1, 1.0 - (distance / 100.0)) -- Closer = stronger push
    local speedFactor = math.min(1.0, playerSpeed / 100.0) -- Faster = stronger push
    
    -- Calculate push direction (away from player)
    local pushX = dx / distance
    local pushY = dy / distance
    
    -- Apply continuous force to wreckage
    local force = pushStrength * distanceFactor * speedFactor
    wreckageBody.vx = (wreckageBody.vx or 0) + pushX * force * dt
    wreckageBody.vy = (wreckageBody.vy or 0) + pushY * force * dt
end

-- Get push strength for a given distance and speed
function WreckagePushSystem.calculatePushStrength(distance, playerSpeed, baseStrength)
    baseStrength = baseStrength or 0.3
    local distanceFactor = math.max(0.1, 1.0 - (distance / 100.0))
    local speedFactor = math.min(1.0, playerSpeed / 100.0)
    return baseStrength * distanceFactor * speedFactor
end

-- Get push direction vector
function WreckagePushSystem.getPushDirection(wreckageX, wreckageY, playerX, playerY)
    local dx = wreckageX - playerX
    local dy = wreckageY - playerY
    local distance = math.sqrt(dx * dx + dy * dy)
    
    if distance <= 0 then
        return 0, 0
    end
    
    return dx / distance, dy / distance
end

-- Check if player is moving fast enough to push wreckage
function WreckagePushSystem.isPlayerMovingFastEnough(playerSpeed, minSpeed)
    minSpeed = minSpeed or 0.5
    return playerSpeed > minSpeed
end

-- Get wreckage within push range
function WreckagePushSystem.getWreckageInRange(world, playerX, playerY, maxRange)
    maxRange = maxRange or 100
    local wreckageEntities = world:get_entities_with_components("wreckage", "position", "physics")
    local inRange = {}
    
    for _, wreckage in ipairs(wreckageEntities) do
        if wreckage and not wreckage.dead and wreckage.components.position then
            local dx = wreckage.components.position.x - playerX
            local dy = wreckage.components.position.y - playerY
            local distance = math.sqrt(dx * dx + dy * dy)
            
            if distance <= maxRange then
                table.insert(inRange, wreckage)
            end
        end
    end
    
    return inRange
end

-- Apply push force to wreckage
function WreckagePushSystem.applyPushForce(wreckageBody, pushX, pushY, force, dt)
    wreckageBody.vx = (wreckageBody.vx or 0) + pushX * force * dt
    wreckageBody.vy = (wreckageBody.vy or 0) + pushY * force * dt
end

-- Get push range
function WreckagePushSystem.getPushRange()
    return 100
end

-- Get base push strength
function WreckagePushSystem.getBasePushStrength()
    return 0.3
end

-- Get minimum player speed for pushing
function WreckagePushSystem.getMinPlayerSpeed()
    return 0.5
end

return WreckagePushSystem
