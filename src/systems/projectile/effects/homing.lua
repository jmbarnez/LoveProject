local EffectRegistry = require("src.systems.projectile.effect_registry")
local Events = require("src.systems.projectile.event_dispatcher").EVENTS
local TargetUtils = require("src.core.target_utils")

local function clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function isTargetValid(target, projectile)
    if not target or target.dead or not target.components or not target.components.position then
        return false
    end

    local projectileComponent = projectile.components and projectile.components.projectile
    local source = bulletComponent and bulletComponent.source
    return TargetUtils.isEnemyTarget(target, source)
end

local function findNearestTarget(projectile, world, maxRangeSq)
    if not world or not world.get_entities_with_components then
        return nil
    end

    local pos = projectile.components and projectile.components.position
    if not pos then
        return nil
    end

    local projectileComponent = projectile.components and projectile.components.projectile
    local source = bulletComponent and bulletComponent.source

    local nearest
    local nearestDistSq = math.huge
    local entities = world:get_entities_with_components("position")

    for _, entity in ipairs(entities) do
        if entity ~= source and not entity.dead and entity.components and entity.components.position then
            if TargetUtils.isEnemyTarget(entity, source) then
                local epos = entity.components.position
                local dx = epos.x - pos.x
                local dy = epos.y - pos.y
                local distSq = dx * dx + dy * dy
                if (not maxRangeSq or distSq <= maxRangeSq) and distSq < nearestDistSq then
                    nearest = entity
                    nearestDistSq = distSq
                end
            end
        end
    end

    if nearest and not isTargetValid(nearest, projectile) then
        return nil
    end

    return nearest
end

local function factory(context, config)
    local projectile = context.projectile
    local world = config.world
    local turnRate = config.turnRate or math.rad(270)
    local reacquireDelay = config.reacquireDelay or 0.1
    if reacquireDelay < 0 then
        reacquireDelay = 0
    end
    local desiredSpeed = config.speed
    local maintainNearest = config.retargetNearest ~= false

    local maxRangeSq = nil
    if config.maxRange and config.maxRange > 0 then
        maxRangeSq = config.maxRange * config.maxRange
    end

    local currentTarget = config.target
    local reacquireTimer = 0

    local function acquire(forceNearest)
        -- Only check if current target is still valid
        -- No nearest target acquisition - missile only targets locked enemy
        if currentTarget and not isTargetValid(currentTarget, projectile) then
            currentTarget = nil
        end
    end

    local function steer(dt)
        local position = projectile.components and projectile.components.position
        -- Get velocity from Windfield physics
        local PhysicsSystem = require("src.systems.physics")
        local physicsManager = PhysicsSystem.getManager()
        if not physicsManager then
            return
        end
        
        local vx, vy = physicsManager:getVelocity(projectile)
        local velocity = { x = vx, y = vy }
        if not position or not velocity then
            return
        end

        -- If no target or target is invalid, maintain current velocity (fly straight)
        if not currentTarget or not isTargetValid(currentTarget, projectile) then
            -- Just maintain current speed and direction
            local speed = math.sqrt((velocity.x or 0) * (velocity.x or 0) + (velocity.y or 0) * (velocity.y or 0))
            if desiredSpeed and desiredSpeed > 0 then
                speed = desiredSpeed
            elseif speed <= 0 then
                speed = 1
            end
            
            local currentAngle = math.atan2(velocity.y or 0, velocity.x or 0)
            local newVx = math.cos(currentAngle) * speed
            local newVy = math.sin(currentAngle) * speed
            physicsManager:setVelocity(projectile, newVx, newVy)
            position.angle = currentAngle
            return
        end

        local targetPos = currentTarget.components.position
        if not targetPos then
            return
        end

        local desiredAngle = math.atan2(targetPos.y - position.y, targetPos.x - position.x)
        local currentAngle = math.atan2(velocity.y or 0, velocity.x or 0)
        local maxTurn = turnRate * dt
        local diff = math.atan2(math.sin(desiredAngle - currentAngle), math.cos(desiredAngle - currentAngle))
        local clamped = clamp(diff, -maxTurn, maxTurn)
        local newAngle = currentAngle + clamped

        local speed = math.sqrt((velocity.x or 0) * (velocity.x or 0) + (velocity.y or 0) * (velocity.y or 0))
        if desiredSpeed and desiredSpeed > 0 then
            speed = desiredSpeed
        elseif speed <= 0 then
            speed = 1
        end

        -- Update velocity through Windfield physics
        local newVx = math.cos(newAngle) * speed
        local newVy = math.sin(newAngle) * speed
        physicsManager:setVelocity(projectile, newVx, newVy)
        position.angle = newAngle
    end

    local events = {}

    events[Events.SPAWN] = function()
        reacquireTimer = reacquireDelay
        if not isTargetValid(currentTarget, projectile) then
            currentTarget = nil
        end
        acquire(true)
    end

    events[Events.UPDATE] = function(payload)
        local dt = (payload and payload.dt) or 0
        if dt < 0 then
            dt = 0
        end

        reacquireTimer = reacquireTimer - dt
        if reacquireTimer <= 0 then
            reacquireTimer = reacquireDelay
            acquire(true)
        else
            acquire(false)
        end

        steer(math.max(dt, 0.0001))
    end

    events[Events.HIT] = function()
        currentTarget = nil
    end

    events[Events.EXPIRE] = function()
        currentTarget = nil
    end

    return {
        events = events,
    }
end

EffectRegistry.register("homing", factory)

return true
