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
