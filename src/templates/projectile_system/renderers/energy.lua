local RendererFactory = require("src.templates.projectile_system.renderer_factory")

local function build(name, defaults)
    RendererFactory.register(name, function(def)
        local props = {}
        for k, v in pairs(def.props or {}) do
            props[k] = v
        end
        props.kind = def.kind or props.kind or defaults.kind or "bullet"
        props.radius = props.radius or defaults.radius or 6
        props.color = props.color or defaults.color
        props.glowColor = props.glowColor or defaults.glowColor or props.color
        props.glowRadius = props.glowRadius or defaults.glowRadius
        props.pulse = props.pulse or defaults.pulse
        props.renderer = name
        props.tracerWidth = props.tracerWidth or defaults.tracerWidth
        props.coreRadius = props.coreRadius or defaults.coreRadius
        props.sparkColor = props.sparkColor or defaults.sparkColor
        return {
            type = def.type or defaults.type or "bullet",
            props = props,
        }
    end)
end

build("plasma", {
    radius = 5,
    color = {0.35, 0.85, 1.0, 1.0},
    glowColor = {0.2, 0.6, 1.0, 0.8},
    glowRadius = 18,
    pulse = { speed = 6.0, min = 0.85, max = 1.25 },
})

build("ion", {
    radius = 6,
    color = {0.5, 0.9, 1.0, 1.0},
    glowColor = {0.2, 0.95, 1.0, 0.9},
    glowRadius = 22,
    tracerWidth = 2.4,
})

build("tesla", {
    radius = 4,
    color = {0.6, 0.9, 1.0, 0.9},
    glowColor = {0.3, 0.7, 1.0, 0.7},
    glowRadius = 28,
    sparkColor = {0.8, 0.95, 1.0, 0.8},
})

build("gravity_well", {
    radius = 10,
    color = {0.45, 0.2, 1.0, 0.75},
    glowColor = {0.25, 0.1, 0.6, 0.55},
    glowRadius = 42,
    pulse = { speed = 3.0, min = 0.7, max = 1.1 },
})

return true
