local Interactable = {}
Interactable.__index = Interactable

function Interactable.new(values)
    values = values or {}
    local instance = setmetatable({}, Interactable)
    instance.range = values.range or 0
    instance.prompt = values.prompt
    instance.requiresKey = values.requiresKey
    instance.hint = values.hint
    instance.activate = values.activate
    return instance
end

return Interactable
