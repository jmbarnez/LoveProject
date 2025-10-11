local RenderUtils = require("src.systems.render.utils")

local function render(entity, player)
    local props = entity.components.renderable.props or {}
    local v = props.visuals or {}
    local size = v.size or 1.0
    local S = RenderUtils.createScaler(size)

    -- Calculate actual station bounds
    local stationRadius = 0

    if type(v.shapes) == "table" and #v.shapes > 0 then
        -- Draw the detailed shapes from content definition
        for _, shape in ipairs(v.shapes) do
            RenderUtils.drawShape(shape, S)

            -- Calculate bounds for each shape
            if shape.type == "circle" then
                local shapeRadius = S(shape.r) + math.sqrt((shape.x or 0)^2 + (shape.y or 0)^2)
                stationRadius = math.max(stationRadius, shapeRadius)
            elseif shape.type == "rectangle" then
                local x, y, w, h = S(shape.x or 0), S(shape.y or 0), S(shape.w or 0), S(shape.h or 0)
                local corners = {
                    math.sqrt((x)^2 + (y)^2),
                    math.sqrt((x + w)^2 + (y)^2),
                    math.sqrt((x)^2 + (y + h)^2),
                    math.sqrt((x + w)^2 + (y + h)^2)
                }
                for _, corner in ipairs(corners) do
                    stationRadius = math.max(stationRadius, corner)
                end
            end
        end
    else
        -- Simple fallback station design
        local R = entity.radius or 200
        stationRadius = S(R * 0.8)

        -- Station outline only (glass panel effect removed)
        RenderUtils.setColor({0.85, 0.88, 0.90, 1.0})
        love.graphics.setLineWidth(S(2))
        love.graphics.circle("line", 0, 0, stationRadius)
        love.graphics.setLineWidth(1)
    end

    -- Draw station safe zone radius ring (faint until player is inside)
    -- This ring defines the actual safe zone radius for both docking and weapons
    local safeZoneRadius = (entity.weaponDisableRadius or (entity.radius or 50) * 1.5) * 2
    
    -- Calculate distance to player to determine ring opacity
    local ringAlpha = 0.1  -- Very faint by default
    if player and player.components and player.components.position then
        local playerPos = player.components.position
        local stationPos = entity.components.position
        if stationPos then
            local dx = playerPos.x - stationPos.x
            local dy = playerPos.y - stationPos.y
            local distance = math.sqrt(dx * dx + dy * dy)
            
            -- If player is inside the safe zone, make ring more visible
            if distance <= safeZoneRadius then
                ringAlpha = 0.6  -- Full visibility when inside
            end
        end
    end
    
    -- Draw ring with calculated opacity
    love.graphics.setColor(1.0, 0.5, 0.0, ringAlpha)  -- Orange with calculated transparency
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", 0, 0, safeZoneRadius)
    love.graphics.setLineWidth(1)
    
    -- Set the actual safe zone radius on the entity for other systems to use
    entity.actualSafeZoneRadius = safeZoneRadius
end

return render
