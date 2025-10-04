-- Collision detection helpers for turret systems
-- Reuses collision system modules to avoid duplication
local Geometry = require("src.systems.collision.geometry")
local Radius = require("src.systems.collision.radius")

local CollisionHelpers = {}

-- Import geometry functions
CollisionHelpers.calculateShieldHitPoint = Geometry.calculateShieldHitPoint
CollisionHelpers.transformPolygon = Geometry.transformPolygon
CollisionHelpers.segPolygonHit = Geometry.segPolygonHit
CollisionHelpers.segIntersect = Geometry.segIntersect
CollisionHelpers.calculateEffectiveRadius = Radius.calculateEffectiveRadius

-- Compute beam muzzle offset for visual effects
function CollisionHelpers.getBeamMuzzleOffset(owner)
  -- Return 0 to start from ship center for better visual effect
  return 0
end

-- Perform collision check for turret projectiles/beams
function CollisionHelpers.performCollisionCheck(x1, y1, x2, y2, target, targetRadius)
    local ex, ey = target.components.position.x, target.components.position.y
    local collidable = target.components.collidable


    -- Shields always take priority - they're larger than the hull
    if target.components.health and target.components.health.shield > 0 then
        local Radius = require("src.systems.collision.radius")
        local shield_radius = Radius.getShieldRadius(target)
        return CollisionHelpers.calculateShieldHitPoint(x1, y1, x2, y2, ex, ey, shield_radius)
    end

    -- Check for polygon collision shape (hull collision)
    if collidable and collidable.shape == "polygon" and collidable.vertices then
        local angle = (target.components.position and target.components.position.angle)
        local wverts = CollisionHelpers.transformPolygon(ex, ey, angle, collidable.vertices)
        return CollisionHelpers.segPolygonHit(x1, y1, x2, y2, wverts)
    -- Legacy support for mineable objects with vertices
    elseif target.components.mineable and collidable and collidable.vertices then
        local angle = (target.components.position and target.components.position.angle)
        local wverts = CollisionHelpers.transformPolygon(ex, ey, angle, collidable.vertices)
        return CollisionHelpers.segPolygonHit(x1, y1, x2, y2, wverts)
    else
        -- Fallback to circular hull collision
        local Physics = require("src.core.physics")
        local hit, hx, hy = Physics.segCircleHit(x1, y1, x2, y2, ex, ey, targetRadius)
        if not hit then
            local dx, dy = (x2 - ex), (y2 - ey)
            hit = (dx*dx + dy*dy) <= targetRadius*targetRadius
            hx, hy = x2, y2
        end
        return hit, hx, hy
    end
end

return CollisionHelpers