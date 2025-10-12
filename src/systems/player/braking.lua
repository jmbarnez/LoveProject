-- Player Braking System
-- Handles active braking using RCS thrusters
-- Extracted from main PlayerSystem.update()

local CorePhysics = require("src.core.physics")
local PlayerDebug = require("src.systems.player.debug")

local BrakingSystem = {}

-- Process braking input and apply brake forces
function BrakingSystem.processBraking(player, body, braking, baseThrust, dt, thrusterState)
    if braking then
        body:setThruster("brake", true)
        thrusterState.brake = 1.0
        
        -- Apply brake force directly since skipThrusterForce bypasses thruster forces
        local currentSpeed = math.sqrt(body.vx * body.vx + body.vy * body.vy)
        if currentSpeed > 0.1 then -- Only brake if moving
            BrakingSystem.applyBrakeForce(body, baseThrust, currentSpeed, dt)
        end
    else
        body:setThruster("brake", false)
        thrusterState.brake = 0
    end
end

-- Apply brake force opposite to current velocity
function BrakingSystem.applyBrakeForce(body, baseThrust, currentSpeed, dt)
    local brakingThrust = baseThrust * CorePhysics.constants.brakingPower
    
    -- Apply force opposite to current velocity vector
    local brakeForceX = -(body.vx / currentSpeed) * brakingThrust
    local brakeForceY = -(body.vy / currentSpeed) * brakingThrust
    
    body:applyForce(brakeForceX, brakeForceY, dt)
end

-- Check if player is moving fast enough to brake
function BrakingSystem.shouldBrake(body, minSpeed)
    minSpeed = minSpeed or 0.1
    local currentSpeed = math.sqrt(body.vx * body.vx + body.vy * body.vy)
    return currentSpeed > minSpeed
end

-- Get current speed
function BrakingSystem.getCurrentSpeed(body)
    return math.sqrt(body.vx * body.vx + body.vy * body.vy)
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
    
    return -(body.vx / currentSpeed) * brakeForce, -(body.vy / currentSpeed) * brakeForce
end

-- Set thruster brake state
function BrakingSystem.setThrusterBrake(body, braking)
    body:setThruster("brake", braking)
end

-- Update thruster state for braking
function BrakingSystem.updateThrusterState(thrusterState, braking)
    thrusterState.brake = braking and 1.0 or 0
end

return BrakingSystem
