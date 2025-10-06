local RenderUtils = require("src.systems.render.utils")
local EnemyStatusBars = require("src.ui.hud.enemy_status_bars")
local DebugPanel = require("src.ui.debug_panel")

local function render(entity, player)
    local props = entity.components.renderable.props or {}
    local v = props.visuals or {}
    local size = v.size or 1.0
    local S = RenderUtils.createScaler(size)

    -- Engine trails are drawn from the main renderer in world space

    local drewBody = false
    if type(v.shapes) == "table" and #v.shapes > 0 then
        for _, shape in ipairs(v.shapes) do
            RenderUtils.drawShape(shape, S)
        end
        drewBody = true
    end

    if not drewBody then
        -- Fallback default drawing
        RenderUtils.setColor({0.35, 0.37, 0.40, 1.0})
        love.graphics.circle("fill", 0, 0, S(10))
        RenderUtils.setColor({0.18, 0.20, 0.22, 1.0})
        love.graphics.circle("line", 0, 0, S(10))
        RenderUtils.setColor({1.0, 0.3, 0.25, 0.85})
        love.graphics.circle("fill", S(3), 0, S(3.2))
    end

    -- Mini shield and health bars (screen-aligned) above enemy
    EnemyStatusBars.drawMiniBars(entity)

    -- Draw detection radius overlay (debug only)
    if entity.components.ai and entity.components.ai.state ~= "dead" and DebugPanel.isVisible() then
        local ai = entity.components.ai
        local detectionRange = ai.detectionRange or 0
        if detectionRange > 0 then
            local engaged = (ai.state == "hunting")
            local primaryColor = engaged and {1.0, 0.35, 0.1, 0.55} or {1.0, 0.85, 0.05, 0.35}
            RenderUtils.setColor(primaryColor)
            love.graphics.setLineWidth(engaged and 1.6 or 1.2)
            love.graphics.circle("line", 0, 0, detectionRange)
            RenderUtils.setColor({primaryColor[1], primaryColor[2], primaryColor[3], 0.18})
            love.graphics.setLineWidth(1)
            love.graphics.circle("line", 0, 0, detectionRange * 0.5)
        end
    end
end

return render
