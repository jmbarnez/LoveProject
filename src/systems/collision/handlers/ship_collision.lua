-- Ship Collision Handler
-- Handles collision resolution specific to ships and ship-like entities

local PhysicsResolution = require("src.systems.collision.physics.physics_resolution")
local CollisionShapes = require("src.systems.collision.shapes.collision_shapes")

local ShipCollision = {}

-- Check if entity is a ship-like entity
function ShipCollision.isShip(entity)
    return entity.isPlayer or 
           entity.components.player or 
           entity.components.ai or 
           entity.tag == "ship" or 
           entity.tag == "enemy" or
           entity.components.ship
end

-- Check if entity can move
function ShipCollision.canMove(entity)
    local physics = entity.components.physics and entity.components.physics.body
    local wreckage = entity.components.wreckage ~= nil
    return physics or ShipCollision.isShip(entity) or wreckage
end

-- Handle ship-to-ship collision
function ShipCollision.handleShipToShip(entity1, entity2, collision, dt)
    local nx = collision.normalX or 0
    local ny = collision.normalY or 0
    local overlap = collision.overlap or 0
    
    if overlap <= 0 then return end
    
    local e1CanMove = ShipCollision.canMove(entity1)
    local e2CanMove = ShipCollision.canMove(entity2)
    
    -- Get restitution values
    local e1Rest, e2Rest = PhysicsResolution.getRestitution(entity1, entity2)
    
    -- Calculate push distances based on collision type
    local isStationCollision = (entity1.tag == "station" or entity2.tag == "station") or 
                               (entity1.components and entity1.components.station) or 
                               (entity2.components and entity2.components.station)
    
    local e1HasPolygon = entity1.components and entity1.components.collidable and 
                        entity1.components.collidable.shape == "polygon"
    local e2HasPolygon = entity2.components and entity2.components.collidable and 
                        entity2.components.collidable.shape == "polygon"
    
    local pushDistance
    if e1HasPolygon or e2HasPolygon then
        pushDistance = overlap * (isStationCollision and 0.3 or 0.2)
    else
        pushDistance = overlap * (isStationCollision and 0.25 or 0.15)
    end
    
    if isStationCollision then
        pushDistance = math.max(pushDistance, 1)
    end
    
    -- Enhanced momentum-based collision resolution
    if e1CanMove and e2CanMove then
        -- Both entities can move - use proper momentum transfer
        local mass1 = PhysicsResolution.getEntityMass(entity1)
        local mass2 = PhysicsResolution.getEntityMass(entity2)
        local totalMass = mass1 + mass2
        
        -- Calculate momentum-based push distances
        local push1 = pushDistance * (mass2 / totalMass)
        local push2 = pushDistance * (mass1 / totalMass)
        
        -- Apply separation with momentum preservation
        PhysicsResolution.pushEntity(entity1, -nx * push1, -ny * push1, -nx, -ny, dt, e1Rest)
        PhysicsResolution.pushEntity(entity2, nx * push2, ny * push2, nx, ny, dt, e2Rest)
        
        -- Collision damage has been removed for simplified physics
        
        -- Apply momentum transfer between moving entities
        ShipCollision.applyMomentumTransfer(entity1, entity2, nx, ny, e1Rest, e2Rest)
    elseif e1CanMove then
        -- Only entity1 can move - push it away from static entity2
        PhysicsResolution.pushEntity(entity1, -nx * overlap, -ny * overlap, -nx, -ny, dt, e1Rest)
    elseif e2CanMove then
        -- Only entity2 can move - push it away from static entity1
        PhysicsResolution.pushEntity(entity2, nx * overlap, ny * overlap, nx, ny, dt, e2Rest)
    end
end

-- Apply momentum transfer between two moving entities
function ShipCollision.applyMomentumTransfer(entity1, entity2, nx, ny, e1Rest, e2Rest)
    local e1Physics = entity1.components.physics and entity1.components.physics.body
    local e2Physics = entity2.components.physics and entity2.components.physics.body
    
    if e1Physics and e2Physics then
        -- Calculate relative velocity
        local relVx = e2Physics.vx - e1Physics.vx
        local relVy = e2Physics.vy - e1Physics.vy
        local relVelAlongNormal = relVx * nx + relVy * ny
        
        -- Don't resolve if velocities are separating
        if relVelAlongNormal < 0 then
            local mass1 = PhysicsResolution.getEntityMass(entity1)
            local mass2 = PhysicsResolution.getEntityMass(entity2)
            
            -- Calculate impulse magnitude for natural momentum transfer
            local impulse = -(1 + math.min(e1Rest, e2Rest)) * relVelAlongNormal
            impulse = impulse / (1/mass1 + 1/mass2)
            
            -- Apply impulse
            local impulseX = impulse * nx
            local impulseY = impulse * ny
            
            e1Physics.vx = e1Physics.vx - impulseX / mass1
            e1Physics.vy = e1Physics.vy - impulseY / mass1
            e2Physics.vx = e2Physics.vx + impulseX / mass2
            e2Physics.vy = e2Physics.vy + impulseY / mass2
        end
    end
end

-- Handle ship pushing debris
function ShipCollision.handleShipDebrisPush(player, debris, collision, nx, ny, overlap)
    local playerBody = player.components.physics and player.components.physics.body
    local debrisBody = debris.components.physics and debris.components.physics.body
    
    if not playerBody or not debrisBody then return end
    
    local playerVx, playerVy = playerBody.vx, playerBody.vy
    local playerSpeed = math.sqrt(playerVx * playerVx + playerVy * playerVy)
    
    -- Apply momentum even at low speeds for better responsiveness
    if playerSpeed > 0.5 then
        -- Calculate collision normal for directional pushing
        local normalX = nx or 0
        local normalY = ny or 0
        
        -- Calculate velocity component along collision normal
        local velocityAlongNormal = playerVx * normalX + playerVy * normalY
        
        -- Apply momentum transfer in the direction of player movement
        local baseTransfer = 1.2 -- Increased for more responsive pushing
        
        -- Scale by collision overlap for more realistic physics
        local overlapFactor = math.min(1.0, (overlap or 0) / 2.0)
        
        -- Scale by player speed for more dynamic pushing
        local speedFactor = math.min(2.5, playerSpeed / 30.0)
        
        -- Mass ratio consideration (heavier debris is harder to push)
        local playerMass = playerBody.mass or 500
        local debrisMass = debrisBody.mass or 60
        local massRatio = playerMass / debrisMass
        local massFactor = math.min(2.0, massRatio / 1.5)
        
        -- Calculate final transfer rate
        local finalTransfer = baseTransfer * overlapFactor * speedFactor * massFactor
        
        -- Apply momentum transfer in the direction of player movement
        debrisBody.vx = (debrisBody.vx or 0) + playerVx * finalTransfer
        debrisBody.vy = (debrisBody.vy or 0) + playerVy * finalTransfer
        
        -- Apply slight resistance to player movement (realistic physics)
        local playerResistance = finalTransfer * 0.05 -- Reduced resistance for smoother pushing
        playerBody.vx = playerBody.vx * (1 - playerResistance)
        playerBody.vy = playerBody.vy * (1 - playerResistance)
        
        -- Add some angular momentum to make debris spin when pushed
        local angularTransfer = finalTransfer * 0.3
        debrisBody.angularVel = (debrisBody.angularVel or 0) + (playerVx - playerVy) * angularTransfer * 0.01
    end
end

return ShipCollision
