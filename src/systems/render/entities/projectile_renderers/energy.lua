local ProjectileRendererRegistry = require("src.systems.render.entities.projectile_renderers.registry")
local RenderUtils = require("src.systems.render.utils")
local util = require("src.core.util")

local function draw_glow(props)
    if not props.glowColor or not props.glowRadius then return end
    local r, g, b, a = util.unpack_color(props.glowColor)
    RenderUtils.setColor({r, g, b, a or 0.6})
    love.graphics.circle("fill", props.offsetX or 0, props.offsetY or 0, props.glowRadius)
end

local function draw_core(props)
    RenderUtils.setColor(props.color or {0.35, 0.85, 1.0, 1.0})
    love.graphics.circle("fill", props.offsetX or 0, props.offsetY or 0, props.radius or 4)
end

local function draw_pulse(props)
    if not props.pulse then return end
    local pulse = props.pulse
    local timer = love.timer and love.timer.getTime and love.timer.getTime() or 0
    local scale = 1
    if pulse.speed and pulse.max and pulse.min then
        scale = pulse.min + (math.sin(timer * pulse.speed) * 0.5 + 0.5) * (pulse.max - pulse.min)
    end
    RenderUtils.setColor({(props.color or {1,1,1,1})[1], (props.color or {1,1,1,1})[2], (props.color or {1,1,1,1})[3], 0.25})
    love.graphics.circle("line", props.offsetX or 0, props.offsetY or 0, (props.radius or 4) * scale)
end

local function draw_sparks(props)
    if not props.sparkColor then return end
    local color = props.sparkColor
    RenderUtils.setColor(color)
    local radius = props.radius or 5
    for i = 1, 3 do
        local angle = (i / 3) * math.pi * 2
        local sx = math.cos(angle) * radius * 1.6
        local sy = math.sin(angle) * radius * 1.6
        love.graphics.line(0, 0, sx, sy)
    end
end

local function register(name)
    ProjectileRendererRegistry.register(name, function(entity, props)
        draw_glow(props)
        draw_core(props)
        draw_pulse(props)
        draw_sparks(props)
    end)
end

register("plasma")
register("ion")
register("tesla")
register("gravity_well")

return true
