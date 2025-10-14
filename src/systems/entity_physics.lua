--[[
    EntityPhysics
    
    Minimal system that automatically adds entities with windfield_physics components
    to the physics world. This replaces the complex CollisionSystem and PhysicsSystem wrappers.
    
    SINGLE RESPONSIBILITY: Add entities to physics world when they have windfield_physics component
]]

local WindfieldManager = require("src.systems.physics.windfield_manager")

local EntityPhysics = {}

-- Global physics manager instance
local physicsManager = nil

function EntityPhysics.init()
    if not physicsManager then
        physicsManager = WindfieldManager.new()
    end
    return physicsManager
end

function EntityPhysics.getManager()
    return physicsManager
end

function EntityPhysics.update(dt, entities, world)
    -- Initialize physics manager if needed
    if not physicsManager then
        physicsManager = WindfieldManager.new()
    end
    
    -- Update physics world
    physicsManager:update(dt)
    
    -- Process entities that need to be added to physics world
    for id, entity in pairs(entities) do
        if entity.components and entity.components.windfield_physics and entity.components.position then
            -- Only add if not already added
            if not entity._physicsAdded then
                -- Special handling for asteroids (add initial velocity)
                if entity.components.mineable then
                    local velX = (math.random() - 0.5) * 15
                    local velY = (math.random() - 0.5) * 15
                    entity._initialVelocity = { x = velX, y = velY }
                end
                
                -- Add to physics world
                physicsManager:addEntity(entity)
                entity._physicsAdded = true
            end
        end
    end
end

function EntityPhysics.addEntity(entity)
    if not physicsManager then
        physicsManager = WindfieldManager.new()
    end
    
    if entity and entity.components and entity.components.windfield_physics and entity.components.position then
        -- Special handling for asteroids
        if entity.components.mineable then
            local velX = (math.random() - 0.5) * 15
            local velY = (math.random() - 0.5) * 15
            entity._initialVelocity = { x = velX, y = velY }
        end
        
        physicsManager:addEntity(entity)
        entity._physicsAdded = true
        return true
    end
    
    return false
end

function EntityPhysics.removeEntity(entity)
    if physicsManager then
        physicsManager:removeEntity(entity)
        if entity then
            entity._physicsAdded = false
        end
    end
end

function EntityPhysics.destroy()
    if physicsManager then
        physicsManager:destroy()
        physicsManager = nil
    end
end

return EntityPhysics
