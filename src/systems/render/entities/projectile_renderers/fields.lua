local ProjectileRendererRegistry = require("src.systems.render.entities.projectile_renderers.registry")
local RenderUtils = require("src.systems.render.utils")

ProjectileRendererRegistry.register("area_field", function(entity, props)
    local radius = props.coreRadius or props.radius or 40
    local color = props.color or {0.4, 0.8, 1.0, 0.35}
    RenderUtils.setColor({color[1], color[2], color[3], (color[4] or 0.35) * 0.4})
    love.graphics.circle("fill", 0, 0, radius)
    RenderUtils.setColor({color[1], color[2], color[3], (color[4] or 0.35)})
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", 0, 0, radius)
    love.graphics.setLineWidth(1)
end)

return true
