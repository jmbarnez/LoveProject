--[[
    PhysicsSystem

    Handles physics simulation using Windfield as the primary physics engine.
    Manages entity physics bodies and provides integration with the ECS system.
]]

local WindfieldManager = require("src.systems.physics.windfield_manager")
local AsteroidPhysics = require("src.systems.physics.asteroid_physics")
local ShipPhysics = require("src.systems.physics.ship_physics")
local ProjectilePhysics = require("src.systems.physics.projectile_physics")
local Log = require("src.core.log")

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
                ProjectilePhysics.updateProjectilePhysics(entity, physicsManager, dt)
            end
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

-- Legacy compatibility function
function PhysicsSystem.updateLegacy(dt, entities, world)
    for id, entity in pairs(entities) do
        -- Skip anything that does not follow the component schema; legacy
        -- objects occasionally sneak in during development tools.
        if entity.components and entity.components.position then
            local hasVel = entity.components.velocity ~= nil
            local hasPhysicsBody = entity.components.physics and entity.components.physics.body
            local isLaserBullet = false
            if entity.components.bullet and entity.components.renderable and entity.components.renderable.props then
                local k = entity.components.renderable.props.kind
                if k == 'laser' or k == 'salvaging_laser' or k == 'mining_laser' then isLaserBullet = true end
            end
            local wasPosX = entity.components.position.x
            local wasPosY = entity.components.position.y

            -- Integrate simple kinematics if we have velocity and no physics
            -- body. Laser-type bullets are treated as instantaneous beams, so
            -- we leave their position untouched and let the render system
            -- handle the visuals.
            if (hasVel and not hasPhysicsBody) and (not isLaserBullet) then
                -- Apply space drag to velocity-based entities
                local CorePhysics = require("src.core.physics")
                local dragCoeff = CorePhysics.constants.SPACE_DRAG_COEFFICIENT
                entity.components.velocity.x = (entity.components.velocity.x or 0) * dragCoeff
                entity.components.velocity.y = (entity.components.velocity.y or 0) * dragCoeff
                
                entity.components.position.x = (entity.components.position.x or 0) + (entity.components.velocity.x or 0) * dt
                entity.components.position.y = (entity.components.position.y or 0) + (entity.components.velocity.y or 0) * dt
            end

            -- Update physics component if present
            if entity.components.physics and entity.components.physics.update then
                entity.components.physics:update(dt)
                if entity.components.physics.body then
                    -- Sync position/angle from physics body. We still protect
                    -- laser bullets because some templates attach minimal
                    -- bodies for collision tests only.
                    if not isLaserBullet then
                        -- Always sync physics body position to entity position
                        -- This ensures collision-induced movements are properly reflected
                        local bodyX = entity.components.physics.body.x
                        local bodyY = entity.components.physics.body.y
                        local bodyAngle = entity.components.physics.body.angle
                        
                        if bodyX then
                            entity.components.position.x = bodyX
                        end
                        if bodyY then
                            entity.components.position.y = bodyY
                        end
                        if bodyAngle then
                            entity.components.position.angle = bodyAngle
                        end
                    end
                end
            end

            -- Debug: if this entity is a projectile/bullet, log any position change during physics update
            if entity.components.bullet then
            end

            local projectileEvents = entity.components.projectile_events
            if projectileEvents and projectileEvents.dispatcher then
                projectileEvents.dispatcher:emit(ProjectileEvents.UPDATE, {
                    projectile = entity,
                    dt = dt,
                    world = world,
                })
            end
        end
    end
end

return PhysicsSystem
