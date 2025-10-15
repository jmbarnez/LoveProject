--[[
    Legacy Projectile Collision Handler
    
    DEPRECATED: This module is kept for compatibility but functionality
    has been moved to the new modular projectile collision system.
    
    See: src/systems/collision/projectile_collision_handler.lua
]]

local ProjectileCollision = {}

-- Check if entity is a projectile
function ProjectileCollision.isProjectile(entity)
    return entity.components and entity.components.projectile
end

-- Check if projectile should ignore target
function ProjectileCollision.shouldIgnoreTarget(projectile, target, source)
    if target == source then
        return true
    end
    return false
end

-- Legacy function - no longer used
function ProjectileCollision.checkProjectileCollision(projectile, target, dt)
    return false
end

-- Legacy function - no longer used
function ProjectileCollision.handleProjectileCollision(projectile, target, dt, collision, hitX, hitY)
    -- Functionality moved to ProjectileCollisionHandler
end

return ProjectileCollision
