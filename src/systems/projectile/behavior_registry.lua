local Log = require("src.core.log")

local BehaviorRegistry = {}

local registry = {}

function BehaviorRegistry.register(name, factory)
    if type(name) ~= "string" or name == "" then return end
    if type(factory) ~= "function" then return end

    if registry[name] then
        Log.warn("Projectile behavior '" .. name .. "' is being overwritten")
    end

    registry[name] = factory
end

function BehaviorRegistry.create(name, context, config)
    local factory = registry[name]
    if not factory then
        Log.warn("No projectile behavior registered for type '" .. tostring(name) .. "'")
        return nil
    end

    return factory(context, config or {})
end

function BehaviorRegistry.isRegistered(name)
    return registry[name] ~= nil
end

function BehaviorRegistry.reset()
    registry = {}
end

return BehaviorRegistry
