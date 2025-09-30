local Config = require("src.content.config")

local Radius = {}

local function shapeExtent(shape, size)
    if not shape then return 0 end
    size = size or 1.0
    if shape.type == "rectangle" then
        local right = (shape.x or 0) + (shape.w or 0)
        local left = (shape.x or 0)
        local top = (shape.y or 0)
        local bottom = (shape.y or 0) + (shape.h or 0)
        local corners = {
            math.sqrt(left*left + top*top),
            math.sqrt(right*right + top*top),
            math.sqrt(left*left + bottom*bottom),
            math.sqrt(right*right + bottom*bottom)
        }
        local m = 0
        for _, d in ipairs(corners) do m = math.max(m, d * size) end
        return m
    elseif shape.type == "polygon" and shape.points then
        local m = 0
        for i = 1, #shape.points, 2 do
            local px, py = shape.points[i] or 0, shape.points[i+1] or 0
            m = math.max(m, math.sqrt(px*px + py*py) * size)
        end
        return m
    elseif shape.type == "circle" then
        local cx, cy = shape.x or 0, shape.y or 0
        local r = shape.r or shape.radius or 0
        return (math.sqrt(cx*cx + cy*cy) + r) * size
    elseif shape.type == "ellipse" then
        local cx, cy = shape.x or 0, shape.y or 0
        local rx, ry = shape.rx or 0, shape.ry or 0
        return (math.sqrt(cx*cx + cy*cy) + math.max(rx, ry)) * size
    end
    return 0
end

local function computeVisualRadius(entity)
    local renderable = entity.components.renderable
    if not renderable or not renderable.props or not renderable.props.visuals then
        return 0
    end
    local visuals = renderable.props.visuals
    local size = (visuals.size or 1.0)
    local maxExtent = 0

    -- Handle visuals as direct array of shapes (warp gates) or object with .shapes
    local shapes = visuals
    if type(visuals) == "table" and visuals.shapes then
        shapes = visuals.shapes
    end

    -- Check for explicit radius (e.g., planets)
    if visuals.radius then
        maxExtent = math.max(maxExtent, visuals.radius * size)
    end
    if visuals.ringOuter then
        maxExtent = math.max(maxExtent, visuals.ringOuter * size)
    end

    -- Compute from shapes if present (stations, asteroids, warp gates)
    if shapes and type(shapes) == "table" then
        for _, shape in ipairs(shapes) do
            if shape then
                maxExtent = math.max(maxExtent, shapeExtent(shape, size))
            end
        end
    end

    -- For asteroids with vertices (stored in props.vertices, not visuals.vertices)
    if renderable.props and renderable.props.vertices then
        for _, vertex in ipairs(renderable.props.vertices) do
            local vx, vy = vertex[1] or 0, vertex[2] or 0
            maxExtent = math.max(maxExtent, math.sqrt(vx*vx + vy*vy) * size)
        end
    end
    
    -- Also check visuals.vertices for other entities
    if visuals.vertices then
        for _, vertex in ipairs(visuals.vertices) do
            local vx, vy = vertex[1] or 0, vertex[2] or 0
            maxExtent = math.max(maxExtent, math.sqrt(vx*vx + vy*vy) * size)
        end
    end

    return maxExtent
end

local function computeShieldRadius(entity)
    local renderable = entity.components.renderable
    if renderable and renderable.props and renderable.props.visuals then
        local visuals = renderable.props.visuals
        local size = visuals.size or 1.0
        -- If cache matches current visuals.size, return cached value
        if entity.shieldRadius and entity._shieldRadiusVisualSize == size then
            return entity.shieldRadius
        end
        local maxExtent = 0
        if visuals.shapes and type(visuals.shapes) == "table" then
            for _, shape in ipairs(visuals.shapes) do
                maxExtent = math.max(maxExtent, shapeExtent(shape, size))
            end
        end
        if maxExtent > 0 then
            local r = maxExtent + 4 -- doubled padding for clearer shield collision margin
            entity.shieldRadius = r
            entity._shieldRadiusVisualSize = size
            return r
        end
    end
    local baseRadius = entity.components.collidable.radius or (entity.components.player and 12 or 10)
    return math.max(baseRadius * 2, baseRadius + 12)
end

local function computeHullRadius(entity)
    -- Use visuals to estimate true hull extent when shields are down
    local renderable = entity.components.renderable
    if renderable and renderable.props and renderable.props.visuals then
        local visuals = renderable.props.visuals
        local size = visuals.size or 1.0
        local maxExtent = 0
        if visuals.shapes and type(visuals.shapes) == "table" then
            for _, shape in ipairs(visuals.shapes) do
                maxExtent = math.max(maxExtent, shapeExtent(shape, size))
            end
        end
        if maxExtent > 0 then
            -- Hull radius approximates true model extent (no extra shield padding)
            local baseRadius = entity.components.collidable.radius or (entity.components.player and 12 or 10)
            return math.max(baseRadius, maxExtent)
        end
    end
    return entity.components.collidable.radius or (entity.components.player and 12 or 10)
end

function Radius.calculateEffectiveRadius(entity)
    local baseRadius = entity.components.collidable.radius or (entity.components.player and 12 or 10)
    local hitBuffer = (Config.BULLET and Config.BULLET.HIT_BUFFER) or 1.5

    if entity.components.mineable then
        -- For mineable entities (asteroids), use visual radius to ensure proper collision
        local visualRadius = computeVisualRadius(entity)
        local collidableRadius = entity.components.collidable.radius or baseRadius
        local effectiveRadius = math.max(visualRadius, collidableRadius)
        local finalRadius = effectiveRadius + hitBuffer
        print("Radius calculation for asteroid: visual=" .. visualRadius .. ", collidable=" .. collidableRadius .. ", effective=" .. effectiveRadius .. ", final=" .. finalRadius)
        return finalRadius
    end

    -- Compute visual radius for broad-phase culling (covers large renderables like planets/stations/asteroids)
    local visualRadius = computeVisualRadius(entity)
    local effectiveVisual = math.max(baseRadius, visualRadius)

    -- Use expanded, visually-accurate shield radius if entity has shields
    if entity.components.health and (entity.components.health.shield or 0) > 0 then
        local shieldRadius = computeShieldRadius(entity)
        return math.max(effectiveVisual, (shieldRadius > 0 and shieldRadius or baseRadius)) + hitBuffer
    else
        -- When shields are gone, collide against visual hull extent
        local hullRadius = computeHullRadius(entity)
        return math.max(effectiveVisual, (hullRadius > 0 and hullRadius or baseRadius)) + hitBuffer
    end
end

Radius.computeVisualRadius = computeVisualRadius
return Radius