local UpgradeSystem = {}
UpgradeSystem.__index = UpgradeSystem

local registry = {}

local function apply_bonus(turret, bonus)
    if not bonus then return end
    if bonus.damageMultiplier and turret.damage_range then
        turret.damage_range.min = turret.damage_range.min * bonus.damageMultiplier
        turret.damage_range.max = turret.damage_range.max * bonus.damageMultiplier
    end
    if bonus.cycleMultiplier and turret.cycle then
        turret.cycle = turret.cycle * bonus.cycleMultiplier
    end
    if bonus.projectileSpeed and turret.projectileSpeed then
        turret.projectileSpeed = turret.projectileSpeed + bonus.projectileSpeed
    end
    if bonus.homingBonus then
        turret.missileTurnRate = (turret.missileTurnRate or 0) + bonus.homingBonus
    end
end

local function ensure_registry_key(turret)
    return turret.id or turret.instanceId or tostring(turret)
end

function UpgradeSystem.attach(turret, config)
    if not turret then return nil end
    local entry = {
        turret = turret,
        level = (config and config.startLevel) or 0,
        experience = 0,
        thresholds = (config and config.thresholds) or {150, 400, 900},
        bonuses = (config and config.bonuses) or {},
        label = (config and config.label) or "Mk",
    }

    entry.history = {}

    local key = ensure_registry_key(turret)
    registry[key] = entry
    turret.upgradeData = entry

    if entry.level > 0 then
        for lvl = 1, entry.level do
            apply_bonus(turret, entry.bonuses[lvl])
        end
    end

    return entry
end

function UpgradeSystem.detach(turret)
    local key = ensure_registry_key(turret)
    registry[key] = nil
end

function UpgradeSystem.onProjectileHit(bullet, damage)
    local bulletData = bullet and bullet.components and bullet.components.bullet
    if not bulletData then return end
    local turretId = bulletData.turretId
    if not turretId then return end

    local entry = registry[turretId]
    if not entry then return end

    local gain = damage or 0
    if bulletData.hitKind == 'shield' then
        gain = gain * 0.5
    end
    entry.experience = entry.experience + gain

    while entry.thresholds[entry.level + 1] and entry.experience >= entry.thresholds[entry.level + 1] do
        entry.level = entry.level + 1
        apply_bonus(entry.turret, entry.bonuses[entry.level])
        table.insert(entry.history, {
            level = entry.level,
            experience = entry.experience,
        })
    end
end

function UpgradeSystem.getEntry(id)
    return registry[id]
end

function UpgradeSystem.getRegistry()
    return registry
end

return UpgradeSystem
