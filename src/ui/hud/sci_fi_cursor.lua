local Theme = require("src.core.theme")

local SciFiCursor = {}

local function resolveColor(color, fallback)
    if type(color) == "table" then
        return color
    end
    return fallback
end

function SciFiCursor.drawAtOrigin(fillColor, outlineColor)
    local fill = resolveColor(fillColor, Theme.colors.accent)
    local outline = resolveColor(outlineColor, Theme.colors.text)

    Theme.setColor(fill)
    love.graphics.polygon("fill", 0, 0, 12, 12, 0, 15)

    Theme.setColor(outline)
    love.graphics.setLineWidth(1)
    love.graphics.polygon("line", 0, 0, 12, 12, 0, 15)
end

function SciFiCursor.draw(x, y, fillColor, outlineColor)
    love.graphics.push()
    love.graphics.translate(x, y)
    SciFiCursor.drawAtOrigin(fillColor, outlineColor)
    love.graphics.pop()
end

return SciFiCursor
