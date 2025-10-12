-- Projectile Collision Handler
-- Handles collision resolution specific to projectiles and bullets

local CollisionShapes = require("src.systems.collision.shapes.collision_shapes")
local Radius = require("src.systems.collision.radius")

local ProjectileCollision = {}

-- Check if entity is a projectile
function ProjectileCollision.isProjectile(entity)
    return entity.components and entity.components.bullet
end

-- Check if projectile should ignore target
function ProjectileCollision.shouldIgnoreTarget(projectile, target, source)
    if not projectile or not target or not projectile.components.bullet then
        return true
    end

    -- Don't hit the source
    if target == source then
        return true
    end

    -- Don't hit projectiles from the same source
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

-- Check projectile collision using line-segment detection
function ProjectileCollision.checkProjectileCollision(projectile, target, dt)
    if not ProjectileCollision.isProjectile(projectile) then
        return false
    end

    -- Use the same collision detection as laser beams for consistency
    local CollisionHelpers = require("src.systems.turret.collision_helpers")
    
    -- Calculate projectile trajectory
    local pos = projectile.components.position
    local vel = projectile.components.velocity or {x = 0, y = 0}
    
    -- Previous position (where projectile was last frame)
    local x1 = pos.x - ((vel.x or 0) * dt)
    local y1 = pos.y - ((vel.y or 0) * dt)
    
    -- Current position
    local x2 = pos.x
    local y2 = pos.y
    
    -- Use effective radius for all targets to include HIT_BUFFER
    local targetRadius = Radius.calculateEffectiveRadius(target)
    
    -- Use the same collision detection as laser beams (line-segment detection)
    local ProjectileUtils = require("src.systems.collision.helpers.projectile_utils")
    
    -- Get projectile radius from collidable component
    local projectileRadius = 2.0 -- Default radius
    local projectileCollidable = projectile.components.collidable
    if projectileCollidable and projectileCollidable.radius then
        projectileRadius = projectileCollidable.radius
    end
    
    return ProjectileUtils.perform_collision_check(x1, y1, x2, y2, target, targetRadius, projectileRadius)
end

-- Handle projectile-specific collision behavior
function ProjectileCollision.handleProjectileCollision(projectile, target, dt, collision, hitX, hitY)
    if not ProjectileCollision.isProjectile(projectile) then
        return
    end

    -- Get target radius for effects
    local targetRadius = Radius.calculateEffectiveRadius(target)

    -- Mark projectile as coming from unified collision system to prevent duplicate effects
    projectile._fromUnifiedCollision = true

    -- Process the hit using the unified collision system
    local world = projectile._world
    
    if world then
        local CollisionEffects = require("src.systems.collision.effects")
        local damage = projectile.components.damage and (projectile.components.damage.value or projectile.components.damage) or 1
        local source = projectile.components.bullet and projectile.components.bullet.source
        
        -- Check if target is also a projectile
        if target.components.bullet then
            -- Projectile vs projectile collision - both take damage
            local targetDamage = target.components.damage and (target.components.damage.value or target.components.damage) or 1
            
            -- Apply damage to both projectiles
            CollisionEffects.applyDamage(projectile, targetDamage, target.components.bullet.source)
            CollisionEffects.applyDamage(target, damage, source)
            
            -- Mark both projectiles as dead
            projectile.dead = true
            target.dead = true
        else
            -- Projectile vs non-projectile collision - only target takes damage
            CollisionEffects.applyDamage(target, damage, source)
            
            -- Mark projectile as dead
            projectile.dead = true
        end
    else
        -- Fallback: just mark projectile as dead
        projectile.dead = true
    end
end

return ProjectileCollision
