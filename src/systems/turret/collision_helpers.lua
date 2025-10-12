-- Collision detection helpers for turret systems
-- Reuses collision system modules to avoid duplication
local Geometry = require("src.systems.collision.geometry")
local Radius = require("src.systems.collision.radius")
local Physics = require("src.core.physics")

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
    local components = target.components or {}
    local position = components.position or {}
    local ex, ey = position.x, position.y
    local collidable = components.collidable

    if not ex or not ey then
        return false
    end

    if not targetRadius then
        if collidable and collidable.radius and collidable.radius > 0 then
            targetRadius = collidable.radius
        else
            targetRadius = CollisionHelpers.calculateEffectiveRadius(target)
        end
    end

    local health = components.health
    -- For players, check shield collision first if they have active shields
    -- This ensures remote projectiles properly detect shield hits even with stale shield data
    if health and (health.shield or 0) > 0 then
        local shieldRadius = Radius.getShieldRadius(target)
        local shield_hit, hx, hy = CollisionHelpers.calculateShieldHitPoint(x1, y1, x2, y2, ex, ey, shieldRadius)
        if shield_hit then
            return shield_hit, hx, hy, "shield"
        end
        -- If shield miss, continue to check hull collision
    end

    local hasPolygon = collidable and collidable.vertices
    if hasPolygon and (collidable.shape == "polygon" or components.mineable) then
        local angle = position.angle or 0
        local wverts = CollisionHelpers.transformPolygon(ex, ey, angle, collidable.vertices)
        -- Use more precise polygon collision detection
        local hit, hitX, hitY = CollisionHelpers.segPolygonHit(x1, y1, x2, y2, wverts)
        if hit then
            return hit, hitX, hitY, "hull"
        end
        
        -- For mineable entities (asteroids), only use polygon collision - no circular fallback
        -- This prevents mining lasers from hitting circular hitboxes that extend beyond the actual asteroid shape
        if components.mineable then
            return false
        end
    end

    -- Use more precise circular collision detection for non-mineable entities
    local hit, hitX, hitY = Physics.segCircleHit(x1, y1, x2, y2, ex, ey, targetRadius)
    if hit then
        return hit, hitX, hitY, "hull"
    end

    return false
end

return CollisionHelpers
