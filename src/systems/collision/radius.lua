local Config = require("src.content.config")

local Radius = {}

local HIT_BUFFER = (Config.BULLET and Config.BULLET.HIT_BUFFER) or 1.5
local SHIELD_PADDING = 4
local DEFAULT_PLAYER_RADIUS = 12
local DEFAULT_ENTITY_RADIUS = 10

local function baseRadius(entity)
    local collidable = entity.components and entity.components.collidable
    if collidable and collidable.radius and collidable.radius > 0 then
        return collidable.radius
    end
    if entity.components and entity.components.player then
        return DEFAULT_PLAYER_RADIUS
    end
    return DEFAULT_ENTITY_RADIUS
end

local function extentFromVertices(vertices)
    local maxExtent = 0
    if not vertices then return maxExtent end

    if type(vertices[1]) == "table" then
        for _, vertex in ipairs(vertices) do
            local vx = vertex[1] or 0
            local vy = vertex[2] or 0
            local distance = math.sqrt(vx * vx + vy * vy)
            if distance > maxExtent then
                maxExtent = distance
            end
        end
        return maxExtent
    end

    for i = 1, #vertices, 2 do
        local vx = vertices[i] or 0
        local vy = vertices[i + 1] or 0
        local distance = math.sqrt(vx * vx + vy * vy)
        if distance > maxExtent then
            maxExtent = distance
        end
    end
    return maxExtent
end

local function shapeExtent(shape, size)
    if not shape then return 0 end
    size = size or 1.0

    if shape.type == "rectangle" then
        local right = (shape.x or 0) + (shape.w or 0)
        local left = (shape.x or 0)
        local top = (shape.y or 0)
        local bottom = (shape.y or 0) + (shape.h or 0)
        local corners = {
            math.sqrt(left * left + top * top),
            math.sqrt(right * right + top * top),
            math.sqrt(left * left + bottom * bottom),
            math.sqrt(right * right + bottom * bottom)
        }
        local m = 0
        for _, d in ipairs(corners) do
            m = math.max(m, d * size)
        end
        return m
    elseif shape.type == "polygon" and shape.points then
        local m = 0
        for i = 1, #shape.points, 2 do
            local px = shape.points[i] or 0
            local py = shape.points[i + 1] or 0
            m = math.max(m, math.sqrt(px * px + py * py) * size)
        end
        return m
    elseif shape.type == "circle" then
        local cx, cy = shape.x or 0, shape.y or 0
        local r = shape.r or shape.radius or 0
        return (math.sqrt(cx * cx + cy * cy) + r) * size
    elseif shape.type == "ellipse" then
        local cx, cy = shape.x or 0, shape.y or 0
        local rx, ry = shape.rx or 0, shape.ry or 0
        return (math.sqrt(cx * cx + cy * cy) + math.max(rx, ry)) * size
    end

    return 0
end

local function visualsShapes(visuals)
    if type(visuals) ~= "table" then
        return nil
    end
    if visuals.shapes then
        return visuals.shapes
    end
    return visuals
end

function Radius.computeVisualRadius(entity)
    local renderable = entity.components and entity.components.renderable
    if not renderable or not renderable.props then
        return 0
    end

    local visuals = renderable.props.visuals or {}
    local size = visuals.size or 1.0
    local maxExtent = 0

    if visuals.radius then
        maxExtent = math.max(maxExtent, visuals.radius * size)
    end
    if visuals.ringOuter then
        maxExtent = math.max(maxExtent, visuals.ringOuter * size)
    end

    local shapes = visualsShapes(visuals)
    if shapes and type(shapes) == "table" then
        for _, shape in ipairs(shapes) do
            maxExtent = math.max(maxExtent, shapeExtent(shape, size))
        end
    end

    -- Handle asteroid chunks (stored in renderable.props.chunks)
    if renderable.props.chunks and type(renderable.props.chunks) == "table" then
        for _, chunk in ipairs(renderable.props.chunks) do
            if chunk.shape == "ellipse" then
                local cx, cy = chunk.x or 0, chunk.y or 0
                local rx, ry = chunk.rx or 0, chunk.ry or 0
                local chunkExtent = math.sqrt(cx * cx + cy * cy) + math.max(rx, ry)
                maxExtent = math.max(maxExtent, chunkExtent * size)
            elseif chunk.shape == "circle" then
                local cx, cy = chunk.x or 0, chunk.y or 0
                local r = chunk.r or chunk.radius or 0
                local chunkExtent = math.sqrt(cx * cx + cy * cy) + r
                maxExtent = math.max(maxExtent, chunkExtent * size)
            end
        end
    end

    if renderable.props and renderable.props.vertices then
        maxExtent = math.max(maxExtent, extentFromVertices(renderable.props.vertices) * size)
    end

    if visuals.vertices then
        maxExtent = math.max(maxExtent, extentFromVertices(visuals.vertices) * size)
    end

    return maxExtent
end

function Radius.getHullRadius(entity)
    local radius = baseRadius(entity)
    local collidable = entity.components and entity.components.collidable

    if collidable and collidable.vertices then
        radius = math.max(radius, extentFromVertices(collidable.vertices))
    end

    -- For mineable entities (asteroids), prioritize visual radius since chunks extend beyond base radius
    if entity.components and entity.components.mineable then
        local visualRadius = Radius.computeVisualRadius(entity)
        radius = math.max(radius, visualRadius)
    else
        radius = math.max(radius, Radius.computeVisualRadius(entity))
    end

    return radius
end

function Radius.getShieldRadius(entity)
    local renderable = entity.components and entity.components.renderable
    if renderable and renderable.props and renderable.props.visuals then
        local visuals = renderable.props.visuals
        local size = visuals.size or 1.0
        if entity.shieldRadius and entity._shieldRadiusVisualSize == size then
            return entity.shieldRadius
        end
        local maxExtent = 0

        local shapes = visualsShapes(visuals)
        if shapes and type(shapes) == "table" then
            for _, shape in ipairs(shapes) do
                maxExtent = math.max(maxExtent, shapeExtent(shape, size))
            end
        end

        if maxExtent > 0 then
            local radius = math.max(Radius.getHullRadius(entity), maxExtent + SHIELD_PADDING)
            entity.shieldRadius = radius
            entity._shieldRadiusVisualSize = size
            return radius
        end
    end

    local base = baseRadius(entity)
    local fallback = math.max(base * 2, base + 12)
    entity.shieldRadius = fallback
    entity._shieldRadiusVisualSize = nil
    return fallback
end

function Radius.calculateEffectiveRadius(entity)
    local effective = Radius.getHullRadius(entity)
    local health = entity.components and entity.components.health
    -- For players, always use shield radius if they have shield capacity
    -- This ensures consistent collision detection for remote projectiles
    if health and (health.maxShield or 0) > 0 then
        effective = math.max(effective, Radius.getShieldRadius(entity))
    end
    return effective + HIT_BUFFER
end

function Radius.invalidateCache(entity, opts)
    opts = opts or {}
    entity._radiusCacheVersion = (entity._radiusCacheVersion or 0) + 1
    if opts.visual then
        entity._visualRadiusCacheVersion = (entity._visualRadiusCacheVersion or 0) + 1
    end
end

return Radius
