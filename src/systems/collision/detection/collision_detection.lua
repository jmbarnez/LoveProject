-- Collision Detection System
-- Handles core collision detection algorithms between different shape types

local Geometry = require("src.systems.collision.geometry")
local CollisionShapes = require("src.systems.collision.shapes.collision_shapes")

local CollisionDetection = {}

-- Check collision between two entities
function CollisionDetection.checkEntityCollision(entity1, entity2)
    local shape1 = CollisionShapes.getCollisionShape(entity1)
    local shape2 = CollisionShapes.getCollisionShape(entity2)

    if not shape1 or not shape2 then
        return false
    end

    -- Enhanced collision detection for more precision
    if shape1.type == "polygon" and shape2.type == "polygon" then
        local collided, overlap, nx, ny = Geometry.polygonPolygonMTV(shape1.vertices, shape2.vertices)
        if not collided then
            return false
        end
        return true, { overlap = overlap, normalX = nx, normalY = ny, shape1 = shape1, shape2 = shape2 }
    elseif shape1.type == "polygon" and shape2.type == "circle" then
        local collided, overlap, nx, ny = Geometry.polygonCircleMTV(shape1.vertices, shape2.x, shape2.y, shape2.radius)
        if not collided then
            return false
        end
        return true, { overlap = overlap, normalX = nx, normalY = ny, shape1 = shape1, shape2 = shape2 }
    elseif shape1.type == "circle" and shape2.type == "polygon" then
        local collided, overlap, nx, ny = Geometry.polygonCircleMTV(shape2.vertices, shape1.x, shape1.y, shape1.radius)
        if not collided then
            return false
        end
        return true, { overlap = overlap, normalX = -nx, normalY = -ny, shape1 = shape1, shape2 = shape2 }
    else
        local dx = shape2.x - shape1.x
        local dy = shape2.y - shape1.y
        local distanceSq = dx * dx + dy * dy
        local minDistance = shape1.radius + shape2.radius
        
        -- Use more precise collision detection for circular shapes
        if distanceSq < (minDistance * minDistance) then
            local distance = math.sqrt(distanceSq)
            local nx, ny
            if distance > 0.001 then  -- More precise threshold to avoid division by very small numbers
                nx = dx / distance  -- Normal points from shape1 to shape2 (entity1 to entity2)
                ny = dy / distance
            else
                nx, ny = 1, 0  -- Default normal when entities are at same position
                distance = 0  -- Don't override distance, keep it 0 for proper overlap calculation
            end
            return true, { overlap = (minDistance - distance), normalX = nx, normalY = ny, shape1 = shape1, shape2 = shape2 }
        end
        return false
    end
end

-- Check if two entities are colliding (simple boolean check)
function CollisionDetection.areColliding(entity1, entity2)
    local collided, _ = CollisionDetection.checkEntityCollision(entity1, entity2)
    return collided
end

-- Get collision data between two entities
function CollisionDetection.getCollisionData(entity1, entity2)
    return CollisionDetection.checkEntityCollision(entity1, entity2)
end

return CollisionDetection
