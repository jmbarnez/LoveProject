local Log = require("src.core.log")

local EffectRegistry = {}
EffectRegistry.__index = EffectRegistry

local registry = {}

function EffectRegistry.register(name, factory)
    if type(name) ~= "string" or name == "" then return end
    if type(factory) ~= "function" then return end

    if registry[name] then
        Log.warn("Projectile effect '" .. name .. "' is being overwritten")
    end

    registry[name] = factory
end

function EffectRegistry.create(name, context, config)
    local factory = registry[name]
    if not factory then
        Log.warn("No projectile effect registered for type '" .. tostring(name) .. "'")
        return nil
    end

    return factory(context, config or {})
end

function EffectRegistry.isRegistered(name)
    return registry[name] ~= nil
end

function EffectRegistry.reset()
    registry = {}
end

return EffectRegistry
