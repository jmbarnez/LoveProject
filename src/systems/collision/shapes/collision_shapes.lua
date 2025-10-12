-- Collision Shape Detection System
-- Handles detection and calculation of collision shapes for entities

local Radius = require("src.systems.collision.radius")
local Geometry = require("src.systems.collision.geometry")
local StationShields = require("src.systems.collision.station_shields")

local CollisionShapes = {}

-- Get the collision radius for an entity, properly handling polygon shapes
function CollisionShapes.getEntityCollisionRadius(entity)
    local collidable = entity.components and entity.components.collidable
    if not collidable then
        return 0
    end
    
    -- For polygon shapes, calculate radius from vertices only (not visual elements)
    if collidable.shape == "polygon" and collidable.vertices then
        local maxRadius = 0
        for i = 1, #collidable.vertices, 2 do
            local vx = collidable.vertices[i] or 0
            local vy = collidable.vertices[i + 1] or 0
            local distance = math.sqrt(vx * vx + vy * vy)
            if distance > maxRadius then
                maxRadius = distance
            end
        end
        return maxRadius
    end
    
    -- For circular shapes, use the radius directly
    if collidable.radius and collidable.radius > 0 then
        return collidable.radius
    end
    
    -- Fallback to hull radius for other entities
    return Radius.getHullRadius(entity)
end

-- Get the collision shape for an entity
function CollisionShapes.getCollisionShape(entity)
    local pos = entity.components.position

    -- Shields are always circular by design
    if StationShields.hasActiveShield(entity) then
        return {
            type = "circle",
            x = pos.x,
            y = pos.y,
            radius = Radius.getShieldRadius(entity)
        }
    end

    -- Check for polygon collision shape first (primary method)
    local collidable = entity.components and entity.components.collidable
    if collidable and collidable.shape == "polygon" and collidable.vertices then
        local pos = entity.components.position
        local angle = (pos and pos.angle) or 0
        local verts = Geometry.transformPolygon(pos.x, pos.y, angle, collidable.vertices)
        if verts and #verts >= 6 then  -- Ensure we have at least 3 vertices (6 coordinates)
            return { type = "polygon", vertices = verts }
        end
    end

    -- Only use circular collision for truly circular objects
    -- This includes: projectiles, small circular items, and objects explicitly marked as circular
    if collidable and collidable.shape == "circle" and collidable.radius then
        return {
            type = "circle",
            x = pos.x,
            y = pos.y,
            radius = collidable.radius
        }
    end

    -- For ships and other entities that require polygon shapes, check if they have them
    if entity.tag == "ship" or entity.tag == "enemy" or entity.tag == "asteroid" or 
       (entity.components and (entity.components.ship or entity.components.enemy or entity.components.mineable or entity.components.wreckage)) then
        -- These entities must have polygon collision shapes defined
        -- If no polygon shape is available, return nil (no collision)
        return nil
    end

    -- For stations, only use polygon shapes - no circular fallback
    if entity.tag == "station" or (entity.components and entity.components.station) then
        -- Stations must have polygon collision shapes - no circular fallback
        -- If no polygon shape is available, return nil (no collision)
        return nil
    end

    -- Only allow circular collision for projectiles and items that are explicitly circular
    if entity.components and entity.components.bullet then
        -- Projectiles can use circular collision
        return {
            type = "circle",
            x = pos.x,
            y = pos.y,
            radius = Radius.getHullRadius(entity)
        }
    end

    -- For all other entities without proper collision shapes, return nil (no collision)
    return nil
end

-- Get world polygon for an entity
function CollisionShapes.getWorldPolygon(entity)
    local collidable = entity.components and entity.components.collidable
    if not collidable or collidable.shape ~= "polygon" or not collidable.vertices then
        return nil
    end

    local pos = entity.components.position
    local angle = (pos and pos.angle) or 0
    return Geometry.transformPolygon(pos.x, pos.y, angle, collidable.vertices)
end

return CollisionShapes
