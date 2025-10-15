--[[
    Projectile Physics Controller
    
    Handles all projectile-specific physics behavior.
    Ensures projectiles never bounce by controlling physics at the source.
    
    SINGLE RESPONSIBILITY: Projectile physics management
    MODULAR: Completely separate from other physics systems
]]

local WindfieldManager = require("src.systems.physics.windfield_manager")
local ProjectileCategories = require("src.systems.projectile.categories")
local Log = require("src.core.log")

local ProjectilePhysics = {}

-- Create projectile collider with category-specific physics configuration
function ProjectilePhysics.createCollider(projectile, x, y, options)
    local manager = WindfieldManager.getManager()
    if not manager then
        return nil
    end
    
    -- Get projectile kind and category
    local projectileKind = ProjectileCategories.getProjectileKind(projectile)
    local physicsConfig = ProjectileCategories.getPhysicsConfig(projectileKind)
    
    -- Apply category-specific physics settings
    local physicsOptions = {
        mass = options.mass or 1,
        restitution = physicsConfig.restitution,
        friction = physicsConfig.friction,
        fixedRotation = physicsConfig.fixedRotation,
        bodyType = physicsConfig.bodyType,
        colliderType = options.colliderType or "circle",
        radius = options.radius or 2,
        vertices = options.vertices
    }
    
    -- Create collider through WindfieldManager
    local collider = manager:addEntity(projectile, physicsOptions.colliderType, x, y, physicsOptions)
    
    -- Additional safety: Force zero restitution on the underlying fixture
    if collider and collider.fixture then
        if collider.fixture.setRestitution then
            collider.fixture:setRestitution(0)
        end
        if collider.fixture.setFriction then
            collider.fixture:setFriction(0)
        end
    end
    
    return collider
end

-- Handle projectile collision with immediate stop
function ProjectilePhysics.handleCollision(projectile, target, contact)
    local manager = WindfieldManager.getManager()
    if not manager then
        return
    end
    
    local collider = manager:getCollider(projectile)
    if not collider or collider:isDestroyed() then
        return
    end
    
    -- Immediately stop all projectile movement
    collider:setLinearVelocity(0, 0)
    collider:setAngularVelocity(0)
    
    -- Force zero restitution on contact
    if contact then
        if contact.setRestitution then
            contact:setRestitution(0)
        end
        if contact.setFriction then
            contact:setFriction(0)
        end
    end
    
    -- Mark projectile as handled to prevent duplicate processing
    projectile._physicsHandled = true
end

-- Check if entity is a projectile
function ProjectilePhysics.isProjectile(entity)
    return ProjectileCategories.isProjectile(entity)
end

-- Update projectile physics (called every frame)
function ProjectilePhysics.update(projectile, dt)
    if not ProjectilePhysics.isProjectile(projectile) then
        return
    end
    
    local manager = WindfieldManager.getManager()
    if not manager then
        return
    end
    
    local collider = manager:getCollider(projectile)
    if not collider or collider:isDestroyed() then
        return
    end
    
    -- Continuously ensure zero restitution
    collider:setRestitution(0)
    collider:setFriction(0)
    
    -- Ensure fixed rotation
    collider:setFixedRotation(true)
end

return ProjectilePhysics
