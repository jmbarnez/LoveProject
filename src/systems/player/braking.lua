-- Player Braking System
-- Handles active braking using RCS thrusters
-- Extracted from main PlayerSystem.update()

-- Braking constants (moved from core.physics)
local BRAKING_CONSTANTS = {
    brakingPower = 1.5 -- Brake power multiplier
}
local PlayerDebug = require("src.systems.player.debug")

local BrakingSystem = {}

-- Process braking input and apply brake forces
function BrakingSystem.processBraking(player, body, braking, baseThrust, dt, thrusterState)
    if braking then
        thrusterState.brake = 1.0
        BrakingSystem.setThrusterBrake(body, true)
        
        -- Get physics system for applying brake forces
        local EntityPhysics = require("src.systems.entity_physics")
        local physicsManager = EntityPhysics.getManager()
        
        if physicsManager then
            -- Get current velocity
            local vx, vy = physicsManager:getVelocity(player)
            local currentSpeed = math.sqrt(vx * vx + vy * vy)
            
            if currentSpeed > 0.1 then -- Only brake if moving
                -- Apply brake force opposite to current velocity
                local brakeForce = baseThrust * 0.8 -- Brake power
                local brakeForceX = -(vx / currentSpeed) * brakeForce
                local brakeForceY = -(vy / currentSpeed) * brakeForce
                
                physicsManager:applyForce(player, brakeForceX, brakeForceY)
            end
        end
    else
        thrusterState.brake = 0
        BrakingSystem.setThrusterBrake(body, false)
    end
end

-- Apply brake force opposite to current velocity
function BrakingSystem.applyBrakeForce(body, baseThrust, currentSpeed, dt)
    local brakingThrust = baseThrust * BRAKING_CONSTANTS.brakingPower
    
    -- Get velocity from windfield physics system
    local EntityPhysics = require("src.systems.entity_physics")
    local manager = EntityPhysics.getManager()
    if manager then
        local collider = manager:getCollider(body)
        if collider then
            local vx, vy = collider:getLinearVelocity()
            
            -- Apply force opposite to current velocity vector
            local brakeForceX = -(vx / currentSpeed) * brakingThrust
            local brakeForceY = -(vy / currentSpeed) * brakingThrust
            
            collider:applyForce(brakeForceX, brakeForceY)
        end
    end
end

-- Check if player is moving fast enough to brake
function BrakingSystem.shouldBrake(body, minSpeed)
    minSpeed = minSpeed or 0.1
    local EntityPhysics = require("src.systems.entity_physics")
    local manager = EntityPhysics.getManager()
    if manager then
        local collider = manager:getCollider(body)
        if collider then
            local vx, vy = collider:getLinearVelocity()
            local currentSpeed = math.sqrt(vx * vx + vy * vy)
            return currentSpeed > minSpeed
        end
    end
    return false
end

-- Get current speed
function BrakingSystem.getCurrentSpeed(body)
    local EntityPhysics = require("src.systems.entity_physics")
    local manager = EntityPhysics.getManager()
    if manager then
        local collider = manager:getCollider(body)
        if collider then
            local vx, vy = collider:getLinearVelocity()
            return math.sqrt(vx * vx + vy * vy)
        end
    end
    return 0
end

-- Calculate brake force magnitude
function BrakingSystem.calculateBrakeForce(baseThrust)
    return baseThrust * BRAKING_CONSTANTS.brakingPower
end

-- Get brake force vector
function BrakingSystem.getBrakeForceVector(body, brakeForce)
    local currentSpeed = BrakingSystem.getCurrentSpeed(body)
    if currentSpeed <= 0.1 then
        return 0, 0
    end
    
    local EntityPhysics = require("src.systems.entity_physics")
    local manager = EntityPhysics.getManager()
    if manager then
        local collider = manager:getCollider(body)
        if collider then
            local vx, vy = collider:getLinearVelocity()
            return -(vx / currentSpeed) * brakeForce, -(vy / currentSpeed) * brakeForce
        end
    end
    return 0, 0
end

-- Set thruster brake state
function BrakingSystem.setThrusterBrake(body, braking)
    if body and body.setThruster then
        body:setThruster("brake", braking)
    end
end

-- Update thruster state for braking
function BrakingSystem.updateThrusterState(thrusterState, braking)
    thrusterState.brake = braking and 1.0 or 0
end

return BrakingSystem
