--[[
    Projectile Physics Factory
    
    Handles creation and management of projectile physics bodies using Windfield.
    Provides specialized projectile physics behavior and collision handling.
]]

local WindfieldManager = require("src.systems.physics.windfield_manager")
local Log = require("src.core.log")

local ProjectilePhysics = {}

-- Projectile physics constants
local PROJECTILE_CONSTANTS = {
    BULLET_MASS = 1,
    MISSILE_MASS = 5,
    LASER_MASS = 0.1,
    RESTITUTION = 0.1,
    FRICTION = 0.0,
    MAX_VELOCITY = 1000,
    LIFETIME = 5.0, -- seconds
}

function ProjectilePhysics.createProjectileCollider(projectile, windfieldManager)
    if not projectile or not projectile.components or not projectile.components.position then
        Log.warn("physics", "Cannot create projectile collider: missing position component")
        return nil
    end
    
    local pos = projectile.components.position
    local bullet = projectile.components.bullet
    local renderable = projectile.components.renderable
    
    if not bullet or not renderable then
        Log.warn("physics", "Cannot create projectile collider: missing bullet or renderable component")
        return nil
    end
    
    -- Determine projectile type and properties
    local projectileType = renderable.props.kind or "bullet"
    local mass = PROJECTILE_CONSTANTS.BULLET_MASS
    local radius = 2
    
    if projectileType == "missile" then
        mass = PROJECTILE_CONSTANTS.MISSILE_MASS
        radius = 4
    elseif projectileType == "laser" or projectileType == "mining_laser" or projectileType == "salvaging_laser" then
        mass = PROJECTILE_CONSTANTS.LASER_MASS
        radius = 1
    end
    
    -- Create physics options
    local options = {
        mass = mass,
        restitution = PROJECTILE_CONSTANTS.RESTITUTION,
        friction = PROJECTILE_CONSTANTS.FRICTION,
        fixedRotation = true, -- Projectiles don't rotate
        bodyType = "dynamic",
        colliderType = "circle",
        radius = radius,
    }
    
    -- Create collider
    local collider = windfieldManager:addEntity(projectile, "circle", pos.x, pos.y, options)
    
    if collider then
        Log.debug("physics", "Created projectile collider: %s (mass=%.1f, radius=%.1f)", 
                 projectileType, mass, radius)
        
        -- Set initial velocity based on bullet properties
        local speed = bullet.speed or 500
        local angle = pos.angle or 0
        local vx = math.cos(angle) * speed
        local vy = math.sin(angle) * speed
        
        windfieldManager:setVelocity(projectile, vx, vy)
        
        return collider
    else
        Log.error("physics", "Failed to create projectile collider")
        return nil
    end
end

function ProjectilePhysics.updateProjectilePhysics(projectile, windfieldManager, dt)
    if not projectile or not windfieldManager then return end
    
    local collider = windfieldManager.entities[projectile]
    if not collider or collider:isDestroyed() then return end
    
    local bullet = projectile.components.bullet
    if not bullet then return end
    
    -- Update lifetime
    bullet.lifetime = (bullet.lifetime or PROJECTILE_CONSTANTS.LIFETIME) - dt
    if bullet.lifetime <= 0 then
        -- Mark projectile for destruction
        projectile.dead = true
        return
    end
    
    -- Get current velocity
    local vx, vy = windfieldManager:getVelocity(projectile)
    local speed = math.sqrt(vx * vx + vy * vy)
    
    -- Cap maximum velocity
    if speed > PROJECTILE_CONSTANTS.MAX_VELOCITY then
        local ratio = PROJECTILE_CONSTANTS.MAX_VELOCITY / speed
        vx = vx * ratio
        vy = vy * ratio
        windfieldManager:setVelocity(projectile, vx, vy)
    end
end

function ProjectilePhysics.handleProjectileCollision(projectile, target, contact)
    -- Handle projectile hit
    Log.debug("physics", "Projectile hit: %s -> %s", 
             projectile.components.renderable.props.kind or "unknown", 
             target.subtype or "unknown")
    
    -- Mark projectile for destruction
    projectile.dead = true
    
    -- Add hit effects
    local CollisionEffects = require("src.systems.collision.effects")
    if CollisionEffects then
        local projPos = projectile.components.position
        local targetPos = target.components.position
        CollisionEffects.createCollisionEffects(projectile, target, 
                                               projPos.x, projPos.y, targetPos.x, targetPos.y, 
                                               0, 0, 2, 20, nil, nil)
    end
end

return ProjectilePhysics
