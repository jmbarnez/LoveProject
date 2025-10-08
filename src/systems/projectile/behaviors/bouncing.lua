local BehaviorRegistry = require("src.systems.projectile.behavior_registry")
local ProjectileEvents = require("src.systems.projectile.event_dispatcher").EVENTS
local State = require("src.game.state")

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
            local velocity = projectile.components and projectile.components.velocity
            if velocity then
                local currentSpeed = math.sqrt((velocity.x or 0) * (velocity.x or 0) + (velocity.y or 0) * (velocity.y or 0))
                if currentSpeed < state.minimumSpeed then
                    local angle = math.atan2(velocity.y or 0, velocity.x or 0)
                    velocity.x = math.cos(angle) * state.minimumSpeed
                    velocity.y = math.sin(angle) * state.minimumSpeed
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

        local velocity = projectile.components and projectile.components.velocity
        local position = projectile.components and projectile.components.position
        if not velocity or not position then
            return
        end

        local impactAngle = payload.impactAngle or 0
        local nx, ny = math.cos(impactAngle), math.sin(impactAngle)
        local rx, ry = reflect_velocity(velocity.x or 0, velocity.y or 0, nx, ny)
        rx, ry = normalize(rx, ry)

        local speed = math.sqrt((velocity.x or 0) * (velocity.x or 0) + (velocity.y or 0) * (velocity.y or 0))
        if state.speedMultiplier and state.speedMultiplier ~= 1.0 then
            speed = speed * state.speedMultiplier
        end
        if state.minimumSpeed and state.minimumSpeed > 0 then
            speed = math.max(speed, state.minimumSpeed)
        end

        velocity.x = rx * speed
        velocity.y = ry * speed
        position.angle = math.atan2(velocity.y, velocity.x)

        if payload.hitPosition then
            local offsetX = nx * ((payload.separation or 4) + 2)
            local offsetY = ny * ((payload.separation or 4) + 2)
            position.x = payload.hitPosition.x + offsetX
            position.y = payload.hitPosition.y + offsetY
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
