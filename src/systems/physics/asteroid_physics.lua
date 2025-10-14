--[[
    Asteroid Physics Factory
    
    Handles creation and management of asteroid physics bodies using Windfield.
    Provides specialized asteroid physics behavior and collision handling.
]]

local WindfieldManager = require("src.systems.physics.windfield_manager")
local Util = require("src.core.util")
local Log = require("src.core.log")

local AsteroidPhysics = {}

-- Asteroid physics constants
local ASTEROID_CONSTANTS = {
    SMALL_MASS = 48,
    MEDIUM_MASS = 120,
    LARGE_MASS = 300,
    RESTITUTION = 0.3,
    FRICTION = 0.1,
    MIN_VELOCITY = 0.5,
    MAX_VELOCITY = 200,
}

function AsteroidPhysics.createAsteroidCollider(asteroid, windfieldManager)
    if not asteroid or not asteroid.components or not asteroid.components.position then
        Log.warn("physics", "Cannot create asteroid collider: missing position component")
        return nil
    end
    
    local pos = asteroid.components.position
    local renderable = asteroid.components.renderable
    local mineable = asteroid.components.mineable
    
    if not renderable or not mineable then
        Log.warn("physics", "Cannot create asteroid collider: missing renderable or mineable component")
        return nil
    end
    
    -- Determine asteroid size and mass
    local size = mineable.size or "small"
    local mass = ASTEROID_CONSTANTS.SMALL_MASS
    local radius = 24
    
    if size == "medium" then
        mass = ASTEROID_CONSTANTS.MEDIUM_MASS
        radius = 36
    elseif size == "large" then
        mass = ASTEROID_CONSTANTS.LARGE_MASS
        radius = 48
    end
    
    -- Get asteroid vertices for polygon collider
    local vertices = {}
    if renderable.props and renderable.props.vertices then
        vertices = renderable.props.vertices
    else
        -- Generate vertices if not present
        local geometry = Util.generateAsteroidGeometry(radius, renderable.props.chunkOptions or {})
        vertices = geometry.vertices
    end
    
    -- Flatten vertices for Windfield
    local flatVertices = {}
    for _, vertex in ipairs(vertices) do
        table.insert(flatVertices, vertex[1])
        table.insert(flatVertices, vertex[2])
    end
    
    -- Create physics options - use circle collider due to Box2D polygon vertex limit
    local options = {
        mass = mass,
        restitution = ASTEROID_CONSTANTS.RESTITUTION,
        friction = ASTEROID_CONSTANTS.FRICTION,
        fixedRotation = false,
        bodyType = "dynamic",
        colliderType = "circle",
        radius = radius,
    }
    
    -- Create collider
    local collider = windfieldManager:addEntity(asteroid, "circle", pos.x, pos.y, options)
    
    if collider then
        Log.debug("physics", "Created asteroid collider: %s (mass=%.1f, radius=%.1f)", 
                 size, mass, radius)
        
        -- Add initial random velocity
        local velX = (math.random() - 0.5) * 15
        local velY = (math.random() - 0.5) * 15
        windfieldManager:setVelocity(asteroid, velX, velY)
        
        return collider
    else
        Log.error("physics", "Failed to create asteroid collider")
        return nil
    end
end

function AsteroidPhysics.updateAsteroidPhysics(asteroid, windfieldManager, dt)
    if not asteroid or not windfieldManager then return end
    
    local collider = windfieldManager.entities[asteroid]
    if not collider or collider:isDestroyed() then return end
    
    -- Apply space drag and velocity limits
    local vx, vy = windfieldManager:getVelocity(asteroid)
    local speed = math.sqrt(vx * vx + vy * vy)
    
    if speed > 0 then
        -- Apply space drag
        vx = vx * 0.99995
        vy = vy * 0.99995
        
        -- Stop very slow movement
        local newSpeed = math.sqrt(vx * vx + vy * vy)
        if newSpeed < ASTEROID_CONSTANTS.MIN_VELOCITY then
            vx, vy = 0, 0
        end
        
        -- Cap maximum velocity
        if newSpeed > ASTEROID_CONSTANTS.MAX_VELOCITY then
            local ratio = ASTEROID_CONSTANTS.MAX_VELOCITY / newSpeed
            vx = vx * ratio
            vy = vy * ratio
        end
        
        windfieldManager:setVelocity(asteroid, vx, vy)
    end
end

function AsteroidPhysics.handleAsteroidCollision(asteroid1, asteroid2, contact)
    -- Windfield handles the physics automatically
    -- We can add custom effects here if needed
    
    Log.debug("physics", "Asteroid collision: %s vs %s", 
             asteroid1.subtype or "unknown", asteroid2.subtype or "unknown")
    
    -- Add collision effects, sounds, etc.
    local CollisionEffects = require("src.systems.collision.effects")
    if CollisionEffects then
        local pos1 = asteroid1.components.position
        local pos2 = asteroid2.components.position
        CollisionEffects.createCollisionEffects(asteroid1, asteroid2, 
                                               pos1.x, pos1.y, pos2.x, pos2.y, 
                                               0, 0, 20, 20, nil, nil)
    end
end

return AsteroidPhysics
