-- Player State Validator
-- Centralized validation for player state and components
-- Replaces multiple early returns with single validation check

local Log = require("src.core.log")

local StateValidator = {}

-- Validation result structure
local ValidationResult = {}
ValidationResult.__index = ValidationResult

function ValidationResult.new(isValid, reason, data)
    local self = setmetatable({}, ValidationResult)
    self.isValid = isValid
    self.reason = reason or "Unknown validation error"
    self.data = data or {}
    return self
end

function ValidationResult:isSuccess()
    return self.isValid
end

function ValidationResult:getReason()
    return self.reason
end

function ValidationResult:getData()
    return self.data
end

-- Main validation function - replaces all early returns
function StateValidator.validate(player, state, body, docking)
    -- Check if player exists
    if not player then
        return ValidationResult.new(false, "No player entity provided")
    end

    -- Check if player has components
    if not player.components then
        return ValidationResult.new(false, "Player missing components")
    end

    -- Check if player state exists
    if not state then
        return ValidationResult.new(false, "Player missing player_state component")
    end

    -- Check if player is docked (skip update but not an error)
    if docking and docking.docked then
        return ValidationResult.new(false, "Player is docked, skipping update", { skipUpdate = true })
    end

    -- Check if physics body exists
    if not body then
        return ValidationResult.new(false, "No physics body found for player")
    end

    -- All validations passed
    return ValidationResult.new(true, "Player state is valid", {
        player = player,
        state = state,
        body = body,
        docking = docking
    })
end

-- Validate player for specific operations
function StateValidator.validateForMovement(player, state, body)
    local baseValidation = StateValidator.validate(player, state, body)
    if not baseValidation:isSuccess() then
        return baseValidation
    end

    -- Additional movement-specific validations
    if not player.components.position then
        return ValidationResult.new(false, "Player missing position component")
    end

    if not body.thrusterPower then
        return ValidationResult.new(false, "Player physics body missing thruster power")
    end

    return ValidationResult.new(true, "Player ready for movement")
end

-- Validate player for turret operations
function StateValidator.validateForTurrets(player, state)
    if not player then
        return ValidationResult.new(false, "No player entity provided")
    end

    if not state then
        return ValidationResult.new(false, "Player missing player_state component")
    end

    if not player.components.equipment then
        return ValidationResult.new(false, "Player missing equipment component")
    end

    if not player.components.equipment.grid then
        return ValidationResult.new(false, "Player equipment missing grid")
    end

    return ValidationResult.new(true, "Player ready for turret operations")
end

-- Validate player for dash
function StateValidator.validateForDash(player, state, cooldown)
    if not player then
        return ValidationResult.new(false, "No player entity provided")
    end

    if not state then
        return ValidationResult.new(false, "Player missing player_state component")
    end

    if cooldown and cooldown > 0 then
        return ValidationResult.new(false, "Dash on cooldown", { cooldown = cooldown })
    end

    if not player._dashQueued then
        return ValidationResult.new(false, "No dash queued")
    end

    return ValidationResult.new(true, "Player ready for dash")
end

-- Validate player for regeneration
function StateValidator.validateForRegeneration(player)
    if not player then
        return ValidationResult.new(false, "No player entity provided")
    end

    if not player.components.hull then
        return ValidationResult.new(false, "Player missing health component")
    end

    return ValidationResult.new(true, "Player ready for regeneration")
end

-- Validate player for wreckage pushing
function StateValidator.validateForWreckagePush(player, body, inputs)
    if not player then
        return ValidationResult.new(false, "No player entity provided")
    end

    if not body then
        return ValidationResult.new(false, "No physics body found")
    end

    if not inputs then
        return ValidationResult.new(false, "No input data provided")
    end

    -- Check if player is moving
    local isMoving = inputs.w or inputs.s or inputs.a or inputs.d
    if not isMoving then
        return ValidationResult.new(false, "Player not moving")
    end

    return ValidationResult.new(true, "Player ready for wreckage push")
end

-- Validate player for weapon operations
function StateValidator.validateForWeapons(player, state)
    if not player then
        return ValidationResult.new(false, "No player entity provided")
    end

    if not state then
        return ValidationResult.new(false, "Player missing player_state component")
    end

    if not player.components.position then
        return ValidationResult.new(false, "Player missing position component")
    end

    return ValidationResult.new(true, "Player ready for weapon operations")
end

-- Helper function to get player state safely
function StateValidator.getPlayerState(player)
    if not player or not player.components then 
        return nil 
    end
    return player.components.player_state
end

-- Helper function to get docking status safely
function StateValidator.getDockingStatus(player)
    if not player or not player.components then 
        return nil 
    end
    return player.components.docking_status
end

-- Helper function to get physics body safely
function StateValidator.getPhysicsBody(player)
    if not player or not player.components or not player.components.physics then
        return nil
    end
    return player.components.physics.body
end

-- Helper function to ensure thruster state exists
function StateValidator.ensureThrusterState(state)
    if not state then 
        return nil 
    end
    
    state.thruster_state = state.thruster_state or {
        forward = 0,
        reverse = 0,
        strafeLeft = 0,
        strafeRight = 0,
        boost = 0,
        brake = 0,
        isThrusting = false,
    }
    return state.thruster_state
end

return StateValidator
