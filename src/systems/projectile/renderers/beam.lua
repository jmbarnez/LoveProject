local RendererFactory = require("src.systems.projectile.renderer_factory")

local function build(name, defaults)
    RendererFactory.register(name, function(def)
        local props = {}
        for k, v in pairs(def.props or {}) do
            props[k] = v
        end
        props.kind = def.kind or props.kind or "laser"
        props.length = props.length or defaults.length or 600
        props.maxLength = props.maxLength or defaults.maxLength or props.length
        props.tracerWidth = props.tracerWidth or defaults.tracerWidth or 4
        props.color = props.color or defaults.color
        props.coreColor = props.coreColor or defaults.coreColor
        props.renderer = name
        props.glowColor = props.glowColor or defaults.glowColor
        props.rayCount = props.rayCount or defaults.rayCount
        return {
            type = def.type or "bullet",
            props = props,
        }
    end)
end

build("particle_beam", {
    color = {0.65, 0.95, 1.0, 0.75},
    coreColor = {0.9, 1.0, 1.0, 1.0},
    tracerWidth = 5,
    rayCount = 3,
})

build("disruptor_beam", {
    color = {0.95, 0.4, 1.0, 0.85},
    coreColor = {1.0, 0.75, 1.0, 0.9},
    tracerWidth = 6,
    rayCount = 2,
})

return true
