local Interactable = {}
Interactable.__index = Interactable

function Interactable.new(values)
    local instance = setmetatable({}, Interactable)
    values = values or {}
    instance.range = values.range or 50
    instance.prompt = values.prompt or "Click to interact"
    instance.requiresKey = values.requiresKey
    return instance
end

return Interactable
