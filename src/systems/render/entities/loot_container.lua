local RenderUtils = require("src.systems.render.utils")

local function render(entity, player)
    local r = (entity.components.collidable and entity.components.collidable.radius) or 18

    -- Check if player is hovering and can interact
    local isHovered = false
    local canInteract = false
    local playerDistance = math.huge

    if player and player.cursorWorldPos and entity.components.position then
        local cx, cy = player.cursorWorldPos.x, player.cursorWorldPos.y
        local ex, ey = entity.components.position.x, entity.components.position.y
        local dx, dy = cx - ex, cy - ey
        local cursorDist = math.sqrt(dx*dx + dy*dy)
        isHovered = (cursorDist <= r)

        -- Check player distance for interaction
        if player.components and player.components.position then
            local px, py = player.components.position.x, player.components.position.y
            local pdx, pdy = px - ex, py - ey
            playerDistance = math.sqrt(pdx*pdx + pdy*pdy)
            canInteract = (playerDistance <= 100)
        end
    end

    love.graphics.push()
    love.graphics.rotate(0.785) -- 45 degrees

    -- Main body (brighter when hovered)
    local bodyColor = isHovered and {0.4, 0.4, 0.45} or {0.3, 0.3, 0.35}
    RenderUtils.setColor(bodyColor)
    love.graphics.rectangle("fill", -r, -r, r * 2, r * 2)

    -- Border (golden when hovered and can interact, blue when just hovered)
    local borderColor = {0.2, 0.2, 0.25}
    if isHovered then
        if canInteract then
            borderColor = {0.8, 0.6, 0.2} -- Gold when can interact
        else
            borderColor = {0.4, 0.6, 0.8} -- Blue when too far
        end
    end
    RenderUtils.setColor(borderColor)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", -r, -r, r * 2, r * 2)

    -- Metal plate effect
    RenderUtils.setColor({0.25, 0.25, 0.3})
    love.graphics.rectangle("line", -r + 3, -r + 3, r * 2 - 6, r * 2 - 6)

    -- Corner rivets
    RenderUtils.setColor({0.1, 0.1, 0.15})
    love.graphics.circle("fill", -r + 4, -r + 4, 2)
    love.graphics.circle("fill", r - 4, -r + 4, 2)
    love.graphics.circle("fill", -r + 4, r - 4, 2)
    love.graphics.circle("fill", r - 4, r - 4, 2)

    love.graphics.pop()
    love.graphics.setLineWidth(1)

    -- Add glow effect when hovered
    if isHovered then
        local glowColor = canInteract and {0.8, 0.6, 0.2, 0.3} or {0.4, 0.6, 0.8, 0.3}
        RenderUtils.setColor(glowColor)
        love.graphics.circle("fill", 0, 0, r + 8)

        -- Outer glow ring
        local ringColor = canInteract and {0.8, 0.6, 0.2, 0.5} or {0.4, 0.6, 0.8, 0.5}
        RenderUtils.setColor(ringColor)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", 0, 0, r + 6)
        love.graphics.setLineWidth(1)
    end

    -- Helper text above the container
    if isHovered then
        local text = canInteract and "Click to open" or string.format("Move closer (%.0fm)", playerDistance - 100)
        local textColor = canInteract and {0.9, 0.7, 0.3, 1.0} or {0.6, 0.8, 1.0, 1.0}

        -- Set small font if available
        local oldFont = love.graphics.getFont()
        local Theme = require("src.core.theme")
        if Theme.fonts and Theme.fonts.small then
            love.graphics.setFont(Theme.fonts.small)
        end

        local font = love.graphics.getFont()
        local textWidth = font:getWidth(text)
        local textHeight = font:getHeight()
        local textX = -textWidth / 2
        local textY = -r - textHeight - 10

        -- Text background
        RenderUtils.setColor({0, 0, 0, 0.7})
        love.graphics.rectangle("fill", textX - 4, textY - 2, textWidth + 8, textHeight + 4, 2, 2)

        -- Text
        RenderUtils.setColor(textColor)
        love.graphics.print(text, textX, textY)

        if oldFont then love.graphics.setFont(oldFont) end
    end
end

return render
