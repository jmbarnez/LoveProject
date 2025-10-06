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

        -- Draw mining hotspots as half circles sticking out from asteroid edge
        if entity.components.mineable and entity.components.mineable.hotspots then
            local hotspots = entity.components.mineable.hotspots:getHotspots()
            local asteroidRadius = entity.components.collidable and entity.components.collidable.radius or 30

            for _, hotspot in ipairs(hotspots) do
                if hotspot.active then
                    -- Calculate pulsing effect
                    local pulse = 0.8 + 0.2 * math.sin(hotspot.pulsePhase)
                    local alpha = (hotspot.lifetime / hotspot.maxLifetime) * pulse

                    -- Calculate angle from asteroid center to hotspot
                    local dx = hotspot.x - entity.components.position.x
                    local dy = hotspot.y - entity.components.position.y
                    local angle = math.atan2(dy, dx)

                    -- Calculate half circle parameters based on stored hotspot position
                    local halfCircleRadius = hotspot.radius * pulse
                    local baseDistance = math.sqrt(dx * dx + dy * dy)
                    local desiredDistance = asteroidRadius + halfCircleRadius * 0.35
                    local distance = baseDistance
                    if distance <= 0 then
                        distance = desiredDistance
                    else
                        distance = math.max(distance, desiredDistance)
                    end

                    local halfCircleX = math.cos(angle) * distance
                    local halfCircleY = math.sin(angle) * distance

                    -- Draw half circle as a filled arc with vivid yellow glow
                    local glowColor = {1.0, 0.95, 0.35, alpha * 0.55}
                    RenderUtils.setColor(glowColor)
                    love.graphics.arc("fill", halfCircleX, halfCircleY, halfCircleRadius,
                                   angle - math.pi/2, angle + math.pi/2, 32)

                    -- Draw half circle border with a brighter rim
                    local borderColor = {1.0, 0.9, 0.2, alpha}
                    RenderUtils.setColor(borderColor)
                    love.graphics.setLineWidth(2)
                    love.graphics.arc("line", halfCircleX, halfCircleY, halfCircleRadius,
                                    angle - math.pi/2, angle + math.pi/2, 32)
                    love.graphics.setLineWidth(1)

                    -- Draw inner core as smaller half circle to sell the heat
                    local coreColor = {1.0, 0.98, 0.55, alpha * 0.85}
                    RenderUtils.setColor(coreColor)
                    local coreRadius = halfCircleRadius * 0.42
                    love.graphics.arc("fill", halfCircleX, halfCircleY, coreRadius,
                                   angle - math.pi/2, angle + math.pi/2, 32)
                end
            end
        end

        -- No hover glow ring; visible effects only when laser is cutting

        ResourceNodeBars.drawMiningBar(entity, {
            isHovered = isHovered,
        })
    end
end

return render
