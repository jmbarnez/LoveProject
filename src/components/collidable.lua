local Collidable = {}
Collidable.__index = Collidable

function Collidable.new(values)
    local instance = setmetatable({}, Collidable)
    -- Support being called with a table of properties
    values = values or {}
    instance.radius = values.radius or 0
    -- Preserve optional shape/vertices for polygon collisions
    instance.shape = values.shape or values.type
    instance.vertices = values.vertices
    -- Optional gameplay metadata
    instance.friendly = values.friendly or false
    instance.signature = values.signature -- may be nil if not provided
    return instance
end

return Collidable
