local RenderUtils = require("src.systems.render.utils")

local function render(entity, player)
    local props = entity.components.renderable.props or {}
    local v = props.visuals or {}
    local size = v.size or 1.0
    local S = RenderUtils.createScaler(size)

    -- Visual parameters
    local R = (v.radius or (entity.components.collidable and entity.components.collidable.radius) or 600)
    local baseColor = v.baseColor or {0.10, 0.12, 0.18, 1.0}
    local accentColor = v.accentColor or {0.18, 0.22, 0.32, 1.0}
    local atmosphereColor = v.atmosphereColor or {0.35, 0.75, 1.0, 0.14}
    local showAtmosphere = (v.atmosphere ~= false)
    local highlightColor = v.highlightColor or {1.0, 0.95, 0.85, 0.10}
    local lightDir = v.lightDir or (math.pi * 1.25) -- radians; light from top-left by default

    -- Ring parameters (optional)
    local ringInner = v.ringInner or (R * 1.25)
    local ringOuter = v.ringOuter or (R * 1.8)
    local ringTilt = v.ringTilt or (math.rad(25))
    local ringFlatten = v.ringFlatten or 0.35 -- 1.0 = circle, <1 = thinner ellipse
    local ringColor = v.ringColor or {0.75, 0.70, 0.60, 0.28}
    local ringEdgeColor = v.ringEdgeColor or {0.95, 0.90, 0.80, 0.38}
    local ringLayers = v.ringLayers or 10

    -- Draw ring first so it appears behind the planet body
    if ringOuter and ringInner and ringOuter > ringInner then
        love.graphics.push()
        love.graphics.rotate(ringTilt)
        for i = 0, ringLayers - 1 do
            local t = i / math.max(1, (ringLayers - 1))
            local rr = ringInner + (ringOuter - ringInner) * t
            local baseAlpha = (type(ringColor) == "table" and ringColor[4]) or 0.28
            local a = baseAlpha * (0.6 + 0.4 * (1 - math.abs(0.5 - t) * 2))
            love.graphics.setColor(ringColor[1], ringColor[2], ringColor[3], a)
            love.graphics.ellipse('line', 0, 0, S(rr), S(rr * ringFlatten))
        end
        -- Subtle brighter edge
        love.graphics.setColor(ringEdgeColor[1], ringEdgeColor[2], ringEdgeColor[3], ringEdgeColor[4])
        love.graphics.ellipse('line', 0, 0, S(ringOuter), S(ringOuter * ringFlatten))
        love.graphics.pop()
    end

    -- Body base
    RenderUtils.setColor(baseColor)
    love.graphics.circle('fill', 0, 0, S(R))

    -- Subtle bands/accents to add depth
    local accentAlpha = (type(accentColor) == "table" and accentColor[4]) or 1.0
    RenderUtils.setColor({accentColor[1], accentColor[2], accentColor[3], accentAlpha * 0.6})
    for i = -2, 2 do
        local ry = S(R * (0.72 + i * 0.06))
        local alpha = 0.05 + (0.03 * (2 - math.abs(i)))
        love.graphics.setColor(accentColor[1], accentColor[2], accentColor[3], alpha)
        love.graphics.ellipse('fill', 0, 0, S(R * 0.96), ry)
    end

    -- Day-night terminator shading: layered offset circles opposing lightDir
    local layers = 16
    for i = 1, layers do
        local t = i / layers
        local off = S(R * 0.28 * t)
        local ox = -math.cos(lightDir) * off
        local oy = -math.sin(lightDir) * off
        local a = 0.04 * (1.0 - t)
        love.graphics.setColor(0, 0, 0, a)
        love.graphics.circle('fill', ox, oy, S(R * (1.0 - 0.01 * i)))
    end

    -- Highlight rim on the lit side
    do
        local rimR = S(R * 0.98)
        local w = math.max(2, S(R * 0.03))
        local hx = math.cos(lightDir) * S(R * 0.02)
        local hy = math.sin(lightDir) * S(R * 0.02)
        love.graphics.setLineWidth(w)
        love.graphics.setColor(highlightColor)
        love.graphics.circle('line', hx, hy, rimR)
        love.graphics.setLineWidth(1)
    end

    -- Atmosphere glow (optional)
    local atmosphereAlpha = (type(atmosphereColor) == "table" and atmosphereColor[4]) or 0.14
    if showAtmosphere and atmosphereAlpha > 0 then
        local gLayers = 5
        for i = 1, gLayers do
            local t = i / gLayers
            local rr = S(R * (1.02 + t * 0.06))
            local a = atmosphereAlpha * (1.1 - t)
            love.graphics.setColor(atmosphereColor[1], atmosphereColor[2], atmosphereColor[3], a)
            love.graphics.circle('line', 0, 0, rr)
        end
    end
end

return render
