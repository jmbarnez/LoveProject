local RenderUtils = require("src.systems.render.utils")
local ResourceNodeBars = require("src.ui.hud.resource_node_bars")

local function render(entity, player)
    local props = entity.components.renderable.props or {}
    local ttl = (entity.components.timed_life and entity.components.timed_life.timer) or 1
    local alpha = math.max(0.2, math.min(1.0, ttl / 2.0))
    local frags = props.fragments

    -- Check if this wreckage is being hovered (cursor within range and can salvage)
    local isHovered = false
    local canSalvage = false
    if player and entity then
        local canSalvageCheck = (entity.canBeSalvaged and entity:canBeSalvaged())
          or (entity.salvageAmount and entity.salvageAmount > 0)
          or (entity.components and entity.components.lootable and #entity.components.lootable.drops > 0)
        if canSalvageCheck then
            canSalvage = true
            -- Check if cursor is hovering over this wreckage
            if player.cursorWorldPos then
                local wx, wy = entity.components.position.x, entity.components.position.y
                local cx, cy = player.cursorWorldPos.x, player.cursorWorldPos.y
                local dx, dy = cx - wx, cy - wy
                local dist = math.sqrt(dx*dx + dy*dy)
                local hoverRadius = (entity.components.collidable and entity.components.collidable.radius or 20) + 8
                isHovered = (dist <= hoverRadius)
            end
        end
    end

    if type(frags) == "table" and #frags > 0 then
        for _, s in ipairs(frags) do
            if s.type == 'polygon' and s.points then
                local baseAlpha = (type(s.color) == "table" and s.color[4]) or 1
                local a = baseAlpha * alpha
                RenderUtils.setColor(s.color, a)
                love.graphics.polygon(s.mode or 'fill', s.points)
            elseif (s.type == 'rect' or s.type == 'rectangle') then
                local baseAlpha = (type(s.color) == "table" and s.color[4]) or 1
                local a = baseAlpha * alpha
                RenderUtils.setColor(s.color, a)
                love.graphics.rectangle(s.mode or 'fill', s.x or -4, s.y or -4, s.w or 8, s.h or 8, s.rx or 1, s.ry or s.rx or 1)
            elseif s.type == 'circle' then
                local baseAlpha = (type(s.color) == "table" and s.color[4]) or 1
                local a = baseAlpha * alpha
                RenderUtils.setColor(s.color, a)
                love.graphics.circle(s.mode or 'fill', s.x or 0, s.y or 0, s.r or 3)
            elseif s.type == 'line' and s.points then
                local baseAlpha = (type(s.color) == "table" and s.color[4]) or 1
                local a = baseAlpha * alpha
                RenderUtils.setColor(s.color, a)
                love.graphics.line(s.points)
            end
        end
    else
        local size = (props.size or 1.0) * 6
        love.graphics.setColor(0.42, 0.45, 0.50, 0.7 * alpha)
        love.graphics.rectangle('fill', -size/2, -size/2, size, size, 2, 2)
        love.graphics.setColor(0.20, 0.22, 0.26, 0.6 * alpha)
        love.graphics.rectangle('line', -size/2, -size/2, size, size, 2, 2)
    end

    ResourceNodeBars.drawSalvageBar(entity, {
        isHovered = isHovered,
    })
    -- Remove hover glow for wreckage to match new system
    if false and isHovered and canSalvage then
        if type(frags) == "table" and #frags > 0 then
            -- Draw glow outline following the actual fragment shapes
            for _, s in ipairs(frags) do
                if s.type == 'polygon' and s.points then
                    -- Outer glow
                    RenderUtils.setColor({0.2, 1.0, 0.3, 0.3})
                    love.graphics.setLineWidth(4)
                    love.graphics.polygon("line", s.points)
                    -- Inner glow
                    RenderUtils.setColor({0.2, 1.0, 0.3, 0.15})
                    love.graphics.setLineWidth(2)
                    love.graphics.polygon("line", s.points)
                elseif (s.type == 'rect' or s.type == 'rectangle') then
                    -- Rectangle glow
                    RenderUtils.setColor({0.2, 1.0, 0.3, 0.3})
                    love.graphics.setLineWidth(3)
                    love.graphics.rectangle("line", s.x or -4, s.y or -4, s.w or 8, s.h or 8, s.rx or 1, s.ry or s.rx or 1)
                elseif s.type == 'circle' then
                    -- Circle glow
                    RenderUtils.setColor({0.2, 1.0, 0.3, 0.3})
                    love.graphics.setLineWidth(3)
                    love.graphics.circle("line", s.x or 0, s.y or 0, (s.r or 3) + 2)
                end
            end
        else
            -- Fallback for wreckage without fragments - use rectangle glow
            local size = (props.size or 1.0) * 6
            RenderUtils.setColor({0.2, 1.0, 0.3, 0.3})
            love.graphics.setLineWidth(3)
            love.graphics.rectangle('line', -size/2 - 2, -size/2 - 2, size + 4, size + 4, 3, 3)
        end
        love.graphics.setLineWidth(1)
    end
end

return render
