local Renderable = {}
Renderable.__index = Renderable

function Renderable.new(typeOrValues, props)
    local instance = setmetatable({}, Renderable)

    -- Handle both old and new calling conventions
    if type(typeOrValues) == "string" then
        instance.type = typeOrValues
        instance.props = props or {}
        instance.visuals = props
    else
        local values = typeOrValues or {}
        instance.type = values.type or "asteroid"
        instance.shape = values.shape or "asteroid"
        instance.size = values.size or 1
        instance.props = values.props or {}
        instance.visuals = values.visuals
    end

    return instance
end

return Renderable
