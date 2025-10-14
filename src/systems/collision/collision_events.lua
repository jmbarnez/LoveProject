-- CollisionEvents
-- Lightweight event hub for collision-specific hooks.
-- Allows systems to subscribe to unified physics collisions without
-- embedding bespoke logic into the resolver.

local CollisionEvents = {}

local EVENT_BUCKETS = {
    pre_resolve = {},
    post_resolve = {},
}

-- Subscribe to a collision event.
-- @param event string: 'pre_resolve' | 'post_resolve'
-- @param listener function(context): listener invoked with collision context.
-- @return function: call to unsubscribe the listener.
function CollisionEvents.on(event, listener)
    local bucket = EVENT_BUCKETS[event]
    if not bucket then
        error(("CollisionEvents.on: unknown event '%s'"):format(tostring(event)))
    end

    table.insert(bucket, listener)

    return function()
        for index, fn in ipairs(bucket) do
            if fn == listener then
                table.remove(bucket, index)
                break
            end
        end
    end
end

-- Emit an event to all listeners.
-- The context table is passed by reference so listeners may mutate it
-- (e.g., `context.cancel = true` during pre_resolve).
function CollisionEvents.emit(event, context)
    local bucket = EVENT_BUCKETS[event]
    if not bucket then
        return
    end

    -- Iterate by index to avoid issues if listeners remove themselves.
    for i = 1, #bucket do
        bucket[i](context)
        if event == "pre_resolve" and context.cancel then
            -- Early exit once a listener cancels the collision resolution.
            break
        end
    end
end

return CollisionEvents
