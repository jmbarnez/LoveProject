local ProjectileRendererRegistry = require("src.systems.render.entities.projectile_renderers.registry")
local RenderUtils = require("src.systems.render.utils")

local function draw_body(props)
    local length = props.length or 18
    local radius = props.radius or 4
    RenderUtils.setColor(props.bodyColor or props.color or {0.6, 0.7, 0.8, 1.0})
    love.graphics.rectangle("fill", -length * 0.5, -radius, length, radius * 2, radius * 0.2)
end

local function draw_tip(props)
    local radius = props.radius or 4
    RenderUtils.setColor(props.color or {1.0, 0.8, 0.2, 1.0})
    love.graphics.circle("fill", radius * 0.8, 0, radius * 0.9)
end

local function draw_fins(props)
    if not props.finColor then return end
    local length = props.length or 18
    local radius = props.radius or 4
    RenderUtils.setColor(props.finColor)
    love.graphics.polygon("fill", -length * 0.5, -radius * 1.2, -length * 0.2, 0, -length * 0.5, radius * 1.2)
end

local function draw_trail(props)
    local trail = props.trail
    if not trail then return end
    RenderUtils.setColor(trail.color or {1.0, 0.6, 0.2, 0.8})
    love.graphics.circle("fill", - (props.length or 18) * 0.6, 0, (props.radius or 4) * 0.9)
end

local function register(name)
    ProjectileRendererRegistry.register(name, function(entity, props)
        draw_trail(props)
        draw_body(props)
        draw_fins(props)
        draw_tip(props)
    end)
end

register("torpedo")
register("cluster_missile")
register("homing_missile")

return true
