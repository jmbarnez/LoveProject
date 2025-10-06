local ProjectileRendererRegistry = require("src.systems.render.entities.projectile_renderers.registry")
local RenderUtils = require("src.systems.render.utils")
local util = require("src.core.util")

local function draw_streak(props)
    local streak = props.streak
    if not streak then return end
    local length = streak.length or 20
    local width = streak.width or 2
    local color = streak.color or {1, 1, 1, 0.5}
    RenderUtils.setColor(color)
    love.graphics.setLineWidth(width)
    love.graphics.line(-length, 0, 0, 0)
    love.graphics.setLineWidth(1)
end

local function draw_core(props)
    RenderUtils.setColor(props.color or {0.9, 0.9, 0.95, 1.0})
    love.graphics.circle("fill", 0, 0, props.radius or 3)
end

local function draw_sparks(props)
    if not props.sparkColor then return end
    RenderUtils.setColor(props.sparkColor)
    for i = 1, 4 do
        local angle = (i / 4) * math.pi * 2
        local len = (props.radius or 4) * 1.4
        love.graphics.line(0, 0, math.cos(angle) * len, math.sin(angle) * len)
    end
end

local function register(name)
    ProjectileRendererRegistry.register(name, function(entity, props)
        draw_streak(props)
        draw_core(props)
        draw_sparks(props)
    end)
end

register("railgun")
register("gauss")
register("fragmentation")
register("kinetic_bombardment")

return true
