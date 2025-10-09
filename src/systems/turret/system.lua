local TurretCore = require("src.systems.turret.core")
local ModifierSystem = require("src.systems.turret.modifier_system")
local UpgradeSystem = require("src.systems.turret.upgrade_system")
local TurretEffects = require("src.systems.turret.effects")

-- Ensure built-in turret handlers are registered before instances are created.
require("src.systems.turret.types.projectile")
require("src.systems.turret.types.gun")
require("src.systems.turret.types.missile")
require("src.systems.turret.types.laser")
require("src.systems.turret.types.mining_laser")
require("src.systems.turret.types.salvaging_laser")

local TurretSystem = {}

local trackedTurrets = setmetatable({}, { __mode = "k" })

local function track(turret)
    if turret then
        trackedTurrets[turret] = true
    end
end

local function untrack(turret)
    if turret then
        trackedTurrets[turret] = nil
    end
end

local function attachModifiers(turret, params)
    turret.modifierSystem = ModifierSystem.new(turret, (params and params.modifiers) or {})
    turret.modifiers = turret.modifierSystem:getSummaries()
end

local function attachUpgrades(turret, params)
    if params and params.upgrades then
        turret.upgradeEntry = UpgradeSystem.attach(turret, params.upgrades)
    end
end

local function detachUpgrades(turret)
    if turret and turret.upgradeEntry then
        UpgradeSystem.detach(turret)
        turret.upgradeEntry = nil
    end
end

function TurretSystem.spawn(owner, params)
    local turret = TurretCore.new(owner, params or {})
    attachModifiers(turret, params)
    attachUpgrades(turret, params)
    track(turret)
    return turret
end

function TurretSystem.update(turret, dt, target, locked, world)
    if not turret then
        return
    end

    if turret.update then
        turret:update(dt, target, locked, world)
    end
end

function TurretSystem.fire(turret, dt, target, locked, world)
    if not turret then
        return false
    end

    local handler = turret.getHandler and turret:getHandler() or nil
    if handler and handler.fire then
        handler.fire(turret, dt, target, locked, world)
        return true
    end

    local previousFiring = turret.firing
    turret.firing = true
    TurretSystem.update(turret, dt, target, locked, world)
    turret.firing = previousFiring
    return true
end

function TurretSystem.stopEffects(turret)
    if not turret then
        return
    end

    TurretEffects.stopAllTurretSounds(turret)
end

function TurretSystem.teardown(turret)
    if not turret then
        return
    end

    TurretSystem.stopEffects(turret)
    detachUpgrades(turret)
    turret.modifierSystem = nil
    turret.modifiers = turret.modifiers or {}
    untrack(turret)
end

function TurretSystem.cleanupEffects()
    TurretEffects.cleanupOrphanedSounds()
end

function TurretSystem.getTurretBySlot(owner, slot)
    return TurretCore.getTurretBySlot(owner, slot)
end

function TurretSystem.getTurretWorldPosition(turret)
    return TurretCore.getTurretWorldPosition(turret)
end

function TurretSystem.listActive()
    local list = {}
    for turret in pairs(trackedTurrets) do
        table.insert(list, turret)
    end
    return list
end

return TurretSystem
