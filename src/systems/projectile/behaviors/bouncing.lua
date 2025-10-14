local BehaviorRegistry = require("src.systems.projectile.behavior_registry")
local ProjectileEvents = require("src.systems.projectile.event_dispatcher").EVENTS

local function reflect_velocity(vx, vy, nx, ny)
    local dot = (vx * nx) + (vy * ny)
    local rx = vx - 2 * dot * nx
    local ry = vy - 2 * dot * ny
    return rx, ry
end

local function normalize(x, y)
    local len = math.sqrt(x * x + y * y)
    if len <= 0.0001 then
        return 0, 0
    end
    return x / len, y / len
end

local function factory(context, config)
    local projectile = context.projectile
    local maxBounces = config.bounces or config.maxBounces or 1
    if maxBounces < 0 then maxBounces = 0 end

    local state = {
        remaining = maxBounces,
        maxBounces = maxBounces,
        speedMultiplier = config.speedMultiplier or 1.0,
        minimumSpeed = config.minimumSpeed or 0,
        immunityDuration = config.immunityDuration or 0.05,
        immunityTimer = 0,
    }

    local function sync_component()
        local component = projectile.components and projectile.components.bouncing
        if component then
            component.remaining = state.remaining
            component.maxBounces = state.maxBounces
        end
    end

    local events = {}

    events[ProjectileEvents.UPDATE] = function(payload)
        local dt = (payload and payload.dt) or 0
        if dt < 0 then dt = 0 end
        if state.immunityTimer > 0 then
            state.immunityTimer = math.max(0, state.immunityTimer - dt)
        end
        if state.minimumSpeed and state.minimumSpeed > 0 then
            -- Get velocity from Windfield physics
            local PhysicsSystem = require("src.systems.physics")
            local physicsManager = PhysicsSystem.getManager()
            if physicsManager then
                local vx, vy = physicsManager:getVelocity(projectile)
                local currentSpeed = math.sqrt((vx or 0) * (vx or 0) + (vy or 0) * (vy or 0))
                if currentSpeed < state.minimumSpeed then
                    local angle = math.atan2(vy or 0, vx or 0)
                    local newVx = math.cos(angle) * state.minimumSpeed
                    local newVy = math.sin(angle) * state.minimumSpeed
                    physicsManager:setVelocity(projectile, newVx, newVy)
                end
            end
        end
    end

    events[ProjectileEvents.HIT] = function(payload)
        if not payload or state.remaining <= 0 then
            return
        end

        if state.immunityTimer > 0 then
            return
        end

        local position = projectile.components and projectile.components.position
        if not position then
            return
        end
        
        -- Get velocity from Windfield physics
        local PhysicsSystem = require("src.systems.physics")
        local physicsManager = PhysicsSystem.getManager()
        if not physicsManager then
            return
        end
        
        local vx, vy = physicsManager:getVelocity(projectile)
        local impactAngle = payload.impactAngle or 0
        local nx, ny = math.cos(impactAngle), math.sin(impactAngle)
        local rx, ry = reflect_velocity(vx or 0, vy or 0, nx, ny)
        rx, ry = normalize(rx, ry)

        local speed = math.sqrt((vx or 0) * (vx or 0) + (vy or 0) * (vy or 0))
        if state.speedMultiplier and state.speedMultiplier ~= 1.0 then
            speed = speed * state.speedMultiplier
        end
        if state.minimumSpeed and state.minimumSpeed > 0 then
            speed = math.max(speed, state.minimumSpeed)
        end

        -- Update velocity through Windfield physics
        local newVx = rx * speed
        local newVy = ry * speed
        physicsManager:setVelocity(projectile, newVx, newVy)
        position.angle = math.atan2(newVy, newVx)

        if payload.hitPosition then
            local offsetX = nx * ((payload.separation or 4) + 2)
            local offsetY = ny * ((payload.separation or 4) + 2)
            local newX = payload.hitPosition.x + offsetX
            local newY = payload.hitPosition.y + offsetY
            
            -- Update position through WindField physics
            local collider = physicsManager:getCollider(projectile)
            if collider and not collider:isDestroyed() then
                collider:setPosition(newX, newY)
            end
        end

        state.remaining = state.remaining - 1
        sync_component()
        state.immunityTimer = state.immunityDuration

        payload.keepAlive = true
        payload.skipTarget = payload.target
    end

    events[ProjectileEvents.EXPIRE] = function(payload)
        if payload and payload.reason == "timed_out" and state.remaining > 0 then
            -- Allow projectiles that still have bounces to persist by refreshing timer once
            if projectile.components and projectile.components.timed_life then
                projectile.components.timed_life.timer = (projectile.components.timed_life.duration or 0.5)
            end
        end
    end

    return {
        events = events,
        components = {
            {
                name = "bouncing",
                config = {
                    maxBounces = maxBounces,
                },
                overwrite = true,
            }
        }
    }
end

BehaviorRegistry.register("bouncing", factory)

return true
