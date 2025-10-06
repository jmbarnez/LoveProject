local RendererFactory = require("src.templates.projectile_system.renderer_factory")

local function build(name, defaults)
    RendererFactory.register(name, function(def)
        local props = {}
        for k, v in pairs(def.props or {}) do
            props[k] = v
        end
        props.kind = def.kind or props.kind or "missile"
        props.length = props.length or defaults.length or 22
        props.radius = props.radius or defaults.radius or 5
        props.color = props.color or defaults.color
        props.engineColor = props.engineColor or defaults.engineColor or {1.0, 0.6, 0.2, 1.0}
        props.trail = props.trail or defaults.trail
        props.renderer = name
        props.bodyColor = props.bodyColor or defaults.bodyColor
        props.finColor = props.finColor or defaults.finColor
        return {
            type = def.type or "bullet",
            props = props,
        }
    end)
end

build("torpedo", {
    length = 28,
    radius = 6,
    color = {0.75, 0.85, 1.0, 1.0},
    bodyColor = {0.35, 0.45, 0.65, 1.0},
    finColor = {0.2, 0.3, 0.5, 1.0},
    trail = { color = {1.0, 0.6, 0.25, 0.9}, interval = 0.02 },
})

build("cluster_missile", {
    length = 18,
    radius = 5,
    color = {0.9, 0.8, 0.45, 1.0},
    bodyColor = {0.4, 0.35, 0.25, 1.0},
    trail = { color = {1.0, 0.7, 0.35, 0.8}, interval = 0.03 },
})

build("homing_missile", {
    length = 16,
    radius = 5,
    color = {0.6, 0.85, 1.0, 1.0},
    bodyColor = {0.3, 0.5, 0.75, 1.0},
    trail = { color = {0.75, 0.9, 1.0, 0.7}, interval = 0.025 },
})

return true
