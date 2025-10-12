-- Player Regeneration System
-- Handles energy and shield regeneration
-- Extracted from main PlayerSystem.update()

local PlayerDebug = require("src.systems.player.debug")

local RegenSystem = {}

-- Process energy regeneration
function RegenSystem.processEnergyRegen(player, dt)
    local regenRate = player.energyRegen or 10
    local health = player.components.health
    
    if health then
        local newEnergy = health.energy + regenRate * dt
        health.energy = math.min(health.maxEnergy, newEnergy)
        
        PlayerDebug.logRegeneration(regenRate, 0, health.energy, 0)
    end
end

-- Process shield regeneration with non-linear slowdown
function RegenSystem.processShieldRegen(player, dt)
    local shieldRegenRate = player:getShieldRegen()
    local health = player.components.health
    
    if shieldRegenRate > 0 and health then
        local currentShield = health.shield or 0
        local maxShield = health.maxShield or 0
        
        if currentShield < maxShield then
            -- Calculate non-linear regeneration rate
            -- Rate decreases exponentially as shields get closer to full
            local shieldPercent = currentShield / maxShield
            local regenMultiplier = math.pow(1 - shieldPercent, 2)  -- Quadratic slowdown

            -- Apply regeneration with multiplier
            local actualRegen = shieldRegenRate * regenMultiplier * dt
            local newShield = currentShield + actualRegen
            health.shield = math.min(maxShield, newShield)
            
            PlayerDebug.logRegeneration(0, shieldRegenRate, 0, health.shield)
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
    local health = player.components.health
    if not health then return false end
    
    return health.energy >= health.maxEnergy
end

-- Check if shield is at maximum
function RegenSystem.isShieldAtMax(player)
    local health = player.components.health
    if not health then return false end
    
    return (health.shield or 0) >= (health.maxShield or 0)
end

-- Get current energy percentage
function RegenSystem.getEnergyPercentage(player)
    local health = player.components.health
    if not health or health.maxEnergy <= 0 then return 0 end
    
    return health.energy / health.maxEnergy
end

-- Get current shield percentage
function RegenSystem.getShieldPercentage(player)
    local health = player.components.health
    if not health or (health.maxShield or 0) <= 0 then return 0 end
    
    return (health.shield or 0) / health.maxShield
end

-- Set energy regeneration rate
function RegenSystem.setEnergyRegenRate(player, rate)
    player.energyRegen = rate
end

-- Force energy regeneration (for testing/debugging)
function RegenSystem.forceEnergyRegen(player, amount)
    local health = player.components.health
    if health then
        health.energy = math.min(health.maxEnergy, health.energy + amount)
    end
end

-- Force shield regeneration (for testing/debugging)
function RegenSystem.forceShieldRegen(player, amount)
    local health = player.components.health
    if health then
        health.shield = math.min(health.maxShield, (health.shield or 0) + amount)
    end
end

return RegenSystem
