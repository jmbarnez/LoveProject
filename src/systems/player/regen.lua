-- Player Regeneration System
-- Handles energy and shield regeneration
-- Extracted from main PlayerSystem.update()

local PlayerDebug = require("src.systems.player.debug")

local RegenSystem = {}

-- Process energy regeneration
function RegenSystem.processEnergyRegen(player, dt)
    local regenRate = player.energyRegen or 10
    local energy = player.components.energy
    
    if energy then
        local newEnergy = energy.energy + regenRate * dt
        energy.energy = math.min(energy.maxEnergy, newEnergy)
        
        PlayerDebug.logRegeneration(regenRate, 0, energy.energy, 0)
    end
end

-- Process shield regeneration with non-linear slowdown
function RegenSystem.processShieldRegen(player, dt)
    local shieldRegenRate = player:getShieldRegen()
    local shield = player.components.shield
    
    if shieldRegenRate > 0 and shield then
        local currentShield = shield.shield or 0
        local maxShield = shield.maxShield or 0
        
        if currentShield < maxShield then
            -- Calculate non-linear regeneration rate
            -- Rate decreases exponentially as shields get closer to full
            local shieldPercent = currentShield / maxShield
            local regenMultiplier = math.pow(1 - shieldPercent, 2)  -- Quadratic slowdown

            -- Apply regeneration with multiplier
            local actualRegen = shieldRegenRate * regenMultiplier * dt
            local newShield = currentShield + actualRegen
            shield.shield = math.min(maxShield, newShield)
            
            PlayerDebug.logRegeneration(0, shieldRegenRate, 0, shield.shield)
        end
    end
end

-- Process i-frames decay
function RegenSystem.processIframesDecay(player, dt)
    player.iFrames = math.max(0, (player.iFrames or 0) - dt)
end

-- Process all regeneration systems
function RegenSystem.processAll(player, dt)
    RegenSystem.processEnergyRegen(player, dt)
    RegenSystem.processShieldRegen(player, dt)
    RegenSystem.processIframesDecay(player, dt)
end

-- Get energy regeneration rate
function RegenSystem.getEnergyRegenRate(player)
    return player.energyRegen or 10
end

-- Get shield regeneration rate
function RegenSystem.getShieldRegenRate(player)
    return player:getShieldRegen()
end

-- Calculate shield regeneration multiplier based on current shield percentage
function RegenSystem.calculateShieldRegenMultiplier(currentShield, maxShield)
    if maxShield <= 0 then return 0 end
    
    local shieldPercent = currentShield / maxShield
    return math.pow(1 - shieldPercent, 2)  -- Quadratic slowdown
end

-- Check if energy is at maximum
function RegenSystem.isEnergyAtMax(player)
    local energy = player.components.energy
    if not energy then return false end
    
    return energy.energy >= energy.maxEnergy
end

-- Check if shield is at maximum
function RegenSystem.isShieldAtMax(player)
    local shield = player.components.shield
    if not shield then return false end
    
    return (shield.shield or 0) >= (shield.maxShield or 0)
end

-- Get current energy percentage
function RegenSystem.getEnergyPercentage(player)
    local energy = player.components.energy
    if not energy or energy.maxEnergy <= 0 then return 0 end
    
    return energy.energy / energy.maxEnergy
end

-- Get current shield percentage
function RegenSystem.getShieldPercentage(player)
    local shield = player.components.shield
    if not shield or (shield.maxShield or 0) <= 0 then return 0 end
    
    return (shield.shield or 0) / shield.maxShield
end

-- Set energy regeneration rate
function RegenSystem.setEnergyRegenRate(player, rate)
    player.energyRegen = rate
end

-- Force energy regeneration (for testing/debugging)
function RegenSystem.forceEnergyRegen(player, amount)
    local energy = player.components.energy
    if energy then
        energy.energy = math.min(energy.maxEnergy, energy.energy + amount)
    end
end

-- Force shield regeneration (for testing/debugging)
function RegenSystem.forceShieldRegen(player, amount)
    local shield = player.components.shield
    if shield then
        shield.shield = math.min(shield.maxShield, (shield.shield or 0) + amount)
    end
end

return RegenSystem
