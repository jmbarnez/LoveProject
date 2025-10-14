--[[
    PhysicsSystem

    Handles physics simulation using Windfield as the primary physics engine.
    Manages entity physics bodies and provides integration with the ECS system.
]]

local WindfieldManager = require("src.systems.physics.windfield_manager")
local AsteroidPhysics = require("src.systems.physics.asteroid_physics")
local ShipPhysics = require("src.systems.physics.ship_physics")
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
            
            -- Projectiles are now handled entirely by Windfield physics system
            -- No additional processing needed
        end
    end
    
end

function PhysicsSystem.addEntity(entity)
    if not physicsManager then
        PhysicsSystem.init()
    end
    
    if not entity or not entity.components or not entity.components.position then
        return nil
    end
    
    -- Handle Windfield physics entities
    if entity.components.windfield_physics then
        return physicsManager:addEntity(entity)
    end
    
    -- Handle asteroids
    if entity.components.mineable then
        return AsteroidPhysics.createAsteroidCollider(entity, physicsManager)
    end
    
    -- Handle ships
    if entity.isPlayer or entity.components.player then
        return ShipPhysics.createShipCollider(entity, physicsManager)
    end
    
    -- Handle projectiles
    if entity.components.bullet then
        return ProjectilePhysics.createProjectileCollider(entity, physicsManager)
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
