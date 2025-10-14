--[[
    PhysicsSystem

    Handles physics simulation using Windfield as the primary physics engine.
    Manages entity physics bodies and provides integration with the ECS system.
]]

local WindfieldManager = require("src.systems.physics.windfield_manager")
local AsteroidPhysics = require("src.systems.physics.asteroid_physics")
local ShipPhysics = require("src.systems.physics.ship_physics")
-- ProjectilePhysics integrated into main physics system
local EventDispatcher = require("src.systems.projectile.event_dispatcher")
local Log = require("src.core.log")

local ProjectileEvents = EventDispatcher.EVENTS

local PhysicsSystem = {}

-- Global physics manager instance
local physicsManager = nil

function PhysicsSystem.init()
    if not physicsManager then
        physicsManager = WindfieldManager.new()
        Log.info("physics", "Physics system initialized with Windfield")
    end
    return physicsManager
end

function PhysicsSystem.getManager()
    return physicsManager
end

function PhysicsSystem.update(dt, entities, world)
    if not physicsManager then
        PhysicsSystem.init()
    end
    
    -- Update all physics bodies
    physicsManager:update(dt)
    
    -- Handle specific entity types
    for id, entity in pairs(entities) do
        if entity.components and entity.components.position then
            -- Windfield physics entities are handled by WindfieldManager:syncPositions()
            -- No need to sync here to avoid double syncing
            
            -- Handle asteroids
            if entity.components.mineable then
                AsteroidPhysics.updateAsteroidPhysics(entity, physicsManager, dt)
            end
            
            -- Handle ships (players and AI)
            if entity.isPlayer or entity.components.player then
                ShipPhysics.updateShipPhysics(entity, physicsManager, dt)
            end
            
            -- Handle projectiles
            if entity.components.bullet then
                PhysicsSystem.updateProjectilePhysics(entity, physicsManager, dt)
            end
        end
    end
    
end

function PhysicsSystem.addEntity(entity)
    Log.debug("physics", "PhysicsSystem.addEntity called for entity: %s", entity and entity.id or "nil")
    
    if not physicsManager then
        Log.debug("physics", "Physics manager not initialized, calling init()")
        PhysicsSystem.init()
    end
    
    if not physicsManager then
        Log.error("physics", "Physics manager still not initialized after init() call!")
        return nil
    end
    
    if not entity or not entity.components or not entity.components.position then
        Log.warn("physics", "Cannot add entity: missing entity, components, or position")
        return nil
    end
    
    -- Handle Windfield physics entities
    if entity.components.windfield_physics then
        Log.debug("physics", "Adding entity to Windfield physics system")
        return physicsManager:addEntity(entity)
    end
    
    -- Handle asteroids
    if entity.components.mineable then
        Log.debug("physics", "Adding asteroid to physics system")
        return AsteroidPhysics.createAsteroidCollider(entity, physicsManager)
    end
    
    -- Handle ships
    if entity.isPlayer or entity.components.player then
        Log.debug("physics", "Adding ship to physics system")
        return ShipPhysics.createShipCollider(entity, physicsManager)
    end
    
    -- Handle projectiles
    if entity.components.bullet then
        Log.debug("physics", "Adding projectile to physics system")
        return PhysicsSystem.createProjectileCollider(entity, physicsManager)
    end
    
    Log.debug("physics", "Entity does not match any physics category - no physics collider created")
    return nil
end

function PhysicsSystem.removeEntity(entity)
    if physicsManager then
        physicsManager:removeEntity(entity)
    end
end

function PhysicsSystem.applyForce(entity, fx, fy)
    if physicsManager then
        physicsManager:applyForce(entity, fx, fy)
    end
end

function PhysicsSystem.applyImpulse(entity, ix, iy)
    if physicsManager then
        physicsManager:applyImpulse(entity, ix, iy)
    end
end

function PhysicsSystem.setVelocity(entity, vx, vy)
    if physicsManager then
        physicsManager:setVelocity(entity, vx, vy)
    end
end

function PhysicsSystem.getVelocity(entity)
    if physicsManager then
        return physicsManager:getVelocity(entity)
    end
    return 0, 0
end

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

function PhysicsSystem.createProjectileCollider(projectile, windfieldManager)
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
        
        -- Check if initial velocity was applied
        if projectile._initialVelocity then
            Log.debug("physics", "Projectile has _initialVelocity: vx=%.2f, vy=%.2f", 
                     projectile._initialVelocity.x, projectile._initialVelocity.y)
        else
            Log.warn("physics", "Projectile missing _initialVelocity!")
        end
        
        -- Initial velocity is already set by WindfieldManager:addEntity()
        -- No need to set it again here
        
        return collider
    else
        Log.error("physics", "Failed to create projectile collider")
        return nil
    end
end

function PhysicsSystem.updateProjectilePhysics(projectile, windfieldManager, dt)
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

function PhysicsSystem.destroy()
    if physicsManager then
        physicsManager:destroy()
        physicsManager = nil
    end
end

return PhysicsSystem
