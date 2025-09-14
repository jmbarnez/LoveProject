local Damage = {}
Damage.__index = Damage

function Damage.new(value)
    local instance = setmetatable({}, Damage)
    instance.value = value or 0
    return instance
end

return Damage