local RendererFactory = {}

local registry = {}

local function shallow_copy(tbl)
    local copy = {}
    for k, v in pairs(tbl or {}) do
        copy[k] = v
    end
    return copy
end

local function merge_props(base, overrides)
    local props = shallow_copy(base)
    for k, v in pairs(overrides or {}) do
        props[k] = v
    end
    return props
end

function RendererFactory.register(name, factory)
    if type(name) ~= "string" or name == "" then return end
    if type(factory) ~= "function" then return end
    registry[name] = factory
end

function RendererFactory.create(def)
    if type(def) ~= "table" then
        return { type = "bullet", props = {} }
    end

    if def.renderer and registry[def.renderer] then
        local result = registry[def.renderer](def)
        if result then
            return result
        end
    end

    if def.kind and registry[def.kind] then
        local result = registry[def.kind](def)
        if result then
            return result
        end
    end

    local props = shallow_copy(def.props)
    if def.kind and not props.kind then
        props.kind = def.kind
    end
    return {
        type = def.type or "bullet",
        props = props,
    }
end

function RendererFactory.extend(def, overrides)
    if not def then return RendererFactory.create(overrides or {}) end
    local combined = {
        type = overrides and overrides.type or def.type,
        renderer = overrides and overrides.renderer or def.renderer,
        kind = overrides and overrides.kind or def.kind,
        props = merge_props(def.props or {}, overrides and overrides.props or {}),
    }
    return RendererFactory.create(combined)
end

return RendererFactory
