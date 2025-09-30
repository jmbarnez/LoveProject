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
    if (not instance.radius or instance.radius == 0) and instance.vertices then
        local maxRadius = 0
        for i = 1, #instance.vertices, 2 do
            local vx = instance.vertices[i] or 0
            local vy = instance.vertices[i + 1] or 0
            local distance = math.sqrt(vx * vx + vy * vy)
            if distance > maxRadius then
                maxRadius = distance
            end
        end
        instance.radius = maxRadius
    end
    -- Optional gameplay metadata
    instance.friendly = values.friendly or false
    instance.signature = values.signature -- may be nil if not provided
    return instance
end

return Collidable
