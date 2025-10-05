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

    targetRadius = targetRadius or CollisionHelpers.calculateEffectiveRadius(target)

    local health = components.health
    -- For players, always check shield collision first if they have any shield capacity
    -- This ensures remote projectiles properly detect shield hits even with stale shield data
    if health and (health.maxShield or 0) > 0 then
        local shieldRadius = Radius.getShieldRadius(target)
        return CollisionHelpers.calculateShieldHitPoint(x1, y1, x2, y2, ex, ey, shieldRadius)
    end

    local hasPolygon = collidable and collidable.vertices
    if hasPolygon and (collidable.shape == "polygon" or components.mineable) then
        local angle = position.angle or 0
        local wverts = CollisionHelpers.transformPolygon(ex, ey, angle, collidable.vertices)
        return CollisionHelpers.segPolygonHit(x1, y1, x2, y2, wverts)
    end

    return Physics.segCircleHit(x1, y1, x2, y2, ex, ey, targetRadius)
end

return CollisionHelpers
