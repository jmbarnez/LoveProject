local function render(entity, player)
    local props = entity.components.renderable.props or {}
    local Theme = require("src.core.theme")
    local time = love.timer.getTime()
    entity._pulseOffset = entity._pulseOffset or math.random() * math.pi * 2

    local baseRadius = 9 * (props.sizeScale or 1.0)
    local pulse = 0.75 + 0.25 * math.sin(time * 4 + entity._pulseOffset)
    local glowRadius = baseRadius * (1.4 + 0.2 * math.sin(time * 3.2 + entity._pulseOffset * 0.5))

    local xpColor = Theme.semantic and Theme.semantic.modernStatusXP or {0.45, 0.75, 1.0, 1.0}
    local glowColor = {xpColor[1], xpColor[2], xpColor[3], 0.35}

    love.graphics.setColor(glowColor)
    love.graphics.circle("fill", 0, 0, glowRadius)

    love.graphics.setColor(xpColor[1], xpColor[2], xpColor[3], 0.85)
    love.graphics.circle("fill", 0, 0, baseRadius * pulse)

    love.graphics.setColor(1.0, 1.0, 1.0, 0.95)
    love.graphics.setLineWidth(1)
    love.graphics.circle("line", 0, 0, baseRadius * (0.85 + 0.15 * pulse))

    local oldFont = love.graphics.getFont()
    if Theme.fonts and Theme.fonts.small then
        love.graphics.setFont(Theme.fonts.small)
    end

    local font = love.graphics.getFont()
    local label = "XP"
    local labelW = font:getWidth(label)
    local labelH = font:getHeight()
    love.graphics.setColor(1.0, 1.0, 1.0, 0.9)
    love.graphics.print(label, -labelW * 0.5, -labelH * 0.5)

    if oldFont then
        love.graphics.setFont(oldFont)
    end
end

return render
