--[[
    PhysicsSystem

    Handles physics simulation using Windfield as the primary physics engine.
    Manages entity physics bodies and provides integration with the ECS system.
    
    PHYSICS OWNERSHIP:
    - WindfieldManager: Owns all physics bodies and collision detection
    - PhysicsSystem: Orchestrates entity-specific physics (ships, asteroids, projectiles)
    - CollisionSystem: Manages entity lifecycle and broad-phase queries (quadtree)
    - Projectiles: Created by Projectiles.spawn() -> added to world -> physics body created by PhysicsSystem
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
    -- Always destroy the old manager first to prevent reinitialization issues
    if physicsManager then
        physicsManager:destroy()
        physicsManager = nil
    end
    
    physicsManager = WindfieldManager.new()
    Log.info("physics", "Physics system initialized with Windfield")
    return physicsManager
end

function PhysicsSystem.getManager()
    return physicsManager
end

function PhysicsSystem.update(dt, entities, world)
    if not physicsManager then
        PhysicsSystem.init()
    end

    -- Step the Windfield world (applies drag, syncs positions)
    -- Note: Ship forces are applied by PlayerSystem, not here to avoid double-updating
    physicsManager:update(dt)

    -- Post-step adjustments for other physics-driven entities
    for id, entity in pairs(entities) do
        if entity.components and entity.components.position then
            if entity.components.mineable then
                AsteroidPhysics.updateAsteroidPhysics(entity, physicsManager, dt)
            end
        end
    end
end

function PhysicsSystem.addEntity(entity)
    if not physicsManager then
        PhysicsSystem.init()
    end
    
    if not physicsManager then
        return nil
    end
    
    if not entity or not entity.components or not entity.components.position then
        return nil
    end
    
    -- For asteroids, we give them a random initial velocity.
    -- This is the only special logic required before adding them to the physics manager.
    if entity.components.mineable then
        local velX = (math.random() - 0.5) * 15
        local velY = (math.random() - 0.5) * 15
        -- We attach the velocity to the entity itself. The WindfieldManager will read it.
        entity._initialVelocity = { x = velX, y = velY }
    end
    
    -- For any entity that has a windfield_physics component, we add it to the physics world.
    -- This is the single, simple path for all physics objects.
    if entity.components.windfield_physics then
        return physicsManager:addEntity(entity)
    end
    
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

function PhysicsSystem.destroy()
    if physicsManager then
        physicsManager:destroy()
        physicsManager = nil
    end
end

return PhysicsSystem
