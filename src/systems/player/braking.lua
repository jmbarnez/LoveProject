-- Player Braking System
-- Handles active braking using RCS thrusters
-- Extracted from main PlayerSystem.update()

local CorePhysics = require("src.core.physics")
local PlayerDebug = require("src.systems.player.debug")

local BrakingSystem = {}

-- Process braking input and apply brake forces
function BrakingSystem.processBraking(player, body, braking, baseThrust, dt, thrusterState)
    if braking then
        thrusterState.brake = 1.0
        
        -- Get physics system for applying brake forces
        local PhysicsSystem = require("src.systems.physics")
        local physicsManager = PhysicsSystem.getManager()
        
        if physicsManager then
            -- Get current velocity
            local vx, vy = physicsManager:getVelocity(player)
            local currentSpeed = math.sqrt(vx * vx + vy * vy)
            
            if currentSpeed > 0.1 then -- Only brake if moving
                -- Apply brake force opposite to current velocity
                local brakeForce = baseThrust * 0.8 -- Brake power
                local brakeForceX = -(vx / currentSpeed) * brakeForce * dt
                local brakeForceY = -(vy / currentSpeed) * brakeForce * dt
                
                physicsManager:applyForce(player, brakeForceX, brakeForceY)
            end
        end
    else
        thrusterState.brake = 0
    end
end

-- Apply brake force opposite to current velocity
function BrakingSystem.applyBrakeForce(body, baseThrust, currentSpeed, dt)
    local brakingThrust = baseThrust * CorePhysics.constants.brakingPower
    
    -- Get velocity from windfield physics system
    local PhysicsSystem = require("src.systems.physics")
    local vx, vy = PhysicsSystem.getVelocity(body)
    
    -- Apply force opposite to current velocity vector
    local brakeForceX = -(vx / currentSpeed) * brakingThrust
    local brakeForceY = -(vy / currentSpeed) * brakingThrust
    
    PhysicsSystem.applyForce(body, brakeForceX, brakeForceY)
end

-- Check if player is moving fast enough to brake
function BrakingSystem.shouldBrake(body, minSpeed)
    minSpeed = minSpeed or 0.1
    local PhysicsSystem = require("src.systems.physics")
    local vx, vy = PhysicsSystem.getVelocity(body)
    local currentSpeed = math.sqrt(vx * vx + vy * vy)
    return currentSpeed > minSpeed
end

-- Get current speed
function BrakingSystem.getCurrentSpeed(body)
    local PhysicsSystem = require("src.systems.physics")
    local vx, vy = PhysicsSystem.getVelocity(body)
    return math.sqrt(vx * vx + vy * vy)
end

-- Calculate brake force magnitude
function BrakingSystem.calculateBrakeForce(baseThrust)
    return baseThrust * CorePhysics.constants.brakingPower
end

-- Get brake force vector
function BrakingSystem.getBrakeForceVector(body, brakeForce)
    local currentSpeed = BrakingSystem.getCurrentSpeed(body)
    if currentSpeed <= 0.1 then
        return 0, 0
    end
    
    local PhysicsSystem = require("src.systems.physics")
    local vx, vy = PhysicsSystem.getVelocity(body)
    return -(vx / currentSpeed) * brakeForce, -(vy / currentSpeed) * brakeForce
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
