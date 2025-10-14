--[[
    Debug Collision Renderer
    
    Renders collision shapes as overlays to visualize collision boundaries.
    This helps ensure visual and collision shapes are perfectly aligned.
]]

local Log = require("src.core.log")

local DebugCollision = {}

-- Debug settings
local DEBUG_COLLISION_SHAPES = false
local DEBUG_COLLISION_COLOR = {1, 0, 0, 0.5}  -- Red with 50% alpha
local DEBUG_COLLISION_LINE_WIDTH = 2

-- Toggle debug collision visualization
function DebugCollision.toggle()
    DEBUG_COLLISION_SHAPES = not DEBUG_COLLISION_SHAPES
    Log.info("debug", "Collision shape visualization: %s", DEBUG_COLLISION_SHAPES and "ON" or "OFF")
end

-- Set debug collision visualization state
function DebugCollision.setEnabled(enabled)
    DEBUG_COLLISION_SHAPES = enabled
    Log.info("debug", "Collision shape visualization: %s", DEBUG_COLLISION_SHAPES and "ON" or "OFF")
end

-- Check if debug collision is enabled
function DebugCollision.isEnabled()
    return DEBUG_COLLISION_SHAPES
end

-- Render collision shape for an entity
function DebugCollision.renderEntityCollision(entity)
    if not DEBUG_COLLISION_SHAPES or not entity then
        return
    end
    
    local pos = entity.components and entity.components.position
    if not pos then
        return
    end
    
    local collidable = entity.components.collidable
    if not collidable then
        return
    end
    
    -- Save current graphics state
    local oldColor = {love.graphics.getColor()}
    local oldLineWidth = love.graphics.getLineWidth()
    
    -- Set debug color and line width
    love.graphics.setColor(DEBUG_COLLISION_COLOR)
    love.graphics.setLineWidth(DEBUG_COLLISION_LINE_WIDTH)
    
    -- Render based on collision shape type
    if collidable.shape == "polygon" and collidable.vertices then
        love.graphics.polygon("line", collidable.vertices)
    elseif collidable.shape == "circle" and collidable.radius then
        love.graphics.circle("line", pos.x, pos.y, collidable.radius)
    elseif collidable.shape == "rectangle" and collidable.width and collidable.height then
        local w, h = collidable.width, collidable.height
        love.graphics.rectangle("line", pos.x - w/2, pos.y - h/2, w, h)
    end
    
    -- Restore graphics state
    love.graphics.setColor(oldColor)
    love.graphics.setLineWidth(oldLineWidth)
end

-- Render collision shapes for all entities in a world
function DebugCollision.renderWorldCollisions(world)
    if not DEBUG_COLLISION_SHAPES or not world then
        return
    end
    
    local entities = world:get_entities_with_components("collidable", "position")
    for _, entity in ipairs(entities) do
        DebugCollision.renderEntityCollision(entity)
    end
end

-- Render collision shape for a specific entity type
function DebugCollision.renderEntityTypeCollisions(world, entityType)
    if not DEBUG_COLLISION_SHAPES or not world then
        return
    end
    
    local entities = world:get_entities_with_components("collidable", "position")
    for _, entity in ipairs(entities) do
        if entity.subtype == entityType or entity.id == entityType then
            DebugCollision.renderEntityCollision(entity)
        end
    end
end

return DebugCollision
