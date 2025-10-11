local BehaviorRegistry = require("src.systems.projectile.behavior_registry")
local ProjectileEvents = require("src.systems.projectile.event_dispatcher").EVENTS
local TargetUtils = require("src.core.target_utils")

local function clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function is_target_valid(target)
    return target and not target.dead and target.components and target.components.position
end

local function vector_length(x, y)
    return math.sqrt((x or 0) * (x or 0) + (y or 0) * (y or 0))
end

local function acquire_target(projectile, world, maxRangeSq, preferNearest)
    if not world or not world.get_entities_with_components then
        return nil
    end

    local pos = projectile.components and projectile.components.position
    if not pos then
        return nil
    end

    local bulletComponent = projectile.components and projectile.components.bullet
    local source = bulletComponent and bulletComponent.source

    local bestTarget
    local bestScore = math.huge
    local entities = world:get_entities_with_components("position")

    for _, entity in ipairs(entities) do
        if entity ~= projectile and entity ~= source and TargetUtils.isEnemyTarget(entity, source) and is_target_valid(entity) then
            local epos = entity.components.position
            local dx = epos.x - pos.x
            local dy = epos.y - pos.y
            local distSq = dx * dx + dy * dy
            if not maxRangeSq or distSq <= maxRangeSq then
                local score = preferNearest and distSq or (distSq * 0.9)
                if score < bestScore then
                    bestScore = score
                    bestTarget = entity
                end
            end
        end
    end

    if bestTarget and not is_target_valid(bestTarget) then
        return nil
    end

    return bestTarget
end

local function factory(context, config)
    local projectile = context.projectile
    local turnRate = config.turnRate or math.rad(240)
    local maxRangeSq = nil
    if config.range and config.range > 0 then
        maxRangeSq = config.range * config.range
    elseif config.maxRange and config.maxRange > 0 then
        maxRangeSq = config.maxRange * config.maxRange
    end

    local state = {
        currentTarget = config.target,
        reacquireDelay = math.max(0.05, config.reacquireDelay or 0.15),
        reacquireTimer = 0,
        maintainNearest = config.retargetNearest ~= false,
        desiredSpeed = config.speed,
        hasSpecificTarget = config.target ~= nil, -- Track if we were given a specific target
    }

    local function update_target(world, forceNearest)
        -- Only check if current target is still valid
        -- No nearest target acquisition - missile only targets locked enemy
        if state.currentTarget and not is_target_valid(state.currentTarget) then
            state.currentTarget = nil
        end
    end

    local function steer(dt, world)
        local position = projectile.components and projectile.components.position
        local velocity = projectile.components and projectile.components.velocity
        if not position or not velocity then
            return
        end

        -- If no target or target is invalid, maintain current velocity (fly straight)
        if not state.currentTarget or not is_target_valid(state.currentTarget) then
            -- Just maintain current speed and direction
            local speed = vector_length(velocity.x, velocity.y)
            if state.desiredSpeed and state.desiredSpeed > 0 then
                speed = state.desiredSpeed
            elseif speed <= 0 then
                local physics = projectile.components.physics
                local baseSpeed = (physics and physics.speed) or 700
                speed = baseSpeed
            end
            
            local currentAngle = math.atan2(velocity.y or 0, velocity.x or 0)
            velocity.x = math.cos(currentAngle) * speed
            velocity.y = math.sin(currentAngle) * speed
            position.angle = currentAngle
            return
        end

        local targetPos = state.currentTarget.components.position
        local desiredAngle = math.atan2(targetPos.y - position.y, targetPos.x - position.x)
        local currentAngle = math.atan2(velocity.y or 0, velocity.x or 0)
        local maxTurn = turnRate * dt
        local diff = math.atan2(math.sin(desiredAngle - currentAngle), math.cos(desiredAngle - currentAngle))
        local clamped = clamp(diff, -maxTurn, maxTurn)
        local newAngle = currentAngle + clamped

        local speed = vector_length(velocity.x, velocity.y)
        if state.desiredSpeed and state.desiredSpeed > 0 then
            speed = state.desiredSpeed
        elseif speed <= 0 then
            local physics = projectile.components.physics
            local baseSpeed = (physics and physics.speed) or 700
            speed = baseSpeed
        end

        velocity.x = math.cos(newAngle) * speed
        velocity.y = math.sin(newAngle) * speed
        position.angle = newAngle
    end

    local events = {}

    events[ProjectileEvents.SPAWN] = function(payload)
        local world = payload and payload.world
        if world then
            state.reacquireTimer = state.reacquireDelay
            update_target(world, true)
        end
    end

    events[ProjectileEvents.UPDATE] = function(payload)
        local dt = (payload and payload.dt) or 0
        if dt < 0 then dt = 0 end
        local world = payload and payload.world

        if world then
            state.reacquireTimer = state.reacquireTimer - dt
            if state.reacquireTimer <= 0 then
                state.reacquireTimer = state.reacquireDelay
                update_target(world, true)
            elseif state.maintainNearest then
                update_target(world, false)
            end

            steer(dt, world)
        end
    end

    events[ProjectileEvents.HIT] = function()
        if not config.persistTarget then
            state.currentTarget = nil
        end
    end

    events[ProjectileEvents.EXPIRE] = function()
        state.currentTarget = nil
    end

    return {
        events = events,
    }
end

BehaviorRegistry.register("homing", factory)

return true
