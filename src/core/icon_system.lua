-- Unified Icon System
-- Provides consistent icon rendering across all UI components

local Theme = require("src.core.theme")
local Content = require("src.content.content")

local IconSystem = {}

-- Centralized turret icon drawing function
function IconSystem.drawTurretIcon(turretData, x, y, size, alpha)
    alpha = alpha or 1.0
    
    -- Extract turret info from either turret definition or turret data
    local kind = "gun"
    local tracerColor = Theme.colors.accent
    
    if turretData then
        if type(turretData) == "string" then
            -- It's a turret ID, get the definition
            local def = Content.getTurret(turretData)
            if def then
                kind = def.type or def.kind or "gun"
                tracerColor = (def.tracer and def.tracer.color) or Theme.colors.accent
            end
        else
            -- It's turret data object
            kind = turretData.type or turretData.kind or "gun"
            tracerColor = (turretData.tracer and turretData.tracer.color) or Theme.colors.accent
        end
    end
    
    local c = tracerColor
    local cx, cy = x + size*0.5, y + size*0.5
    
    -- Set alpha for all drawing
    local oldColor = {love.graphics.getColor()}
    love.graphics.setColor(1, 1, 1, alpha)
    
    if kind == 'mining_laser' then
        Theme.setColor(Theme.withAlpha(Theme.colors.bg3, alpha))
        love.graphics.rectangle('fill', x+8, cy-12, size-16, 24)
        Theme.setColor(Theme.withAlpha(c, alpha))
        love.graphics.rectangle('fill', cx-4, y+6, 8, size-12)
        Theme.setColor(Theme.withAlpha(c, alpha * 0.6))
        love.graphics.rectangle('fill', cx-5, y+5, 10, size-10)
        Theme.setColor(Theme.withAlpha(Theme.colors.warning, alpha))
        love.graphics.rectangle('fill', cx-4, y+6, 8, 6)
        Theme.setColor(Theme.withAlpha(Theme.colors.textSecondary, alpha))
        love.graphics.circle('fill', cx-6, cy+8, 2)
        love.graphics.circle('fill', cx, cy+10, 2)
        love.graphics.circle('fill', cx+6, cy+8, 2)
    elseif kind == 'laser' or kind == 'laser_mk1' then
        Theme.setColor(Theme.withAlpha(Theme.colors.bg3, alpha))
        love.graphics.rectangle('fill', x+10, cy-10, size-20, 20)
        Theme.setColor(Theme.withAlpha(c, alpha))
        love.graphics.rectangle('fill', cx-3, y+8, 6, size-16)
        Theme.setColor(Theme.withAlpha(c, alpha * 0.4))
        love.graphics.rectangle('fill', cx-4, y+7, 8, size-14)
        Theme.setColor(Theme.withAlpha(Theme.colors.highlight, alpha))
        love.graphics.rectangle('fill', cx-3, y+8, 6, 4)
    elseif kind == 'missile' or kind == 'rocket_mk1' then
        Theme.setColor(Theme.withAlpha(Theme.colors.textSecondary, alpha))
        love.graphics.ellipse('fill', cx, cy, 10, 16)
        Theme.setColor(Theme.withAlpha(Theme.colors.danger, alpha))
        love.graphics.polygon('fill', cx-12, cy+6, cx-4, cy+2, cx-4, cy+10)
        love.graphics.polygon('fill', cx-12, cy-6, cx-4, cy-2, cx-4, cy-10)
        Theme.setColor(Theme.withAlpha(c, alpha * 0.8))
        love.graphics.circle('fill', cx+10, cy, 3)
        Theme.setColor(Theme.withAlpha(Theme.colors.warning, alpha * 0.6))
        love.graphics.circle('fill', cx+10, cy, 5)
    elseif kind == 'salvaging_laser' then
        Theme.setColor(Theme.withAlpha(Theme.colors.bg3, alpha))
        love.graphics.rectangle('fill', x+8, cy-12, size-16, 24)
        Theme.setColor(Theme.withAlpha(c, alpha))
        love.graphics.rectangle('fill', cx-4, y+6, 8, size-12)
        Theme.setColor(Theme.withAlpha(c, alpha * 0.6))
        love.graphics.rectangle('fill', cx-5, y+5, 10, size-10)
        Theme.setColor(Theme.withAlpha(Theme.colors.success, alpha))
        love.graphics.rectangle('fill', cx-4, y+6, 8, 6)
        Theme.setColor(Theme.withAlpha(Theme.colors.textSecondary, alpha))
        love.graphics.circle('fill', cx-6, cy+8, 2)
        love.graphics.circle('fill', cx, cy+10, 2)
        love.graphics.circle('fill', cx+6, cy+8, 2)
    elseif kind == 'giant_cannon' then
        Theme.setColor(Theme.withAlpha(Theme.colors.bg3, alpha))
        love.graphics.rectangle('fill', x+6, cy-14, size-12, 28)
        Theme.setColor(Theme.withAlpha(c, alpha))
        love.graphics.rectangle('fill', cx-6, y+4, 12, size-8)
        Theme.setColor(Theme.withAlpha(c, alpha * 0.7))
        love.graphics.rectangle('fill', cx-7, y+3, 14, size-6)
        Theme.setColor(Theme.withAlpha(Theme.colors.danger, alpha))
        love.graphics.rectangle('fill', cx-6, y+4, 12, 8)
        Theme.setColor(Theme.withAlpha(Theme.colors.textSecondary, alpha))
        love.graphics.circle('fill', cx-8, cy+6, 2)
        love.graphics.circle('fill', cx, cy+8, 2)
        love.graphics.circle('fill', cx+8, cy+6, 2)
    else
        -- Default gun icon
        Theme.setColor(Theme.withAlpha(Theme.colors.textSecondary, alpha))
        love.graphics.rectangle('fill', cx-12, cy-8, 18, 16)
        Theme.setColor(Theme.withAlpha(c, alpha))
        love.graphics.rectangle('fill', cx+6, cy-3, 12, 6)
        Theme.setColor(Theme.withAlpha(c, alpha * 0.6))
        love.graphics.rectangle('fill', cx+5, cy-4, 14, 8)
        Theme.setColor(Theme.withAlpha(Theme.colors.highlight, alpha))
        love.graphics.rectangle('fill', cx+6, cy-3, 12, 2)
    end
    
    -- Restore original color
    love.graphics.setColor(oldColor)
end

-- Draw item icon (for non-turret items)
function IconSystem.drawItemIcon(itemData, x, y, size, alpha)
    alpha = alpha or 1.0
    
    -- If it has a pre-rendered icon, use that
    if itemData and itemData.icon and type(itemData.icon) == "userdata" then
        local oldColor = {love.graphics.getColor()}
        love.graphics.setColor(1, 1, 1, alpha)
        local img = itemData.icon
        local sx = size / img:getWidth()
        local sy = size / img:getHeight()
        love.graphics.draw(img, x, y, 0, sx, sy)
        love.graphics.setColor(oldColor)
        return true
    end
    
    -- Fallback: draw a simple placeholder
    local oldColor = {love.graphics.getColor()}
    Theme.setColor(Theme.withAlpha(Theme.colors.bg2, alpha))
    love.graphics.rectangle('fill', x, y, size, size)
    Theme.setColor(Theme.withAlpha(Theme.colors.text, alpha))
    love.graphics.rectangle('line', x, y, size, size)
    love.graphics.setColor(oldColor)
    return false
end

-- Get the appropriate icon for any item/turret
function IconSystem.getIcon(itemData, size)
    size = size or 64
    
    -- For turrets, we always use the procedural drawing
    if itemData and (itemData.type == "turret" or itemData.kind or itemData.damage) then
        return nil -- Signal to use drawTurretIcon
    end
    
    -- For items with pre-rendered icons, return the image
    if itemData and itemData.icon and type(itemData.icon) == "userdata" then
        return itemData.icon
    end
    
    return nil -- Signal to use fallback
end

return IconSystem
