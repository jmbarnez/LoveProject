local ProjectileRendererRegistry = {}

local registry = {}

function ProjectileRendererRegistry.register(name, renderer)
    if type(name) ~= "string" or name == "" then return end
    if type(renderer) ~= "function" then return end
    registry[name] = renderer
end

function ProjectileRendererRegistry.draw(name, entity, props)
    local renderer = registry[name]
    if renderer then
        renderer(entity, props)
        return true
    end
    return false
end

function ProjectileRendererRegistry.has(name)
    return registry[name] ~= nil
end

return ProjectileRendererRegistry
