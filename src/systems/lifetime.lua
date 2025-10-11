--[[
    Lifetime System

    Centralizes lifetime bookkeeping for entities that expire after a timer
    elapses or once they surpass a configured travel range. This mirrors the
    projectile expiration behaviour that previously lived inside World:update,
    emitting the same projectile events before entities are marked as dead.
]]

local ProjectileEvents = require("src.systems.projectile.event_dispatcher").EVENTS
local Effects = require("src.systems.effects")

local LifetimeSystem = {}

local function emit_projectile_event(entity, event, payload)
    if not entity or not entity.components then return end
    local projectile_events = entity.components.projectile_events
    if not projectile_events then return end

    local dispatcher = projectile_events.dispatcher
    if dispatcher then
        dispatcher:emit(event, payload)
    end
end

local function update_timed_life(entity, timed_life, dt)
    if not timed_life.timer then return end

    if timed_life.timer > 0 then
        timed_life.timer = timed_life.timer - dt
    end

    if timed_life.timer <= 0 then
        emit_projectile_event(entity, ProjectileEvents.EXPIRE, {
            projectile = entity,
            reason = "timed_out",
        })
        entity.dead = true
    end
end

local function update_max_range(entity, max_range)
    local position = entity.components.position
    if not position then return end

    local start_x = max_range.startX or position.x
    local start_y = max_range.startY or position.y
    local dx = position.x - start_x
    local dy = position.y - start_y
    local distance = math.sqrt(dx * dx + dy * dy)

    max_range.traveledDistance = distance

    if max_range.expired or not max_range.maxDistance then
        return
    end

    if distance < max_range.maxDistance then
        return
    end

    local kind = max_range.kind
    if (kind == "missile" or kind == "rocket") and entity.components.damage then
        if Effects and Effects.createExplosion then
            local damage = entity.components.damage.value or 0
            Effects.createExplosion(position.x, position.y, damage * 0.8, false)
        end
    end

    emit_projectile_event(entity, ProjectileEvents.EXPIRE, {
        projectile = entity,
        reason = "max_range",
        distance = distance,
        maxDistance = max_range.maxDistance,
    })

    max_range.expired = true
    entity.dead = true
end

local function process_entity(entity, dt)
    if not entity or entity.dead or not entity.components then
        return
    end

    local timed_life = entity.components.timed_life
    if timed_life then
        update_timed_life(entity, timed_life, dt)
    end

    if entity.dead then
        return
    end

    local max_range = entity.components.max_range
    if max_range then
        update_max_range(entity, max_range)
    end
end

function LifetimeSystem.update(dt, world)
    if not world then return end
    
    local entities = world:getEntities()
    for _, entity in pairs(entities) do
        -- Only process entities with timed_life or max_range components
        if entity.components and (entity.components.timed_life or entity.components.max_range) then
            process_entity(entity, dt)
        end
    end
end

return LifetimeSystem
