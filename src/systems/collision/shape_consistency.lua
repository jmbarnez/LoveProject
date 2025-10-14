--[[
    Shape Consistency System
    
    Ensures that collision shapes always match visual shapes for precise collision detection.
    This implements the "Single Source of Truth" approach where visual shapes are the
    authoritative source for both rendering and collision detection.
]]

local Log = require("src.core.log")

local ShapeConsistency = {}

-- Extract collision data from visual shapes
function ShapeConsistency.extractCollisionFromVisual(entity)
    if not entity or not entity.visuals or not entity.visuals.shapes then
        return nil
    end
    
    local shapes = entity.visuals.shapes
    if #shapes == 0 then
        return nil
    end
    
    -- Use the first shape as the collision shape
    local primaryShape = shapes[1]
    
    if primaryShape.type == "polygon" and primaryShape.points then
        -- Convert points array to flat vertices array
        local vertices = {}
        -- Handle both coordinate pairs format and flat array format
        if #primaryShape.points > 0 and type(primaryShape.points[1]) == "table" then
            -- New format: array of coordinate pairs {x, y}
            for _, point in ipairs(primaryShape.points) do
                table.insert(vertices, point[1])
                table.insert(vertices, point[2])
            end
        else
            -- Old format: already flat array
            vertices = primaryShape.points
        end
        
        -- Validate vertex count for Box2D (max 8 vertices)
        local vertexCount = #vertices / 2
        if vertexCount > 8 then
            Log.warn("collision", "Polygon has %d vertices, Box2D limit is 8. Truncating to first 8 vertices.", vertexCount)
            -- Truncate to first 8 vertices (16 numbers)
            local truncatedVertices = {}
            for i = 1, math.min(16, #vertices) do
                table.insert(truncatedVertices, vertices[i])
            end
            vertices = truncatedVertices
        end
        
        Log.debug("collision", "Generated polygon with %d vertices for entity %s", #vertices / 2, entity.id or "unknown")
        
        return {
            shape = "polygon",
            vertices = vertices
        }
    elseif primaryShape.type == "circle" then
        return {
            shape = "circle",
            radius = primaryShape.r or 20
        }
    elseif primaryShape.type == "rectangle" then
        return {
            shape = "rectangle",
            width = primaryShape.w or 40,
            height = primaryShape.h or 40
        }
    end
    
    return nil
end

-- Ensure entity has consistent collision shapes derived from visual shapes
function ShapeConsistency.ensureConsistency(entity)
    if not entity then
        return false
    end
    
    local collisionData = ShapeConsistency.extractCollisionFromVisual(entity)
    if not collisionData then
        Log.debug("collision", "No visual shapes found for entity %s", entity.id or "unknown")
        return false
    end
    
    -- Update collidable component
    if not entity.components then
        entity.components = {}
    end
    
    if not entity.components.collidable then
        entity.components.collidable = {}
    end
    
    entity.components.collidable.shape = collisionData.shape
    if collisionData.vertices then
        entity.components.collidable.vertices = collisionData.vertices
    end
    if collisionData.radius then
        entity.components.collidable.radius = collisionData.radius
    end
    if collisionData.width then
        entity.components.collidable.width = collisionData.width
    end
    if collisionData.height then
        entity.components.collidable.height = collisionData.height
    end
    
    -- Update windfield_physics component
    if not entity.components.windfield_physics then
        entity.components.windfield_physics = {}
    end
    
    -- Preserve existing physics properties
    local existingPhysics = entity.components.windfield_physics
    local preservedMass = existingPhysics.mass
    local preservedRestitution = existingPhysics.restitution
    local preservedFriction = existingPhysics.friction
    local preservedFixedRotation = existingPhysics.fixedRotation
    local preservedBodyType = existingPhysics.bodyType
    
    entity.components.windfield_physics.colliderType = collisionData.shape
    if collisionData.vertices then
        entity.components.windfield_physics.vertices = collisionData.vertices
    end
    if collisionData.radius then
        entity.components.windfield_physics.radius = collisionData.radius
    end
    if collisionData.width then
        entity.components.windfield_physics.width = collisionData.width
    end
    if collisionData.height then
        entity.components.windfield_physics.height = collisionData.height
    end
    
    -- Restore preserved physics properties
    if preservedMass then
        entity.components.windfield_physics.mass = preservedMass
    end
    if preservedRestitution then
        entity.components.windfield_physics.restitution = preservedRestitution
    end
    if preservedFriction then
        entity.components.windfield_physics.friction = preservedFriction
    end
    if preservedFixedRotation ~= nil then
        entity.components.windfield_physics.fixedRotation = preservedFixedRotation
    end
    if preservedBodyType then
        entity.components.windfield_physics.bodyType = preservedBodyType
    end
    
    Log.debug("collision", "Ensured shape consistency for entity %s: %s", 
             entity.id or "unknown", collisionData.shape)
    
    return true
end

-- Process all entities in a world to ensure shape consistency
function ShapeConsistency.processWorld(world)
    if not world then
        return
    end
    
    local processed = 0
    local entities = world:get_entities_with_components("renderable")
    
    for _, entity in ipairs(entities) do
        if ShapeConsistency.ensureConsistency(entity) then
            processed = processed + 1
        end
    end
    
    Log.info("collision", "Processed %d entities for shape consistency", processed)
end

return ShapeConsistency
