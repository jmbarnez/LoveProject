--[[
    Projectile Collision Handler
    
    Handles projectile collision detection and response.
    Completely separate from entity collision system.
    
    SINGLE RESPONSIBILITY: Projectile collision detection and response
    MODULAR: Independent collision handling for projectiles
]]

local ProjectilePhysics = require("src.systems.physics.projectile_physics")
local ProjectileCategories = require("src.systems.projectile.categories")
local CollisionEffects = require("src.systems.collision.effects")
local Radius = require("src.systems.collision.radius")
local Log = require("src.core.log")

local ProjectileCollisionHandler = {}

-- Handle projectile collision with target
function ProjectileCollisionHandler.handle(projectile, target, contact, hitX, hitY)
    if not ProjectilePhysics.isProjectile(projectile) then
        return
    end
    
    -- Prevent duplicate handling
    if projectile._collisionHandled then
        return
    end
    projectile._collisionHandled = true
    
    -- Stop projectile physics immediately and destroy it
    ProjectilePhysics.handleCollision(projectile, target, contact)
    
    -- Immediately destroy projectile to prevent bouncing
    projectile.dead = true
    
    -- Get collision position
    local collisionX = hitX or projectile.components.position.x
    local collisionY = hitY or projectile.components.position.y
    
    -- Get target radius for effects
    local targetRadius = Radius.calculateEffectiveRadius(target)
    
    -- Apply damage to target
    local damage = projectile.components.damage and projectile.components.damage.value or 1
    local source = projectile.components.projectile and projectile.components.projectile.source
    
    CollisionEffects.applyDamage(target, damage, source)
    
    -- Create collision effects
    local now = (love and love.timer and love.timer.getTime and love.timer.getTime()) or 0
    if CollisionEffects.canEmitCollisionFX(projectile, target, now) then
        local bulletRadius = Radius.getHullRadius(projectile) or 2
        
        CollisionEffects.createCollisionEffects(
            projectile, target, 
            collisionX, collisionY, collisionX, collisionY, 
            0, 0, bulletRadius, targetRadius, nil, nil
        )
    end
    
    -- Projectile already marked as dead above
end

-- Check if collision should be ignored
function ProjectileCollisionHandler.shouldIgnore(projectile, target)
    if not ProjectilePhysics.isProjectile(projectile) then
        return true
    end
    
    -- Ignore collision with source
    local source = projectile.components.projectile and projectile.components.projectile.source
    if target == source then
        return true
    end
    
    return false
end

return ProjectileCollisionHandler
