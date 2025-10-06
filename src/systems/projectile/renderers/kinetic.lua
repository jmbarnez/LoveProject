local RendererFactory = require("src.systems.projectile.renderer_factory")

local function build(name, defaults)
    RendererFactory.register(name, function(def)
        local props = {}
        for k, v in pairs(def.props or {}) do
            props[k] = v
        end
        props.kind = def.kind or props.kind or "bullet"
        props.radius = props.radius or defaults.radius or 3
        props.color = props.color or defaults.color or {0.9, 0.9, 0.95, 1.0}
        props.tracerWidth = props.tracerWidth or defaults.tracerWidth
        props.coreRadius = props.coreRadius or defaults.coreRadius
        props.renderer = name
        props.streak = props.streak or defaults.streak
        props.sparkColor = props.sparkColor or defaults.sparkColor
        return {
            type = def.type or "bullet",
            props = props,
        }
    end)
end

build("railgun", {
    radius = 3,
    tracerWidth = 1.2,
    color = {0.85, 0.9, 1.0, 1.0},
    streak = { length = 30, width = 2, color = {0.6, 0.75, 1.0, 0.8} },
})

build("gauss", {
    radius = 4,
    tracerWidth = 1.5,
    color = {0.95, 0.8, 0.45, 1.0},
    streak = { length = 26, width = 2.2, color = {1.0, 0.85, 0.3, 0.7} },
})

build("fragmentation", {
    radius = 5,
    color = {0.9, 0.7, 0.4, 1.0},
    tracerWidth = 1.8,
    sparkColor = {1.0, 0.5, 0.2, 0.8},
})

build("kinetic_bombardment", {
    radius = 7,
    tracerWidth = 2.2,
    color = {0.95, 0.95, 1.0, 1.0},
    streak = { length = 40, width = 3.2, color = {1.0, 0.9, 0.7, 0.6} },
})

return true
