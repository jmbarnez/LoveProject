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

    -- Check if this is a utility beam (healing, mining, salvaging)
    local isUtilityBeam = false
    if projectile.components.bullet and projectile.components.bullet.kind then
        local kind = projectile.components.bullet.kind
        isUtilityBeam = (kind == "healing_laser" or kind == "mining_laser" or kind == "salvaging_laser")
    end

    -- For utility beams, allow friendly fire (healing can target allies)
    if isUtilityBeam then
        return false -- Don't ignore any targets for utility beams
    end

    -- For all other projectiles, prevent friendly fire
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

    -- Windfield handles all projectile collision detection automatically
    -- This function is kept for compatibility but always returns false
    -- since Windfield's collision callbacks handle the actual detection
    return false
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
