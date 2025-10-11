local TurretScaling = {}

-- Scaling factors for different turret properties based on level
local SCALING_FACTORS = {
    damage = 1.15,        -- 15% increase per level
    cycle = 0.95,         -- 5% faster per level (lower cycle = faster)
    energy = 1.1,         -- 10% increase per level
    range = 1.05,         -- 5% increase per level
    heat = 1.08,          -- 8% increase per level
    accuracy = 1.02,      -- 2% improvement per level
}

-- Modifier rarity tiers with their chances
local MODIFIER_RARITY = {
    common = { chance = 0.6, maxModifiers = 1 },
    uncommon = { chance = 0.25, maxModifiers = 2 },
    rare = { chance = 0.12, maxModifiers = 3 },
    epic = { chance = 0.03, maxModifiers = 4 }
}

-- Modifier definitions with scaling based on level
local MODIFIER_DEFINITIONS = {
    -- Damage modifiers
    overcharged_coils = {
        name = "Overcharged Coils",
        description = "Increased damage output",
        rarity = "common",
        apply = function(turret, level)
            local multiplier = 1.0 + (level * 0.05) -- 5% per level
            if turret.damage_range then
                turret.damage_range.min = (turret.damage_range.min or 0) * multiplier
                turret.damage_range.max = (turret.damage_range.max or turret.damage_range.min) * multiplier
            end
        end
    },
    
    precision_barrel = {
        name = "Precision Barrel",
        description = "Improved accuracy and range",
        rarity = "common",
        apply = function(turret, level)
            local accuracyMult = 1.0 + (level * 0.03) -- 3% per level
            local rangeMult = 1.0 + (level * 0.04)    -- 4% per level
            
            if turret.spread then
                turret.spread.minDeg = (turret.spread.minDeg or 0) * (1 / accuracyMult)
                turret.spread.maxDeg = (turret.spread.maxDeg or turret.spread.minDeg) * (1 / accuracyMult)
            end
            if turret.optimal then
                turret.optimal = turret.optimal * rangeMult
            end
        end
    },
    
    rapid_fire_mechanism = {
        name = "Rapid Fire Mechanism",
        description = "Faster firing cycle",
        rarity = "common",
        apply = function(turret, level)
            local cycleMult = 1.0 - (level * 0.02) -- 2% faster per level
            if turret.cycle then
                turret.cycle = turret.cycle * cycleMult
            end
        end
    },
    
    energy_efficient_core = {
        name = "Energy Efficient Core",
        description = "Reduced energy consumption",
        rarity = "uncommon",
        apply = function(turret, level)
            local energyMult = 1.0 - (level * 0.03) -- 3% less energy per level
            if turret.capCost then
                turret.capCost = turret.capCost * energyMult
            end
            if turret.energyPerSecond then
                turret.energyPerSecond = turret.energyPerSecond * energyMult
            end
        end
    },
    
    heat_dissipation_system = {
        name = "Heat Dissipation System",
        description = "Better heat management",
        rarity = "uncommon",
        apply = function(turret, level)
            local heatMult = 1.0 - (level * 0.04) -- 4% less heat per level
            if turret.heatPerShot then
                turret.heatPerShot = turret.heatPerShot * heatMult
            end
            if turret.cooldownRate then
                turret.cooldownRate = turret.cooldownRate * (1.0 + level * 0.02) -- 2% faster cooldown per level
            end
        end
    },
    
    reinforced_warheads = {
        name = "Reinforced Warheads",
        description = "Significantly increased damage",
        rarity = "rare",
        apply = function(turret, level)
            local multiplier = 1.0 + (level * 0.08) -- 8% per level
            if turret.damage_range then
                turret.damage_range.min = (turret.damage_range.min or 0) * multiplier
                turret.damage_range.max = (turret.damage_range.max or turret.damage_range.min) * multiplier
            end
        end
    },
    
    advanced_targeting = {
        name = "Advanced Targeting",
        description = "Superior accuracy and tracking",
        rarity = "rare",
        apply = function(turret, level)
            local accuracyMult = 1.0 + (level * 0.05) -- 5% per level
            if turret.spread then
                turret.spread.minDeg = (turret.spread.minDeg or 0) * (1 / accuracyMult)
                turret.spread.maxDeg = (turret.spread.maxDeg or turret.spread.minDeg) * (1 / accuracyMult)
            end
            if turret.optimal then
                turret.optimal = turret.optimal * (1.0 + level * 0.06) -- 6% range per level
            end
        end
    },
    
    quantum_enhanced = {
        name = "Quantum Enhanced",
        description = "Exceptional performance across all metrics",
        rarity = "epic",
        apply = function(turret, level)
            local mult = 1.0 + (level * 0.06) -- 6% per level
            if turret.damage_range then
                turret.damage_range.min = (turret.damage_range.min or 0) * mult
                turret.damage_range.max = (turret.damage_range.max or turret.damage_range.min) * mult
            end
            if turret.cycle then
                turret.cycle = turret.cycle * (1.0 - level * 0.03) -- 3% faster per level
            end
            if turret.optimal then
                turret.optimal = turret.optimal * (1.0 + level * 0.04) -- 4% range per level
            end
        end
    }
}

-- Scale base turret properties with level
function TurretScaling.scaleBaseProperties(turret, level)
    if not turret or level <= 1 then return end
    
    local levelMult = level - 1 -- Level 1 = no scaling
    
    -- Scale damage
    if turret.damage_range then
        local damageScale = math.pow(SCALING_FACTORS.damage, levelMult)
        turret.damage_range.min = (turret.damage_range.min or 0) * damageScale
        turret.damage_range.max = (turret.damage_range.max or turret.damage_range.min) * damageScale
    end
    
    -- Scale firing cycle (lower = faster)
    if turret.cycle then
        local cycleScale = math.pow(SCALING_FACTORS.cycle, levelMult)
        turret.cycle = turret.cycle * cycleScale
    end
    
    -- Scale energy consumption
    if turret.capCost then
        local energyScale = math.pow(SCALING_FACTORS.energy, levelMult)
        turret.capCost = turret.capCost * energyScale
    end
    if turret.energyPerSecond then
        local energyScale = math.pow(SCALING_FACTORS.energy, levelMult)
        turret.energyPerSecond = turret.energyPerSecond * energyScale
    end
    
    -- Scale range
    if turret.optimal then
        local rangeScale = math.pow(SCALING_FACTORS.range, levelMult)
        turret.optimal = turret.optimal * rangeScale
    end
    if turret.falloff then
        local rangeScale = math.pow(SCALING_FACTORS.range, levelMult)
        turret.falloff = turret.falloff * rangeScale
    end
    
    -- Scale heat generation
    if turret.heatPerShot then
        local heatScale = math.pow(SCALING_FACTORS.heat, levelMult)
        turret.heatPerShot = turret.heatPerShot * heatScale
    end
    if turret.maxHeat then
        local heatScale = math.pow(SCALING_FACTORS.heat, levelMult)
        turret.maxHeat = turret.maxHeat * heatScale
    end
    
    -- Scale accuracy (lower spread = better)
    if turret.spread then
        local accuracyScale = math.pow(SCALING_FACTORS.accuracy, levelMult)
        turret.spread.minDeg = (turret.spread.minDeg or 0) / accuracyScale
        turret.spread.maxDeg = (turret.spread.maxDeg or turret.spread.minDeg) / accuracyScale
    end
end

-- Generate modifiers for a turret based on level
function TurretScaling.generateModifiers(level)
    local modifiers = {}
    
    -- Determine rarity tier based on level
    local rarityTier = "common"
    if level >= 15 then
        rarityTier = "epic"
    elseif level >= 10 then
        rarityTier = "rare"
    elseif level >= 5 then
        rarityTier = "uncommon"
    end
    
    local rarityConfig = MODIFIER_RARITY[rarityTier]
    if not rarityConfig then return modifiers end
    
    -- Roll for modifiers
    if math.random() <= rarityConfig.chance then
        local numModifiers = math.random(1, rarityConfig.maxModifiers)
        local availableModifiers = {}
        
        -- Filter modifiers by rarity
        for id, def in pairs(MODIFIER_DEFINITIONS) do
            if def.rarity == rarityTier or 
               (rarityTier == "rare" and def.rarity == "uncommon") or
               (rarityTier == "epic" and (def.rarity == "rare" or def.rarity == "uncommon")) then
                table.insert(availableModifiers, {id = id, def = def})
            end
        end
        
        -- Select random modifiers
        for i = 1, math.min(numModifiers, #availableModifiers) do
            local index = math.random(1, #availableModifiers)
            local modifier = availableModifiers[index]
            table.insert(modifiers, modifier)
            table.remove(availableModifiers, index)
        end
    end
    
    return modifiers
end

-- Apply modifiers to a turret
function TurretScaling.applyModifiers(turret, modifiers, level)
    if not turret or not modifiers then return end
    
    turret.modifiers = turret.modifiers or {}
    
    for _, modifier in ipairs(modifiers) do
        if modifier.def and modifier.def.apply then
            modifier.def.apply(turret, level)
            table.insert(turret.modifiers, {
                id = modifier.id,
                name = modifier.def.name,
                description = modifier.def.description,
                rarity = modifier.def.rarity
            })
        end
    end
end

-- Generate a complete level-scaled turret with modifiers
function TurretScaling.generateLeveledTurret(baseTurret, level)
    if not baseTurret or level < 1 then return baseTurret end
    
    -- Respect max level if defined
    local maxLevel = baseTurret.maxLevel
    if maxLevel and level > maxLevel then
        level = maxLevel
    end
    
    -- Deep copy the base turret
    local leveledTurret = {}
    for k, v in pairs(baseTurret) do
        if type(v) == "table" then
            leveledTurret[k] = {}
            for k2, v2 in pairs(v) do
                leveledTurret[k][k2] = v2
            end
        else
            leveledTurret[k] = v
        end
    end
    
    -- Set the level
    leveledTurret.level = level
    
    -- Scale base properties
    TurretScaling.scaleBaseProperties(leveledTurret, level)
    
    -- Generate and apply modifiers
    local modifiers = TurretScaling.generateModifiers(level)
    TurretScaling.applyModifiers(leveledTurret, modifiers, level)
    
    -- Generate procedural name
    leveledTurret.proceduralName = TurretScaling.generateProceduralName(baseTurret.name, leveledTurret.modifiers, level)
    
    return leveledTurret
end

-- Generate procedural name for leveled turret
function TurretScaling.generateProceduralName(baseName, modifiers, level)
    local name = baseName
    
    -- Add level prefix for high-level turrets
    if level >= 15 then
        name = "Elite " .. name
    elseif level >= 10 then
        name = "Advanced " .. name
    elseif level >= 5 then
        name = "Enhanced " .. name
    end
    
    -- Add modifier suffixes
    if modifiers then
        for _, mod in ipairs(modifiers) do
            if mod.rarity == "epic" then
                name = name .. " of Power"
            elseif mod.rarity == "rare" then
                name = name .. " of Precision"
            end
        end
    end
    
    return name
end

return TurretScaling
