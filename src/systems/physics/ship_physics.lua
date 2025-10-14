--[[
    Ship Physics Factory
    
    Handles creation and management of ship physics bodies using Windfield.
    Provides thruster system integration and ship-specific physics behavior.
]]

local WindfieldManager = require("src.systems.physics.windfield_manager")
local Radius = require("src.systems.collision.radius")
local Log = require("src.core.log")

local ShipPhysics = {}

-- Ship physics constants
local SHIP_CONSTANTS = {
    THRUSTER_POWER = 500,  -- Reduced from 800
    BRAKE_POWER = 800,     -- Reduced from 1200
    BOOST_MULTIPLIER = 2.0,
    ANGULAR_VELOCITY = 0.0,  -- No rotation - ship body is fixed
    MAX_VELOCITY = 200,    -- Reduced from 300 to match ship config
    MIN_VELOCITY = 0.1,
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
    -- Use proper hull radius calculation based on visual boundaries
    local radius = Radius.getHullRadius(ship)
    
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
    
    -- Apply thruster forces (screen-relative since ship angle is fixed)
    local thrusterState = physics:getThrusterState()
    if thrusterState.isThrusting then
        local forceX, forceY = 0, 0
        
        -- Get thrust power from ship configuration
        local shipConfig = ship.ship
        local baseThrust = (shipConfig and shipConfig.engine and shipConfig.engine.accel) or 250
        
        -- Forward/backward thrust (screen-relative)
        if thrusterState.forward > 0 then
            local power = baseThrust * thrusterState.forward
            if thrusterState.boost > 0 then
                power = power * SHIP_CONSTANTS.BOOST_MULTIPLIER
            end
            forceY = forceY - power  -- Up in screen space
        end
        
        if thrusterState.reverse > 0 then
            local power = baseThrust * thrusterState.reverse * 0.7
            forceY = forceY + power  -- Down in screen space
        end
        
        -- Strafe thrust (screen-relative)
        if thrusterState.strafeLeft > 0 then
            local power = baseThrust * thrusterState.strafeLeft * 0.8
            forceX = forceX - power  -- Left in screen space
        end
        
        if thrusterState.strafeRight > 0 then
            local power = baseThrust * thrusterState.strafeRight * 0.8
            forceX = forceX + power  -- Right in screen space
        end
        
        -- Apply forces
        if forceX ~= 0 or forceY ~= 0 then
            windfieldManager:applyForce(ship, forceX, forceY)
        end
        
        -- Braking
        if thrusterState.brake > 0 and speed > 0 then
            local brakeForce = SHIP_CONSTANTS.BRAKE_POWER * thrusterState.brake
            local brakeX = -vx * brakeForce
            local brakeY = -vy * brakeForce
            windfieldManager:applyForce(ship, brakeX, brakeY)
        end
    end

    -- Enforce ship-specific speed limits using ship configuration
    local currentVx, currentVy = windfieldManager:getVelocity(ship)
    local currentSpeed = math.sqrt(currentVx * currentVx + currentVy * currentVy)
    local maxSpeed = (shipConfig and shipConfig.engine and shipConfig.engine.maxSpeed) or 200
    
    if currentSpeed < SHIP_CONSTANTS.MIN_VELOCITY then
        windfieldManager:setVelocity(ship, 0, 0)
    elseif currentSpeed > maxSpeed then
        local ratio = maxSpeed / currentSpeed
        windfieldManager:setVelocity(ship, currentVx * ratio, currentVy * ratio)
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
