local Shield = {}
Shield.__index = Shield

function Shield.new(values)
    local instance = setmetatable({}, Shield)
    -- Shield integrity
    instance.shield = (values and values.shield) or 0
    instance.maxShield = (values and values.maxShield) or 0
    return instance
end

return Shield
