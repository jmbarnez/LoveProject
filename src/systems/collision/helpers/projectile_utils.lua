local Physics = require("src.core.physics")
local Geometry = require("src.systems.collision.geometry")
local Radius = require("src.systems.collision.radius")
local StationShields = require("src.systems.collision.station_shields")
local Log = require("src.core.log")

local ProjectileUtils = {}

-- Debug flag for projectile collision detection
local DEBUG_PROJECTILE_COLLISION = false

function ProjectileUtils.emit_event(projectile, event, payload)
    if not projectile or not projectile.components then return end
    local eventsComp = projectile.components.projectile_events
    local dispatcher = eventsComp and eventsComp.dispatcher
    if dispatcher then
        dispatcher:emit(event, payload)
    end
end

function ProjectileUtils.should_ignore_collision(projectile, target)
    if not projectile or not target or not projectile.components or not target.components then
        return true
    end

    local source = projectile.components.bullet and projectile.components.bullet.source
    if target == projectile or target == source then
        if target == source then
            Log.debug("Ignoring collision: target is source of projectile")
        end
        return true
    end

    local projectileComponent = projectile.components.bullet ~= nil
    local targetIsProjectile = target.components.bullet ~= nil
    if projectileComponent and targetIsProjectile then
        local targetSource = target.components.bullet and target.components.bullet.source
        if targetSource == source then
            return true
        end
        return false
    end

    local isFriendlyBullet = (projectile.components.collidable and projectile.components.collidable.friendly) or false
    if isFriendlyBullet then
        local isFriendlyEntity = target.isFreighter or target.isFriendly
        local isPlayerEntity = target.isPlayer or target.isRemotePlayer or (target.components and target.components.player)
        if isFriendlyEntity and not isPlayerEntity then
            return true
        end
    end

    return false
end

function ProjectileUtils.validate_target_radius(target_radius)
    if not target_radius or target_radius < 0 then
        Log.warn("Invalid target radius: " .. tostring(target_radius) .. ", defaulting to 10")
        return 10
    end
    return target_radius
end

function ProjectileUtils.perform_collision_check(x1, y1, x2, y2, target, target_radius, projectile_radius)
    if math.abs(x1 - x2) + math.abs(y1 - y2) < 0.01 then
        return false
    end

    if not target or not target.components then
        return false
    end

    local components = target.components
    local position = components.position or {}
    local ex, ey = position.x, position.y
    local collidable = components.collidable

    if not ex or not ey then
        return false
    end

    target_radius = ProjectileUtils.validate_target_radius(target_radius)
    projectile_radius = projectile_radius or 2.0 -- Default projectile radius

    local health = components.health
    if health and (health.shield or 0) > 0 then
        local shield_radius = Radius.getShieldRadius(target)
        local shield_hit, hx, hy = Geometry.calculateShieldHitPoint(x1, y1, x2, y2, ex, ey, shield_radius)
        if shield_hit then
            return shield_hit, hx, hy
        end
    end

    local hasPolygon = collidable and collidable.vertices
    if hasPolygon and (collidable.shape == "polygon" or components.mineable) then
        local angle = position.angle or 0
        local wverts = Geometry.transformPolygon(ex, ey, angle, collidable.vertices)
        local hit, hitX, hitY = Geometry.segPolygonHit(x1, y1, x2, y2, wverts)
        if hit then
            return hit, hitX, hitY
        end
    end

    -- Use circle-to-circle collision detection instead of line-segment to circle
    -- This prevents bullets from passing through enemies
    return ProjectileUtils.circleToCircleHit(x1, y1, x2, y2, ex, ey, target_radius, projectile_radius)
end

function ProjectileUtils.circleToCircleHit(x1, y1, x2, y2, cx, cy, target_radius, projectile_radius)
    projectile_radius = projectile_radius or 2.0 -- Default projectile radius
    
    -- Calculate the total radius (projectile + target)
    local total_radius = projectile_radius + target_radius
    
    -- Debug logging to help identify collision issues
    if DEBUG_PROJECTILE_COLLISION then
        local distance = math.sqrt((x2 - cx)^2 + (y2 - cy)^2)
        Log.debug(string.format("Projectile collision check: proj_radius=%.2f, target_radius=%.2f, total_radius=%.2f, distance=%.2f", 
            projectile_radius, target_radius, total_radius, distance))
    end
    
    -- Check if projectile is already overlapping with target at start position
    local start_distance = math.sqrt((x1 - cx)^2 + (y1 - cy)^2)
    if start_distance <= total_radius then
        return true, x1, y1, 0
    end
    
    -- Check if projectile is overlapping with target at end position
    local end_distance = math.sqrt((x2 - cx)^2 + (y2 - cy)^2)
    if end_distance <= total_radius then
        return true, x2, y2, 1
    end
    
    -- Use line-segment to circle collision with the combined radius
    -- This handles the case where the projectile passes through the target
    return Physics.segCircleHit(x1, y1, x2, y2, cx, cy, total_radius)
end

function ProjectileUtils.is_station_shield_hit(projectile, target)
    return StationShields.isStation(target)
        and not projectile.friendly
        and StationShields.hasActiveShield(target)
end

-- Function to enable/disable debug logging
function ProjectileUtils.setDebugEnabled(enabled)
    DEBUG_PROJECTILE_COLLISION = enabled
end

return ProjectileUtils
