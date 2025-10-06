local ProjectileRendererRegistry = require("src.systems.render.entities.projectile_renderers.registry")
local RenderUtils = require("src.systems.render.utils")

local function draw_beam(props)
    local length = props.length or props.maxLength or 600
    local color = props.color or {0.4, 0.8, 1.0, 0.8}
    local core = props.coreColor or {1.0, 1.0, 1.0, 1.0}
    local rayCount = props.rayCount or 1

    if props.glowColor then
        RenderUtils.setColor(props.glowColor)
        love.graphics.setLineWidth((props.tracerWidth or 4) * 2.2)
        love.graphics.line(0, 0, length, 0)
    end

    RenderUtils.setColor(color)
    love.graphics.setLineWidth(props.tracerWidth or 4)
    love.graphics.line(0, 0, length, 0)

    RenderUtils.setColor(core)
    love.graphics.setLineWidth((props.tracerWidth or 4) * 0.5)
    love.graphics.line(0, 0, length, 0)

    if rayCount and rayCount > 1 then
        RenderUtils.setColor({core[1], core[2], core[3], (core[4] or 1) * 0.5})
        for i = 1, rayCount do
            local offset = (i - (rayCount + 1) / 2) * 3
            love.graphics.line(0, offset, length, offset)
        end
    end

    love.graphics.setLineWidth(1)
end

local function register(name)
    ProjectileRendererRegistry.register(name, function(entity, props)
        draw_beam(props)
    end)
end

register("particle_beam")
register("disruptor_beam")

return true
