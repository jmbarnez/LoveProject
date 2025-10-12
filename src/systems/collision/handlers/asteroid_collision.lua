-- Asteroid Collision Handler
-- Handles collision resolution specific to asteroids and mineable entities

local PhysicsResolution = require("src.systems.collision.physics.physics_resolution")
local Sound = require("src.core.sound")

local AsteroidCollision = {}

-- Check if entity is an asteroid
function AsteroidCollision.isAsteroid(entity)
    return entity.components and entity.components.mineable and entity.components.collidable
end

-- Handle asteroid-to-asteroid collision
function AsteroidCollision.handleAsteroidToAsteroid(entity1, entity2, collision, dt)
    local e1Physics = entity1.components.physics and entity1.components.physics.body
    local e2Physics = entity2.components.physics and entity2.components.physics.body
    
    if not e1Physics or not e2Physics then return end
    
    -- Calculate relative velocity for realistic sound scaling
    local v1x, v1y = e1Physics.vx or 0, e1Physics.vy or 0
    local v2x, v2y = e2Physics.vx or 0, e2Physics.vy or 0
    local relativeVelX = v1x - v2x
    local relativeVelY = v1y - v2y
    local relativeSpeed = math.sqrt(relativeVelX * relativeVelX + relativeVelY * relativeVelY)
    
    -- Only play sound for significant impacts (speed > 50 units/sec)
    -- and implement cooldown to prevent spam
    local currentTime = love.timer.getTime()
    local lastCollisionTime = (entity1._lastAsteroidCollision or 0) + (entity2._lastAsteroidCollision or 0)
    local timeSinceLastCollision = currentTime - (lastCollisionTime / 2)
    
    if relativeSpeed > 50 and timeSinceLastCollision > 0.5 then
        local e1x = entity1.components.position.x
        local e1y = entity1.components.position.y
        local e2x = entity2.components.position.x
        local e2y = entity2.components.position.y
        
        local impactX = (e1x + e2x) / 2
        local impactY = (e1y + e2y) / 2
        
        -- Scale volume based on impact speed (0.1 to 0.8 range)
        local volumeScale = math.min(0.8, math.max(0.1, relativeSpeed / 200))
        Sound.triggerEventAt('impact_rock', impactX, impactY, volumeScale)
        
        -- Update collision timestamps
        entity1._lastAsteroidCollision = currentTime
        entity2._lastAsteroidCollision = currentTime
    end
    
    -- Use the physics body collision method for realistic bouncing
    e1Physics:collideWith(e2Physics, 0.6) -- 60% restitution for asteroid bouncing
end

-- Handle asteroid collision with other entities
function AsteroidCollision.handleAsteroidCollision(asteroid, other, collision, dt)
    if not AsteroidCollision.isAsteroid(asteroid) then return end
    
    -- If other entity is also an asteroid, use special handling
    if AsteroidCollision.isAsteroid(other) then
        AsteroidCollision.handleAsteroidToAsteroid(asteroid, other, collision, dt)
        return
    end
    
    -- For other entity types, use standard collision resolution
    local ShipCollision = require("src.systems.collision.handlers.ship_collision")
    ShipCollision.handleShipToShip(asteroid, other, collision, dt)
end

return AsteroidCollision
