local Velocity = {}
Velocity.__index = Velocity

function Velocity.new(values)
    local instance = setmetatable({}, Velocity)
    values = values or {}
    -- Normalize to x/y while supporting legacy dx/dy
    instance.x = values.x or values.dx or 0
    instance.y = values.y or values.dy or 0
    return instance
end

return Velocity
