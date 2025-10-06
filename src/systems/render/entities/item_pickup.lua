local Content = require("src.content.content")

local function render(entity, player)
    local props = entity.components.renderable.props or {}
    local itemId = props.itemId or "ore_tritanium"
    local qty = props.qty or 1
    local s = (props.sizeScale or 0.7) * 1.2  -- Slightly smaller than original (reduced from 1.5 to 1.2)

    -- Fetch item or turret definition for correct model
    local itemDef = Content.getItem(itemId) or Content.getTurret(itemId)
    local Theme = require("src.core.theme")
    local oldFont = love.graphics.getFont()
    if Theme.fonts and Theme.fonts.small then
        love.graphics.setFont(Theme.fonts.small)
    end

    -- Ensure consistent white color for no tint during movement
    love.graphics.setColor(1.0, 1.0, 1.0, 1.0)

    if itemDef and itemDef.icon then
        -- Render small icon
        local icon = itemDef.icon
        local iconW, iconH = icon:getDimensions()
        local scale = s * 0.18  -- Larger icon size for better visibility (increased from 0.12 to 0.18)
        local drawW = iconW * scale
        local drawH = iconH * scale
        love.graphics.draw(icon, -drawW/2, -drawH/2, 0, scale, scale)

        -- Label below: name and qty (smaller and crisper)
        local label = (itemDef.name or itemId) .. " x" .. qty
        local font = love.graphics.getFont()
        local textW = font:getWidth(label)
        local textH = font:getHeight()
        -- Scale down the text to fit better with smaller items
        local textScale = 0.6
        local scaledTextW = textW * textScale
        local scaledTextH = textH * textScale
        love.graphics.push()
        love.graphics.scale(textScale, textScale)
        -- Center the label under the icon (accounting for scaling)
        love.graphics.print(label, -textW/2, (drawH/2 + 2)/textScale)
        love.graphics.pop()
    else
        -- Fallback: simple circle with generic label
        local size = 2 * s
        love.graphics.setColor(0.7, 0.7, 0.8, 1.0)
        love.graphics.circle('fill', 0, 0, size)
        love.graphics.setColor(0.4, 0.4, 0.5, 1.0)
        love.graphics.setLineWidth(1)
        love.graphics.circle('line', 0, 0, size)

        -- Generic label (smaller and crisper)
        local label = "Item x" .. qty
        local font = love.graphics.getFont()
        local textW = font:getWidth(label)
        local textH = font:getHeight()
        love.graphics.setColor(1.0, 1.0, 1.0, 1.0)
        -- Scale down the text to fit better with smaller items
        local textScale = 0.6
        love.graphics.push()
        love.graphics.scale(textScale, textScale)
        -- Center the label under the circle (accounting for scaling)
        love.graphics.print(label, -textW/2, (size + 2)/textScale)
        love.graphics.pop()
    end

    if oldFont then
        love.graphics.setFont(oldFont)
    end
end

return render
