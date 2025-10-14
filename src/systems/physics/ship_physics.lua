--[[
    Ship Physics Factory
    
    Handles creation and management of ship physics bodies using Windfield.
    Provides thruster system integration and ship-specific physics behavior.
]]

local WindfieldManager = require("src.systems.physics.windfield_manager")
local Log = require("src.core.log")

local ShipPhysics = {}

-- Ship physics constants
local SHIP_CONSTANTS = {
    THRUSTER_POWER = 800,
    BRAKE_POWER = 1200,
    BOOST_MULTIPLIER = 2.0,
    ANGULAR_VELOCITY = 3.0,
    MAX_VELOCITY = 300,
    MIN_VELOCITY = 0.1,
    SPACE_DRAG = 0.9995,
}

function ShipPhysics.createShipCollider(ship, windfieldManager)
    if not ship or not ship.components or not ship.components.position then
        Log.warn("physics", "Cannot create ship collider: missing position component")
        return nil
    end
    
    local pos = ship.components.position
    local physics = ship.components.windfield_physics
    
    if not physics then
        Log.warn("physics", "Cannot create ship collider: missing windfield_physics component")
        return nil
    end
    
    -- Determine ship size and mass
    local mass = physics.mass or 1000
    local radius = physics.radius or 20
    
    -- Create physics options
    local options = {
        mass = mass,
        restitution = 0.1, -- Ships are less bouncy
        friction = 0.3,
        fixedRotation = false,
        bodyType = "dynamic",
        colliderType = "circle",
        radius = radius,
    }
    
    -- Create collider at the entity's current position
    local collider = windfieldManager:addEntity(ship, "circle", pos.x, pos.y, options)
    
    if collider then
        Log.debug("physics", "Created ship collider: mass=%.1f, radius=%.1f", mass, radius)
        return collider
    else
        Log.error("physics", "Failed to create ship collider")
        return nil
    end
end

function ShipPhysics.updateShipPhysics(ship, windfieldManager, dt)
    if not ship or not windfieldManager then return end
    
    local collider = windfieldManager.entities[ship]
    if not collider or collider:isDestroyed() then return end
    
    local physics = ship.components.windfield_physics
    if not physics then return end
    
    -- Get current velocity
    local vx, vy = windfieldManager:getVelocity(ship)
    local speed = math.sqrt(vx * vx + vy * vy)
    
    -- Apply thruster forces
    local thrusterState = physics:getThrusterState()
    if thrusterState.isThrusting then
        local forceX, forceY = 0, 0
        local angle = ship.components.position.angle or 0
        
        -- Forward/backward thrust
        if thrusterState.forward > 0 then
            local power = SHIP_CONSTANTS.THRUSTER_POWER * thrusterState.forward
            if thrusterState.boost > 0 then
                power = power * SHIP_CONSTANTS.BOOST_MULTIPLIER
            end
            forceX = forceX + math.cos(angle) * power
            forceY = forceY + math.sin(angle) * power
        end
        
        if thrusterState.reverse > 0 then
            local power = SHIP_CONSTANTS.THRUSTER_POWER * thrusterState.reverse * 0.7
            forceX = forceX - math.cos(angle) * power
            forceY = forceY - math.sin(angle) * power
        end
        
        -- Strafe thrust
        if thrusterState.strafeLeft > 0 then
            local power = SHIP_CONSTANTS.THRUSTER_POWER * thrusterState.strafeLeft * 0.8
            forceX = forceX + math.cos(angle - math.pi/2) * power
            forceY = forceY + math.sin(angle - math.pi/2) * power
        end
        
        if thrusterState.strafeRight > 0 then
            local power = SHIP_CONSTANTS.THRUSTER_POWER * thrusterState.strafeRight * 0.8
            forceX = forceX + math.cos(angle + math.pi/2) * power
            forceY = forceY + math.sin(angle + math.pi/2) * power
        end
        
        -- Apply forces
        if forceX ~= 0 or forceY ~= 0 then
            windfieldManager:applyForce(ship, forceX * dt, forceY * dt)
        end
        
        -- Braking
        if thrusterState.brake > 0 and speed > 0 then
            local brakeForce = SHIP_CONSTANTS.BRAKE_POWER * thrusterState.brake
            local brakeX = -vx * brakeForce * dt
            local brakeY = -vy * brakeForce * dt
            windfieldManager:applyForce(ship, brakeX, brakeY)
        end
    end
    
    -- Apply space drag
    if speed > 0 then
        vx = vx * SHIP_CONSTANTS.SPACE_DRAG
        vy = vy * SHIP_CONSTANTS.SPACE_DRAG
        
        -- Stop very slow movement
        local newSpeed = math.sqrt(vx * vx + vy * vy)
        if newSpeed < SHIP_CONSTANTS.MIN_VELOCITY then
            vx, vy = 0, 0
        end
        
        -- Cap maximum velocity
        if newSpeed > SHIP_CONSTANTS.MAX_VELOCITY then
            local ratio = SHIP_CONSTANTS.MAX_VELOCITY / newSpeed
            vx = vx * ratio
            vy = vy * ratio
        end
        
        windfieldManager:setVelocity(ship, vx, vy)
    end
end

function ShipPhysics.handleShipCollision(ship, other, contact)
    -- Handle ship-specific collision effects
    Log.debug("physics", "Ship collision with %s", other.subtype or "unknown")
    
    -- Add collision effects, damage, etc.
    local CollisionEffects = require("src.systems.collision.effects")
    if CollisionEffects then
        local shipPos = ship.components.position
        local otherPos = other.components.position
        CollisionEffects.createCollisionEffects(ship, other, 
                                               shipPos.x, shipPos.y, otherPos.x, otherPos.y, 
                                               0, 0, 20, 20, nil, nil)
    end
end

return ShipPhysics
