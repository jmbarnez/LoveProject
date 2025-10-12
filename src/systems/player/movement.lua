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

    -- Get thrust power with boost multiplier
    local baseThrust = (body.thrusterPower and body.thrusterPower.main) or 600000
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
    
    -- WASD direct input vector (screen/world axes): W=up, S=down, A=left, D=right
    local ix, iy = 0, 0
    if w then iy = iy - 1 end
    if s then iy = iy + 1 end
    if a then ix = ix - 1 end
    if d then ix = ix + 1 end

    -- Normalize input vector
    local mag = math.sqrt(ix*ix + iy*iy)
    if mag > 0 then
        ix, iy = ix / mag, iy / mag

        -- Acceleration-based movement with speed cap, independent of facing
        local accel = (thrust / ((body.mass or 500))) * dt * 1.0
        local maxSpeed = (player.maxSpeed or 450)
        if boosting then
            maxSpeed = maxSpeed * (getCombatValue("BOOST_THRUST_MULT") or 1.5)
        end

        -- Apply acceleration
        local newVx = body.vx + ix * accel
        local newVy = body.vy + iy * accel

        -- Cap speed
        local newSpeed = math.sqrt(newVx*newVx + newVy*newVy)
        if newSpeed > maxSpeed then
            local scale = maxSpeed / newSpeed
            newVx, newVy = newVx * scale, newVy * scale
        end
        body.vx = newVx
        body.vy = newVy
    end
    
    -- Apply space drag every frame (regardless of thrusting)
    local CorePhysics = require("src.core.physics")
    local dragCoeff = body.dragCoefficient or CorePhysics.constants.SPACE_DRAG_COEFFICIENT
    body.vx = body.vx * dragCoeff
    body.vy = body.vy * dragCoeff
    
    -- Update thruster state based on input
    if w then 
        thrusterState.forward = 1.0
        thrusterState.isThrusting = true
    end
    if s then 
        thrusterState.reverse = 0.7
        thrusterState.isThrusting = true
    end
    if a then 
        thrusterState.strafeLeft = 0.8
        thrusterState.isThrusting = true
    end
    if d then 
        thrusterState.strafeRight = 0.8
        thrusterState.isThrusting = true
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
    if player.components.physics and player.components.physics.update then
        player.components.physics:update(dt)
        local b = player.components.physics.body
        if b then
            player.components.position.x = b.x
            player.components.position.y = b.y
            player.components.position.angle = b.angle
        else
            PlayerDebug.logPhysicsComponentIssue(player)
        end
    else
        PlayerDebug.logPhysicsComponentIssue(player)
    end
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
