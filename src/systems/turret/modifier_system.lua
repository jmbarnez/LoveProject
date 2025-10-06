local ModifierSystem = {}
ModifierSystem.__index = ModifierSystem

local function apply_damage_multiplier(turret, multiplier)
    if not turret.damage_range then return end
    local min = turret.damage_range.min or 0
    local max = turret.damage_range.max or min
    turret.damage_range.min = min * multiplier
    turret.damage_range.max = max * multiplier
end

local function apply_cycle_multiplier(turret, multiplier)
    if turret.cycle then
        turret.cycle = turret.cycle * multiplier
    end
    if turret.reloadTime then
        turret.reloadTime = turret.reloadTime * multiplier
    end
end

local function apply_energy_multiplier(turret, multiplier)
    if turret.capCost then
        turret.capCost = turret.capCost * multiplier
    end
    if turret.energyPerSecond then
        turret.energyPerSecond = turret.energyPerSecond * multiplier
    end
end

ModifierSystem.definitions = {
    overcharged_coils = {
        name = "Overcharged Coils",
        description = "+20% damage, +10% energy cost",
        apply = function(turret, config)
            apply_damage_multiplier(turret, config.damageMultiplier or 1.2)
            apply_energy_multiplier(turret, config.energyMultiplier or 1.1)
        end,
    },
    precision_barrel = {
        name = "Precision Barrel",
        description = "Reduces spread and improves projectile speed",
        apply = function(turret, config)
            if turret.spread then
                turret.spread.minDeg = (turret.spread.minDeg or 0) * (config.spreadMultiplier or 0.7)
                turret.spread.maxDeg = (turret.spread.maxDeg or turret.spread.minDeg) * (config.spreadMultiplier or 0.7)
            end
            if turret.projectileSpeed and turret.projectileSpeed > 0 then
                turret.projectileSpeed = turret.projectileSpeed * (config.speedMultiplier or 1.15)
            end
        end,
    },
    vented_housing = {
        name = "Vented Housing",
        description = "Faster firing cycle at lower damage",
        apply = function(turret, config)
            apply_cycle_multiplier(turret, config.cycleMultiplier or 0.85)
            apply_damage_multiplier(turret, config.damageMultiplier or 0.9)
        end,
    },
    capacitor_bank = {
        name = "Capacitor Bank",
        description = "Reduces energy draw",
        apply = function(turret, config)
            apply_energy_multiplier(turret, config.energyMultiplier or 0.8)
        end,
    },
    smart_warheads = {
        name = "Smart Warheads",
        description = "Missiles gain homing strength",
        apply = function(turret, config)
            turret.missileTurnRate = (turret.missileTurnRate or 0) + (config.turnRateBonus or math.rad(90))
        end,
    }
}

local function shallow_copy(tbl)
    local copy = {}
    for k, v in pairs(tbl or {}) do copy[k] = v end
    return copy
end

function ModifierSystem.new(turret, modifiers)
    local self = setmetatable({}, ModifierSystem)
    self.turret = turret
    self.applied = {}
    if type(modifiers) == "table" then
        if #modifiers > 0 then
            for _, descriptor in ipairs(modifiers) do
                self:apply(descriptor)
            end
        else
            for _, descriptor in pairs(modifiers) do
                self:apply(descriptor)
            end
        end
    end
    return self
end

function ModifierSystem:apply(descriptor)
    if type(descriptor) ~= "table" then return end
    local id = descriptor.id or descriptor.type or descriptor.name
    if not id then return end
    local def = ModifierSystem.definitions[id]
    if not def then return end
    local config = shallow_copy(descriptor)
    if def.apply then
        def.apply(self.turret, config)
    end
    table.insert(self.applied, {
        id = id,
        name = def.name or id,
        description = def.description,
    })
end

function ModifierSystem:getSummaries()
    return self.applied
end

return ModifierSystem
