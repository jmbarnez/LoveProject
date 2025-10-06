local DynamicLight = {}
DynamicLight.__index = DynamicLight

function DynamicLight.new(values)
    local instance = setmetatable({}, DynamicLight)
    values = values or {}
    instance.color = values.color or {1.0, 1.0, 1.0, 0.8}
    instance.radius = values.radius or 24
    instance.pulse = values.pulse
    instance.intensity = values.intensity or 1.0
    instance.offset = values.offset or { x = 0, y = 0 }
    return instance
end

return DynamicLight
