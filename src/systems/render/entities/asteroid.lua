local RenderUtils = require("src.systems.render.utils")
local ResourceNodeBars = require("src.ui.hud.resource_node_bars")

local function render(entity, player)
    local props = entity.components.renderable.props or {}
    local v = props.visuals or {}
    local colors = v.colors or {}
    local vertices = props.vertices

    -- Check if this asteroid is being hovered (cursor within range and has resources)
    local isHovered = false
    local canMine = false
    if player and entity.components and entity.components.mineable then
        local m = entity.components.mineable
        if (m.resources or 0) > 0 then
            canMine = true
            -- Check if cursor is hovering over this asteroid
            if player.cursorWorldPos then
                local ax, ay = entity.components.position.x, entity.components.position.y
                local cx, cy = player.cursorWorldPos.x, player.cursorWorldPos.y
                local dx, dy = cx - ax, cy - ay
                local dist = math.sqrt(dx*dx + dy*dy)
                local hoverRadius = (entity.components.collidable and entity.components.collidable.radius or 30) + 10
                isHovered = (dist <= hoverRadius)
            end
        end
    end

    if vertices and #vertices > 0 then
        -- Get color from content based on asteroid size/type
        local fillColor = colors[props.size] or colors.medium or {0.4, 0.4, 0.45, 1.0}
        local outlineColor = colors.outline or {0.2, 0.2, 0.2, 1.0}

        -- No hover-based color changes; rely on active beam effects only

        -- Unpack the nested vertex table for Love2D's polygon function
        local flatVertices = {}
        for _, vertex in ipairs(vertices) do
            table.insert(flatVertices, vertex[1])
            table.insert(flatVertices, vertex[2])
        end

        RenderUtils.setColor(fillColor)
        love.graphics.polygon("fill", flatVertices)

        RenderUtils.setColor(outlineColor)
        love.graphics.polygon("line", flatVertices)


        -- No hover glow ring; visible effects only when laser is cutting

        ResourceNodeBars.drawMiningBar(entity, {
            isHovered = isHovered,
        })
    end
end

return render
