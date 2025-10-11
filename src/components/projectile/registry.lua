local Log = require("src.core.log")

local ProjectileComponentRegistry = {}

local constructors = {}

local function register(name, constructor)
    if type(name) ~= "string" or name == "" then
        Log.warn("Attempted to register projectile component with invalid name")
        return
    end

    if type(constructor) ~= "function" then
        Log.warn("Projectile component '" .. tostring(name) .. "' must provide a constructor function")
        return
    end

    if constructors[name] then
        Log.warn("Projectile component '" .. name .. "' is being overwritten")
    end

    constructors[name] = constructor
end

function ProjectileComponentRegistry.register(name, constructor)
    register(name, constructor)
end

function ProjectileComponentRegistry.create(name, config, context)
    local constructor = constructors[name]
    if not constructor then
        return nil, string.format("Unknown projectile component '%s'", tostring(name))
    end

    return constructor(config or {}, context or {})
end

function ProjectileComponentRegistry.isRegistered(name)
    return constructors[name] ~= nil
end

function ProjectileComponentRegistry.list()
    local names = {}
    for name in pairs(constructors) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end

-- Register built-in projectile components
register("dynamic_light", require("src.components.projectile.dynamic_light"))
register("bouncing", require("src.components.projectile.bouncing"))

return ProjectileComponentRegistry
