-- Player Afterburner System
-- Handles afterburner mechanics, charge management, and speed boost
-- Similar to dash system but for continuous speed boost

local Config = require("src.content.config")
local PlayerDebug = require("src.systems.player.debug")

local AfterburnerSystem = {}

-- Process afterburner input and execute afterburner if conditions are met
function AfterburnerSystem.processAfterburner(player, state, input, body, dt, modalActive)
    if modalActive then
        return -- Don't process afterburner when modal is active
    end

    -- Check if player has afterburner ability equipped
    if not AfterburnerSystem.hasAfterburnerAbility(player) then
        return -- Player doesn't have afterburner ability
    end

    -- Initialize afterburner state if not exists
    if not state.afterburner_charge then
        state.afterburner_charge = 100 -- Start with full charge
    end
    if not state.afterburner_cooldown then
        state.afterburner_cooldown = 0
    end
    if not state.afterburner_active then
        state.afterburner_active = false
    end

    -- Update cooldown
    state.afterburner_cooldown = math.max(0, state.afterburner_cooldown - dt)
    
    -- Check if afterburner is queued
    if not player._afterburnerQueued then
        return
    end

    -- Clear afterburner queue
    player._afterburnerQueued = false

    -- Check cooldown
    if state.afterburner_cooldown > 0 then
        PlayerDebug.logAfterburner(true, state.afterburner_charge, false, state.afterburner_cooldown)
        return
    end

    -- Check energy requirements
    local energy = player.components and player.components.energy
    local afterburnerConfig = Config.AFTERBURNER or {}
    local energyCost = afterburnerConfig.ENERGY_COST or 0
    local canEnergy = not energy or (energy.energy or 0) >= energyCost
    
    if not canEnergy then
        PlayerDebug.logAfterburner(true, state.afterburner_charge, false, 0)
        return
    end

    -- Toggle afterburner state
    state.afterburner_active = not state.afterburner_active
    
    PlayerDebug.logAfterburner(true, state.afterburner_charge, state.afterburner_active, 0)
end

-- Update afterburner charge and effects
function AfterburnerSystem.updateAfterburner(player, state, body, dt)
    if not state.afterburner_charge then
        return
    end

    local afterburnerConfig = Config.AFTERBURNER or {}
    local chargeRate = afterburnerConfig.CHARGE_RATE or 25
    local drainRate = afterburnerConfig.DRAIN_RATE or 50
    local maxCharge = afterburnerConfig.MAX_CHARGE or 100
    local energyCost = afterburnerConfig.ENERGY_COST or 0

    if state.afterburner_active then
        -- Drain charge while active
        state.afterburner_charge = math.max(0, state.afterburner_charge - drainRate * dt)
        
        -- Consume energy
        local energy = player.components and player.components.energy
        if energy and energyCost > 0 then
            energy.energy = math.max(0, (energy.energy or 0) - energyCost * dt)
        end
        
        -- If charge depleted, deactivate and start cooldown
        if state.afterburner_charge <= 0 then
            state.afterburner_active = false
            state.afterburner_cooldown = afterburnerConfig.COOLDOWN or 1.0
        end
    else
        -- Recharge when not active and not on cooldown
        if state.afterburner_cooldown <= 0 then
            state.afterburner_charge = math.min(maxCharge, state.afterburner_charge + chargeRate * dt)
        end
    end
end

-- Get afterburner speed multiplier
function AfterburnerSystem.getSpeedMultiplier(state)
    if not state.afterburner_active then
        return 1.0
    end
    
    local afterburnerConfig = Config.AFTERBURNER or {}
    return afterburnerConfig.SPEED_MULTIPLIER or 2.0
end

-- Check if afterburner is active
function AfterburnerSystem.isActive(state)
    return state.afterburner_active or false
end

-- Queue an afterburner toggle for the next update
function AfterburnerSystem.queueAfterburner(player)
    player._afterburnerQueued = true
end

-- Check if player has afterburner ability equipped
function AfterburnerSystem.hasAfterburnerAbility(player)
    if not player or not player.abilityModules then
        return false
    end
    
    return player.abilityModules.afterburner_available == true
end

-- Check if afterburner is available (has ability, not on cooldown, and has energy)
function AfterburnerSystem.isAfterburnerAvailable(player, state)
    if not AfterburnerSystem.hasAfterburnerAbility(player) then
        return false
    end
    
    local energy = player.components and player.components.energy
    local afterburnerConfig = Config.AFTERBURNER or {}
    local energyCost = afterburnerConfig.ENERGY_COST or 0
    local hasEnergy = not energy or (energy.energy or 0) >= energyCost
    local offCooldown = (state.afterburner_cooldown or 0) <= 0
    
    return hasEnergy and offCooldown
end

-- Get afterburner charge percentage
function AfterburnerSystem.getChargePercentage(state)
    if not state.afterburner_charge then
        return 0
    end
    
    local afterburnerConfig = Config.AFTERBURNER or {}
    local maxCharge = afterburnerConfig.MAX_CHARGE or 100
    return (state.afterburner_charge / maxCharge) * 100
end

-- Get afterburner cooldown remaining
function AfterburnerSystem.getCooldownRemaining(state)
    return state.afterburner_cooldown or 0
end

-- Get afterburner energy cost per second
function AfterburnerSystem.getEnergyCost()
    local afterburnerConfig = Config.AFTERBURNER or {}
    return afterburnerConfig.ENERGY_COST or 0
end

-- Get afterburner speed multiplier
function AfterburnerSystem.getSpeedMultiplierValue()
    local afterburnerConfig = Config.AFTERBURNER or {}
    return afterburnerConfig.SPEED_MULTIPLIER or 2.0
end

return AfterburnerSystem
