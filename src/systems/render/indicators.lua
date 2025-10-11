local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")

local Indicators = {}

function Indicators.drawTargetingBorder(world)
    local isTargeted = false
    for _, entity in ipairs(world:get_entities_with_components("ai")) do
        if entity.components.ai.targeting then
            isTargeted = true
            break
        end
    end

    if isTargeted then
        --[[
        local sw, sh = Viewport.getDimensions()
        local borderWidth = 5
        local time = love.timer.getTime()
        local alpha = 0.5 + (math.sin(time * 5) * 0.2)

        Theme.setColor(Theme.withAlpha(Theme.colors.danger, alpha))
        love.graphics.rectangle("fill", 0, 0, sw, borderWidth)
        love.graphics.rectangle("fill", 0, sh - borderWidth, sw, borderWidth)
        love.graphics.rectangle("fill", 0, 0, borderWidth, sh)
        love.graphics.rectangle("fill", sw - borderWidth, 0, borderWidth, sh)
        --]]
    end
end

return Indicators
