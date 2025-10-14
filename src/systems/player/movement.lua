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

    -- Get physics system for applying forces
    local PhysicsSystem = require("src.systems.physics")
    local physicsManager = PhysicsSystem.getManager()
    
    if not physicsManager then
        return -- Physics system not initialized
    end
    
    -- Check if the player has a physics collider (avoid jitter on first movement)
    local collider = physicsManager:getCollider(player)
    if not collider then
        return -- Physics body not ready yet
    end

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
    
    -- Space physics: apply forces in the direction the ship is facing
    -- Since ship angle is fixed at 0, we use screen-relative directions
    local forceX, forceY = 0, 0
    
    -- Forward/backward thrust (W/S keys)
    if w then
        forceY = forceY - thrust  -- Up in screen space
    end
    if s then
        forceY = forceY + thrust  -- Down in screen space
    end
    
    -- Strafe left/right (A/D keys)
    if a then
        forceX = forceX - thrust  -- Left in screen space
    end
    if d then
        forceX = forceX + thrust  -- Right in screen space
    end
    
    -- Apply forces to Windfield physics body
    if forceX ~= 0 or forceY ~= 0 then
        physicsManager:applyForce(player, forceX, forceY)
    end
    
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
    if boosting then
        thrusterState.boost = 1.0
        thrusterState.isThrusting = true
    end

    if body and body.setThruster then
        body:setThruster("forward", w)
        body:setThruster("backward", s)
        body:setThruster("left", a)
        body:setThruster("right", d)
        body:setThruster("boost", boosting)
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
    local PhysicsSystem = require("src.systems.physics")
    local physicsManager = PhysicsSystem.getManager()
    
    if physicsManager then
        -- Get position from Windfield physics body
        local x, y = physicsManager:getPosition(player)
        
        if x and y then
            player.components.position.x = x
            player.components.position.y = y
            -- Keep ship angle fixed at 0 - only turrets rotate
            player.components.position.angle = 0
        end
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
