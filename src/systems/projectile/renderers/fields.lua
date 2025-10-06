local RendererFactory = require("src.systems.projectile.renderer_factory")

RendererFactory.register("area_field", function(def)
    local props = {}
    for k, v in pairs(def.props or {}) do
        props[k] = v
    end
    props.kind = def.kind or props.kind or "area_field"
    props.radius = props.radius or def.coreRadius or 40
    props.coreRadius = props.coreRadius or props.radius
    props.color = props.color or {0.4, 0.8, 1.0, 0.35}
    props.renderer = "area_field"
    return {
        type = def.type or "bullet",
        props = props,
    }
end)

return true
