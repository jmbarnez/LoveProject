local RenderUtils = require("src.systems.render.utils")
local util = require("src.core.util")

local function render(entity, player)
    local props = entity.components.renderable.props or {}
    local kind = props.kind

    if kind == 'laser' or kind == 'salvaging_laser' or kind == 'mining_laser' then
        -- Draw along +X in local space; outer renderer applies rotation.
        local len = props.length or props.maxLength or 800
        local baseColor, baseWidth

        -- Type-specific colors for charged pulse system
        if kind == 'salvaging_laser' then
            baseColor = util.copy(props.color or {0.2, 1.0, 0.3, 0.8}) -- Green
            baseWidth = props.tracerWidth or 2.0
        elseif kind == 'mining_laser' then
            baseColor = util.copy(props.color or {1.0, 0.7, 0.2, 0.8}) -- Orange
            baseWidth = props.tracerWidth or 2.0
        else
            baseColor = util.copy(props.color or {0.3, 0.7, 1.0, 0.8}) -- Blue (combat)
            baseWidth = props.tracerWidth or 1.5
        end

        -- Charged pulse effect system: buildup + flash then disappear
        local tl = entity.components.timed_life
        local totalLife = (tl and tl.life) or 0.15
        local timeLeft = (tl and tl.timer) or totalLife
        local elapsed = totalLife - timeLeft

        -- Phase timing
        local flashTime = 0.02

        local phase, phaseProgress, alpha, coreW, glowW
        local r, g, b, baseAlpha = util.unpack_color(baseColor)

        if elapsed <= flashTime then
            -- FLASH PHASE: Intense beam release
            phase = "flash"
            phaseProgress = elapsed / flashTime
            alpha = baseAlpha * (2.0 + 0.5 * math.sin(phaseProgress * math.pi * 8)) -- Flickering intensity
            coreW = baseWidth * (0.8 + 0.3 * math.sin(phaseProgress * math.pi * 12)) -- Thinner core
            glowW = coreW + 4 + 2 * math.sin(phaseProgress * math.pi * 6) -- Less glow
        else
            -- POST-FLASH: Immediate disappear (render nothing)
            phase = "done"
            alpha = 0
            coreW = 0
            glowW = 0
        end

        if love.graphics.setLineStyle then love.graphics.setLineStyle('smooth') end

        -- Skip rendering if laser is done
        if phase == "done" then
            return
        end

        -- Beam rendering
        if phase == "flash" then
            -- Beam discharge
            -- Outer glow
            love.graphics.setLineWidth(glowW)
            RenderUtils.setColor(baseColor, alpha * 0.5)
            love.graphics.line(0, 0, len, 0)

            -- Core beam - brighter and wider
            love.graphics.setLineWidth(coreW)
            RenderUtils.setColor({math.min(1, r + 0.4), math.min(1, g + 0.4), math.min(1, b + 0.4), alpha})
            love.graphics.line(0, 0, len, 0)

        end

        love.graphics.setLineWidth(1)
        if love.graphics.setLineStyle then love.graphics.setLineStyle('rough') end
    else
        local color = props.color or {0.35, 0.70, 1.00, 1.0}
        local radius = props.radius or 1

        RenderUtils.setColor(color)
        love.graphics.circle("fill", 0, 0, radius)
    end
end

return render
