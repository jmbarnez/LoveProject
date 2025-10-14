-- Player Movement System
-- Handles WASD movement, boost, drag, and thruster state
-- Extracted from main PlayerSystem.update()

local Constants = require("src.core.constants")
local Config = require("src.content.config")
local PlayerDebug = require("src.systems.player.debug")

local MovementSystem = {}

-- Combat configuration
local combatOverrides = Config.COMBAT or {}
local combatConstants = Constants.COMBAT

-- Get combat value with fallback
local function getCombatValue(key)
    local value = combatOverrides[key]
    if value ~= nil then return value end
    return combatConstants[key]
end

-- Process movement input and apply forces
function MovementSystem.processMovement(player, body, inputs, dt, thrusterState)
    -- Extract input values
    local w = inputs.w
    local s = inputs.s
    local a = inputs.a
    local d = inputs.d
    local boosting = inputs.boosting
    local modalActive = inputs.modalActive

    -- Debug movement input
    PlayerDebug.logMovementInput(inputs)
    
    -- Debug: Check if we're getting input
    if w or s or a or d then
        local Log = require("src.core.log")
        Log.debug("movement", "Input detected: w=%s, s=%s, a=%s, d=%s", tostring(w), tostring(s), tostring(a), tostring(d))
    end

    -- Physics forces are handled by the Ship Physics System
    -- This system only processes input and updates thruster state

    -- Get thrust power from ship configuration
    local shipConfig = player.ship
    local baseThrust = (shipConfig and shipConfig.engine and shipConfig.engine.accel) or 250
    local thrust = baseThrust
    
    -- Apply boost multiplier
    if boosting then
        local mult = getCombatValue("BOOST_THRUST_MULT") or 1.5
        thrust = thrust * mult
        thrusterState.boost = 1.0
    end
    
    -- Apply slow when actively channeling shields
    if player.shieldChannel then
        local slow = getCombatValue("SHIELD_CHANNEL_SLOW") or 0.5
        thrust = thrust * math.max(0.1, slow)
    end
    
    -- Movement forces are now handled by the Ship Physics System
    -- which reads from the thruster state we set below
    
    -- Update thruster state based on input
    local thrustMultiplier = 1.0  -- Fixed multiplier for thruster intensity
    local forwardIntensity = w and thrustMultiplier or 0
    local reverseIntensity = s and thrustMultiplier or 0
    local strafeLeftIntensity = a and thrustMultiplier or 0
    local strafeRightIntensity = d and thrustMultiplier or 0
    local boostIntensity = boosting and 1.0 or 0

    thrusterState.forward = forwardIntensity
    thrusterState.reverse = reverseIntensity
    thrusterState.strafeLeft = strafeLeftIntensity
    thrusterState.strafeRight = strafeRightIntensity
    thrusterState.boost = boostIntensity
    thrusterState.isThrusting = (forwardIntensity > 0) or (reverseIntensity > 0) or (strafeLeftIntensity > 0) or (strafeRightIntensity > 0) or (boostIntensity > 0)

    -- Also update the windfield physics component's thruster state
    if player.components.windfield_physics then
        player.components.windfield_physics.thrusterState.forward = forwardIntensity
        player.components.windfield_physics.thrusterState.reverse = reverseIntensity
        player.components.windfield_physics.thrusterState.strafeLeft = strafeLeftIntensity
        player.components.windfield_physics.thrusterState.strafeRight = strafeRightIntensity
        player.components.windfield_physics.thrusterState.boost = boostIntensity
        player.components.windfield_physics.thrusterState.isThrusting = thrusterState.isThrusting
    end

    if body and body.setThruster then
        body:setThruster("forward", forwardIntensity)
        body:setThruster("backward", reverseIntensity)
        body:setThruster("left", strafeLeftIntensity)
        body:setThruster("right", strafeRightIntensity)
        body:setThruster("boost", boostIntensity)
    end

    -- Debug thruster state
    PlayerDebug.logThrusterState(thrusterState)
end

-- Handle boost energy drain
function MovementSystem.handleBoostDrain(player, boosting, dt)
    if not boosting then return end

    local energy = player.components and player.components.energy
    if energy then
        local drain = getCombatValue("BOOST_ENERGY_DRAIN") or 20
        energy.energy = math.max(0, (energy.energy or 0) - drain * dt)
        
        -- Stop boosting if energy is depleted
        if (energy.energy or 0) <= 0 then
            return false -- Return false to indicate boosting should stop
        end
    end
    
    return true -- Return true to continue boosting
end

-- Reset thruster state for visual effects
function MovementSystem.resetThrusterState(thrusterState)
    thrusterState.forward = 0      -- W key thrust forward
    thrusterState.reverse = 0      -- S key reverse thrust  
    thrusterState.strafeLeft = 0   -- A key strafe left
    thrusterState.strafeRight = 0  -- D key strafe right
    thrusterState.boost = 0        -- Boost multiplier effect
    thrusterState.brake = 0        -- Space key braking
    thrusterState.isThrusting = false  -- Overall thrusting state
end

-- Check if player is boosting
function MovementSystem.isBoosting(player, boostHeld)
    local energy = player.components and player.components.energy
    return (boostHeld and ((not energy) or ((energy.energy or 0) > 0))) or false
end

-- Get movement inputs from intent
function MovementSystem.getMovementInputs(intent, modalActive)
    return {
        w = (not modalActive) and intent.forward or false,
        s = (not modalActive) and intent.reverse or false,
        a = (not modalActive) and intent.strafeLeft or false,
        d = (not modalActive) and intent.strafeRight or false,
        boost = (not modalActive) and intent.boost or false,
        brake = (not modalActive) and intent.brake or false,
        modalActive = modalActive
    }
end

-- Update physics and sync components
function MovementSystem.updatePhysics(player, dt)
    -- Position syncing is now handled by WindfieldManager:syncPositions()
    -- This function is kept for compatibility but does nothing
end

-- Store cursor world position for turret aiming
function MovementSystem.updateCursorPosition(player, input, modalActive)
    if not modalActive and input and input.aimx and input.aimy then
        player.cursorWorldPos = { x = input.aimx, y = input.aimy }
    elseif modalActive then
        player.cursorWorldPos = nil
    end
end

return MovementSystem

