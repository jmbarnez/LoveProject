--[[
    Ship Physics Factory
    
    Handles creation and management of ship physics bodies using Windfield.
    Provides thruster system integration and ship-specific physics behavior.
    
    SHIP VELOCITY CONTROL:
    - Ships only get velocity from their own thruster forces
    - Global physics system skips ships to prevent unwanted velocity
    - Braking uses direct velocity reduction to prevent oscillation
]]

local WindfieldManager = require("src.systems.physics.windfield_manager")
local Radius = require("src.systems.collision.radius")
local Log = require("src.core.log")

local ShipPhysics = {}

-- Ship physics constants
local SHIP_CONSTANTS = {
    THRUSTER_POWER = 300,  -- More realistic thruster power
    BRAKE_POWER = 400,     -- Proportional brake power
    BOOST_MULTIPLIER = 1.8,  -- Slightly reduced boost
    ANGULAR_VELOCITY = 0.0,  -- No rotation - ship body is fixed
    MAX_VELOCITY = 180,    -- Match ship config
    MIN_VELOCITY = 0.1,
}

function ShipPhysics.createShipCollider(ship, windfieldManager)
    if not ship or not ship.components or not ship.components.position then
        Log.warn("physics", "Cannot create ship collider: missing position component")
        return nil
    end
    
    local pos = ship.components.position
    local physics = ship.components.windfield_physics
    local collidable = ship.components.collidable
    
    if not physics then
        Log.warn("physics", "Cannot create ship collider: missing windfield_physics component")
        return nil
    end
    
    -- Determine ship size and mass
    local mass = physics.mass or 1000
    
    -- Check if ship has polygon collision shape defined
    local usePolygon = collidable and collidable.shape == "polygon" and collidable.vertices
    local colliderType = usePolygon and "polygon" or "circle"
    
    -- Create physics options
    local options = {
        mass = mass,
        restitution = 0.1, -- Ships are less bouncy
        friction = 0.3,
        fixedRotation = true, -- Ships don't rotate - they use screen-relative movement
        bodyType = "dynamic",
        colliderType = colliderType,
    }
    
    if usePolygon then
        -- Use polygon vertices from collidable component
        options.vertices = collidable.vertices
        Log.debug("physics", "Using polygon collider for ship with %d vertices", #collidable.vertices / 2)
    else
        -- Fallback to circle collider
        local radius = Radius.getHullRadius(ship)
        options.radius = radius
        Log.debug("physics", "Using circle collider for ship with radius %.1f", radius)
    end
    
    -- Create collider at the entity's current position
    local collider = windfieldManager:addEntity(ship, colliderType, pos.x, pos.y, options)
    
    if collider then
        -- Ensure ship starts with zero velocity
        collider:setLinearVelocity(0, 0)
        collider:setAngularVelocity(0)
        
        Log.debug("physics", "Created ship collider: mass=%.1f, type=%s", mass, colliderType)
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
    
    -- Get thruster state
    local thrusterState = physics:getThrusterState()
    
    -- Apply thruster forces (screen-relative since ship angle is fixed)
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
                -- Apply afterburner multiplier if active
                local afterburnerMultiplier = 1.0
                if ship.state and ship.state.afterburner_active then
                    local AfterburnerSystem = require("src.systems.player.afterburner")
                    afterburnerMultiplier = AfterburnerSystem.getSpeedMultiplier(ship.state)
                end
                power = power * afterburnerMultiplier
                forceY = forceY - power  -- Up in screen space
            end
            
            if thrusterState.reverse > 0 then
                local power = baseThrust * thrusterState.reverse * 0.7
                forceY = forceY + power  -- Down in screen space
            end
            
            -- Strafe thrust (screen-relative)
            if thrusterState.strafeLeft > 0 then
                local power = baseThrust * thrusterState.strafeLeft * 0.8
                -- Apply afterburner multiplier if active
                local afterburnerMultiplier = 1.0
                if ship.state and ship.state.afterburner_active then
                    local AfterburnerSystem = require("src.systems.player.afterburner")
                    afterburnerMultiplier = AfterburnerSystem.getSpeedMultiplier(ship.state)
                end
                power = power * afterburnerMultiplier
                forceX = forceX - power  -- Left in screen space
            end
            
            if thrusterState.strafeRight > 0 then
                local power = baseThrust * thrusterState.strafeRight * 0.8
                -- Apply afterburner multiplier if active
                local afterburnerMultiplier = 1.0
                if ship.state and ship.state.afterburner_active then
                    local AfterburnerSystem = require("src.systems.player.afterburner")
                    afterburnerMultiplier = AfterburnerSystem.getSpeedMultiplier(ship.state)
                end
                power = power * afterburnerMultiplier
                forceX = forceX + power  -- Right in screen space
            end
            
        -- Apply forces
        if forceX ~= 0 or forceY ~= 0 then
            local Log = require("src.core.log")
            Log.debug("physics", "Applying force: fx=%.2f, fy=%.2f", forceX, forceY)
            windfieldManager:applyForce(ship, forceX, forceY)
        end
    end
    
    -- Simple braking - directly reduce velocity instead of applying opposing force
    if thrusterState.brake > 0 and speed > 0 then
        local Log = require("src.core.log")
        Log.debug("physics", "Applying braking: brake=%.2f, speed=%.2f", thrusterState.brake, speed)
        local brakePower = SHIP_CONSTANTS.BRAKE_POWER * thrusterState.brake
        local brakeFactor = 1.0 - (brakePower * dt)
        brakeFactor = math.max(0.1, brakeFactor) -- Don't let it go to 0 to prevent oscillation

        local newVx = vx * brakeFactor
        local newVy = vy * brakeFactor
        windfieldManager:setVelocity(ship, newVx, newVy)
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
