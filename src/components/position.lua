local Position = {}
Position.__index = Position

function Position.new(values)
    local instance = setmetatable({}, Position)
    instance.x = values.x or 0
    instance.y = values.y or 0
    instance.angle = values.angle or 0
    return instance
end

return Position
