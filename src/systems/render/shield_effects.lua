-- Shield bubble visual effects
local ShieldEffects = {}

-- Calculate maximum extent of a shape from center
local function calculateShapeExtent(shape, size)
    if shape.type == "rectangle" then
        local rightEdge = (shape.x or 0) + (shape.w or 0)
        local leftEdge = (shape.x or 0)
        local topEdge = (shape.y or 0)
        local bottomEdge = (shape.y or 0) + (shape.h or 0)
        
        -- Calculate distance from center (0,0) to each corner
        local corners = {
            math.sqrt(leftEdge^2 + topEdge^2),
            math.sqrt(rightEdge^2 + topEdge^2),
            math.sqrt(leftEdge^2 + bottomEdge^2),
            math.sqrt(rightEdge^2 + bottomEdge^2)
        }
        
        local maxDist = 0
        for _, cornerDist in ipairs(corners) do
            maxDist = math.max(maxDist, cornerDist * size)
        end
        return maxDist
        
    elseif shape.type == "polygon" and shape.points then
        local maxDist = 0
        for i = 1, #shape.points, 2 do
            local px, py = shape.points[i] or 0, shape.points[i+1] or 0
            local dist = math.sqrt(px^2 + py^2) * size
            maxDist = math.max(maxDist, dist)
        end
        return maxDist
        
    elseif shape.type == "circle" then
        local cx, cy = shape.x or 0, shape.y or 0
        local radius = shape.r or shape.radius or 0
        return (math.sqrt(cx^2 + cy^2) + radius) * size
        
    elseif shape.type == "ellipse" then
        local cx, cy = shape.x or 0, shape.y or 0
        local rx, ry = shape.rx or 0, shape.ry or 0
        return (math.sqrt(cx^2 + cy^2) + math.max(rx, ry)) * size
    end
    
    return 0
end

-- Calculate shield radius based on ship dimensions and visuals
local function calculateShieldRadius(entity)
    if not entity or not entity.components then return 50 end
    local col = entity.components.collidable
    local r = (col and col.radius) or 0
    if r <= 0 then return 50 end
    
    -- Calculate proper shield radius based on ship dimensions
    local shieldRadius = r
    local renderable = entity.components.renderable
    
    if renderable and renderable.props and renderable.props.visuals then
        local visuals = renderable.props.visuals
        local size = visuals.size or 1.0
        
        -- Calculate the maximum extent of the ship from its center
        local maxExtent = 0
        if visuals.shapes and type(visuals.shapes) == "table" then
            -- Scan all ship shapes to find the maximum distance from center
            for _, shape in ipairs(visuals.shapes) do
                local extent = calculateShapeExtent(shape, size)
                maxExtent = math.max(maxExtent, extent)
            end
        end
        
        -- If we found ship shapes, use the calculated extent + padding
        if maxExtent > 0 then
            shieldRadius = maxExtent + 4  -- doubled padding to ensure clear separation from hull
        else
            -- Fallback for ships without detailed shapes
            local visualRadius = math.max(r, size * 32)
            shieldRadius = visualRadius + 4
        end
    else
        -- Fallback for entities without detailed visuals
        shieldRadius = math.max(r * 2, r + 15)
    end
    
    return shieldRadius
end

-- Draw shield bubble layers
local function drawShieldLayers(shieldRadius, pulse)
    -- Main shield bubble with better visibility
    love.graphics.setColor(0.2, 0.7, 1.0, 0.12 * pulse)
    love.graphics.circle('fill', 0, 0, shieldRadius)
    
    -- Multiple shield layers for full encirclement
    love.graphics.setLineWidth(1.5)
    love.graphics.setColor(0.4, 0.8, 1.0, 0.25 * pulse)
    love.graphics.circle('line', 0, 0, shieldRadius)
    
    love.graphics.setLineWidth(1)
    love.graphics.setColor(0.6, 0.9, 1.0, 0.35 * pulse)
    love.graphics.circle('line', 0, 0, shieldRadius + 3)
    
    love.graphics.setColor(0.3, 0.75, 1.0, 0.15 * pulse)
    love.graphics.circle('line', 0, 0, shieldRadius + 6)
    
    love.graphics.setLineWidth(1)
end

-- Draw a full shield bubble around the ship when in station bounds
function ShieldEffects.drawShieldBubble(entity)
    if not entity or not entity.components then return end
    if entity.tag == "station" then return end  -- No shields for stations
    
    local h = entity.components.health
    local col = entity.components.collidable
    
    -- Draw only on recent impact or special cases (channeling, disabled)
    local currentTime = love.timer.getTime()
    local hasRecentImpact = entity.shieldImpactTime and currentTime < entity.shieldImpactTime
    local isSpecialCase = entity.shieldChannel or entity.weaponsDisabled
    if not col then return end
    if not (hasRecentImpact or isSpecialCase) then return end
    
    local shieldRadius
    -- Recompute if visuals.size changed or cache missing
    local size = (entity.components and entity.components.renderable and entity.components.renderable.props and entity.components.renderable.props.visuals and entity.components.renderable.props.visuals.size) or 1.0
    if entity.shieldRadius and entity._shieldRadiusVisualSize == size then
        shieldRadius = entity.shieldRadius
    else
        shieldRadius = calculateShieldRadius(entity)
        entity.shieldRadius = shieldRadius
        entity._shieldRadiusVisualSize = size
    end
    
    local t = love.timer.getTime()
    local basePulse = 0.8 + 0.2 * math.sin(t * 2.5)
    -- Slightly stronger pulse when actively channeling
    local pulse = entity.shieldChannel and (basePulse + 0.15) or basePulse
    
    drawShieldLayers(shieldRadius, pulse)
end

return ShieldEffects
