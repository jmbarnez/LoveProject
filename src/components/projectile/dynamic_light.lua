local DynamicLight = require("src.components.dynamic_light")

local function copy_color(color)
    if type(color) ~= "table" then
        return color
    end

    return { color[1], color[2], color[3], color[4] }
end

return function(config)
    config = config or {}

    local color = copy_color(config.color or config.tint or {1.0, 0.85, 0.4, 0.9})
    local radius = config.radius or 24
    local pulse = config.pulse
    local intensity = config.intensity or 1.0
    local offset = config.offset

    return DynamicLight.new({
        color = color,
        radius = radius,
        pulse = pulse,
        intensity = intensity,
        offset = offset,
    })
end
