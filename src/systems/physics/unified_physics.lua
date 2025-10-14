--[[
  Unified Physics System
  
  A generalized physics system that handles all entities with physics bodies
  using the same collision resolution and momentum transfer logic.
  No more specialized collision handlers - everything uses the same physics rules.
]]

local PhysicsResolution = require("src.systems.collision.physics.physics_resolution")
local CollisionDetection = require("src.systems.collision.detection.collision_detection")
local CollisionEffects = require("src.systems.collision.effects")
local Constants = require("src.systems.collision.constants")

local UnifiedPhysics = {}

-- Check if an entity has a physics body and can participate in physics
function UnifiedPhysics.hasPhysicsBody(entity)
    return entity.components and 
           entity.components.physics and 
           entity.components.physics.body and
           entity.components.position
end

-- Check if an entity can move (has physics body or is a special movable type)
function UnifiedPhysics.canMove(entity)
    if not entity.components then return false end
    
    -- Primary check: has physics body
    if entity.components.physics and entity.components.physics.body then
        return true
    end
    
    -- Secondary checks for special cases
    local wreckage = entity.components.wreckage ~= nil
    local mineable = entity.components.mineable ~= nil -- Asteroids
    local isPlayer = entity.isPlayer or (entity.components and entity.components.player)
    local isRewardCrate = entity.subtype == "reward_crate"
    
    return wreckage or mineable or isPlayer or isRewardCrate
end

-- Get entity mass for physics calculations
function UnifiedPhysics.getEntityMass(entity)
    if not entity.components then return 1000 end
    
    local physics = entity.components.physics
    if physics and physics.body then
        local body = physics.body
        local mass = body.mass or physics.mass
        if not mass or mass <= 0 then
            local radius = body.radius or (entity.components.collidable and entity.components.collidable.radius) or 30
            mass = radius * 2
            body.mass = mass
        end
        physics.mass = mass
        return mass
    end
    
    -- Fallback mass based on entity type
    if entity.components.mineable then
        return 2000 -- Asteroids are heavy
    elseif entity.tag == "station" then
        return 10000 -- Stations are very heavy
    elseif entity.isPlayer then
        return 1000 -- Player ship
    else
        return 1000 -- Default mass
    end
end

-- Get restitution (bounciness) for an entity
function UnifiedPhysics.getRestitution(entity)
    if not entity.components then return 0.25 end
    
    -- Check for custom restitution
    if entity.components.physics and entity.components.physics.restitution then
        return entity.components.physics.restitution
    end
    
    -- Default restitution based on entity type
    if entity.components.mineable then
        return 0.1 -- Asteroids are not very bouncy
    elseif entity.tag == "station" then
        return 0.05 -- Stations are very solid
    elseif entity.isPlayer then
        return 0.3 -- Player ship has some bounce
    else
        return 0.25 -- Default bounce
    end
end

-- Calculate push distance based on collision type
function UnifiedPhysics.getPushDistance(entity1, entity2, overlap)
    local isStationCollision = (entity1.tag == "station" or entity2.tag == "station") or 
                               (entity1.components and entity1.components.station) or 
                               (entity2.components and entity2.components.station)
    
    local hasPolygon = (entity1.components and entity1.components.collidable and 
                       entity1.components.collidable.shape == "polygon") or
                      (entity2.components and entity2.components.collidable and 
                       entity2.components.collidable.shape == "polygon")
    
    local basePush = overlap * (hasPolygon and Constants.POLYGON_PUSH_NORMAL or Constants.CIRCLE_PUSH_NORMAL)
    
    if isStationCollision then
        return math.max(basePush, Constants.MIN_STATION_PUSH)
    end
    
    return basePush
end

-- Apply momentum transfer between two entities
function UnifiedPhysics.applyMomentumTransfer(entity1, entity2, nx, ny)
    local e1Physics = entity1.components.physics and entity1.components.physics.body
    local e2Physics = entity2.components.physics and entity2.components.physics.body
    
    if not e1Physics or not e2Physics then return end
    
    -- Calculate relative velocity along collision normal
    local relVx = e2Physics.vx - e1Physics.vx
    local relVy = e2Physics.vy - e1Physics.vy
    local relVelAlongNormal = relVx * nx + relVy * ny
    
    -- Only resolve collision if objects are approaching (not separating)
    if relVelAlongNormal < 0 then
        local mass1 = UnifiedPhysics.getEntityMass(entity1)
        local mass2 = UnifiedPhysics.getEntityMass(entity2)
        
        -- Calculate effective restitution
        local rest1 = UnifiedPhysics.getRestitution(entity1)
        local rest2 = UnifiedPhysics.getRestitution(entity2)
        local effectiveRestitution = math.sqrt(rest1 * rest2)
        
        -- Calculate impulse magnitude using standard collision response formula
        local impulse = -(1 + effectiveRestitution) * relVelAlongNormal
        impulse = impulse / (1/mass1 + 1/mass2)
        
        -- Apply impulse to both objects
        local impulseX = impulse * nx
        local impulseY = impulse * ny
        
        -- Store old velocities for debugging
        local oldV1x, oldV1y = e1Physics.vx, e1Physics.vy
        local oldV2x, oldV2y = e2Physics.vx, e2Physics.vy
        
        e1Physics.vx = e1Physics.vx - impulseX / mass1
        e1Physics.vy = e1Physics.vy - impulseY / mass1
        e2Physics.vx = e2Physics.vx + impulseX / mass2
        e2Physics.vy = e2Physics.vy + impulseY / mass2
        
        -- Debug: Log significant velocity changes for asteroids
        local isAsteroid1 = entity1.components and entity1.components.mineable
        local isAsteroid2 = entity2.components and entity2.components.mineable
        
        if isAsteroid1 or isAsteroid2 then
            local v1Change = math.sqrt((e1Physics.vx - oldV1x)^2 + (e1Physics.vy - oldV1y)^2)
            local v2Change = math.sqrt((e2Physics.vx - oldV2x)^2 + (e2Physics.vy - oldV2y)^2)
            
            if v1Change > 1 or v2Change > 1 then
                -- Debug logging disabled for performance
                -- print(string.format("Asteroid collision: Entity1 vx=%.2f->%.2f vy=%.2f->%.2f, Entity2 vx=%.2f->%.2f vy=%.2f->%.2f", 
                --     oldV1x, e1Physics.vx, oldV1y, e1Physics.vy,
                --     oldV2x, e2Physics.vx, oldV2y, e2Physics.vy))
            end
        end
    end
end

-- Handle collision between two entities using unified physics
function UnifiedPhysics.handleCollision(entity1, entity2, collision, dt)
    local nx = collision.normalX or 0
    local ny = collision.normalY or 0
    local overlap = collision.overlap or 0
    
    if overlap <= 0 then return end
    
    local e1CanMove = UnifiedPhysics.canMove(entity1)
    local e2CanMove = UnifiedPhysics.canMove(entity2)
    
    
    -- Calculate push distance
    local pushDistance = UnifiedPhysics.getPushDistance(entity1, entity2, overlap)
    
    -- Apply collision resolution based on what can move
    if e1CanMove and e2CanMove then
        -- Both entities can move - use momentum-based separation
        local mass1 = UnifiedPhysics.getEntityMass(entity1)
        local mass2 = UnifiedPhysics.getEntityMass(entity2)
        local totalMass = mass1 + mass2
        
        -- Calculate momentum-based push distances
        -- Heavier entity gets smaller push (correct physics)
        local push1 = pushDistance * (mass2 / totalMass)  -- Entity1 gets push based on entity2's mass
        local push2 = pushDistance * (mass1 / totalMass)  -- Entity2 gets push based on entity1's mass
        
        
        -- Apply separation - both entities get pushed away from each other
        PhysicsResolution.pushEntity(entity1, -nx * push1, -ny * push1, -nx, -ny, dt, UnifiedPhysics.getRestitution(entity1))
        PhysicsResolution.pushEntity(entity2, nx * push2, ny * push2, nx, ny, dt, UnifiedPhysics.getRestitution(entity2))
        
        -- Apply momentum transfer
        UnifiedPhysics.applyMomentumTransfer(entity1, entity2, nx, ny)
        
    elseif e1CanMove then
        -- Only entity1 can move - push it away from static entity2
        PhysicsResolution.pushEntity(entity1, -nx * pushDistance, -ny * pushDistance, -nx, -ny, dt, UnifiedPhysics.getRestitution(entity1))
        
    elseif e2CanMove then
        -- Only entity2 can move - push it away from static entity1
        PhysicsResolution.pushEntity(entity2, nx * pushDistance, ny * pushDistance, nx, ny, dt, UnifiedPhysics.getRestitution(entity2))
    end
    
    -- Create collision effects
    local e1Pos = entity1.components.position
    local e2Pos = entity2.components.position
    if e1Pos and e2Pos then
        local e1Radius = entity1.components.collidable and entity1.components.collidable.radius or 20
        local e2Radius = entity2.components.collidable and entity2.components.collidable.radius or 20
        
        CollisionEffects.createCollisionEffects(
            entity1, entity2, 
            e1Pos.x, e1Pos.y, e2Pos.x, e2Pos.y,
            nx, ny, e1Radius, e2Radius,
            collision.shape1, collision.shape2
        )
    end
end

-- Check and resolve collision between two entities
function UnifiedPhysics.checkAndResolveCollision(entity1, entity2, dt)
    if not UnifiedPhysics.hasPhysicsBody(entity1) and not UnifiedPhysics.hasPhysicsBody(entity2) then
        return false
    end
    
    local collided, collision = CollisionDetection.checkEntityCollision(entity1, entity2)
    if collided then
        UnifiedPhysics.handleCollision(entity1, entity2, collision, dt)
        return true
    end
    
    return false
end

return UnifiedPhysics
