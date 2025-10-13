-- Player Turret System
-- Handles turret firing, targeting, and update logic
-- Extracted from main PlayerSystem.update()

local HotbarSystem = require("src.systems.hotbar")
local PlayerDebug = require("src.systems.player.debug")

local TurretSystem = {}

-- Process all turrets from the equipment grid
function TurretSystem.processTurrets(player, state, modalActive, canFire, dt, world)
    -- Process all turrets from the grid, but apply different rules for weapons vs utility turrets
    for _, gridData in ipairs(player.components.equipment.grid) do
        if gridData.type == "turret" and gridData.module and gridData.module.update and type(gridData.module.update) == "function" then
            local turret = gridData.module

            -- Clean up dead assigned targets
            TurretSystem.cleanupDeadTargets(gridData)

            -- Handle mining laser cleanup
            TurretSystem.handleMiningCleanup(turret)

            -- Determine firing state
            local firingState = TurretSystem.determineFiringState(turret, gridData, modalActive, canFire)

            -- Update turret with firing state
            TurretSystem.updateTurret(turret, firingState, dt, world)

            -- Handle utility beam sound cleanup
            TurretSystem.handleUtilityBeamCleanup(turret, firingState.allow)
        end
    end
end

-- Clean up dead assigned targets
function TurretSystem.cleanupDeadTargets(gridData)
    if gridData.assignedTarget and gridData.assignedTarget.dead then
        gridData.assignedTarget = nil
        gridData.assignedType = nil
    end
end

-- Handle mining laser cleanup
function TurretSystem.handleMiningCleanup(turret)
    if turret and turret.kind == "mining_laser" and turret.miningTarget and turret.miningTarget.stopMining then
        -- Stop any mining beam (no targeting)
        turret.miningTarget:stopMining()
        turret.beamActive = false
    end
end

-- Determine firing state for a turret
function TurretSystem.determineFiringState(turret, gridData, modalActive, canFire)
    local isMissile = turret.kind == 'missile'
    local isUtility = turret.kind == 'mining_laser' or turret.kind == 'salvaging_laser' or turret.kind == 'healing_laser'
    local actionName = 'slot_' .. tostring(gridData.slot)
    local perSlotActive = HotbarSystem.isActive(actionName)
    local manualFireAll = false -- Could be made configurable

    local allow = (not modalActive) and canFire and (perSlotActive or manualFireAll)

    -- Handle firing mode logic
    local firing = false
    local autoFire = false

    if turret.fireMode == "automatic" then
        -- For automatic mode: use toggle state
        autoFire = allow
        firing = autoFire
    else
        -- For manual mode: only fire when button is actively held
        firing = allow
        autoFire = false
    end

    return {
        firing = firing,
        autoFire = autoFire,
        allow = allow,
        isMissile = isMissile,
        isUtility = isUtility
    }
end

-- Update turret with firing state
function TurretSystem.updateTurret(turret, firingState, dt, world)
    -- Update turret with firing state
    if turret.fireMode == "automatic" then
        turret.autoFire = firingState.autoFire
    end

    -- Call update with firing state (for manual mode)
    turret.firing = firingState.firing
    turret:update(dt, nil, not firingState.allow, world)
    
    -- Debug turret firing
    PlayerDebug.logTurretFiring(turret, firingState.firing, firingState.allow)
end

-- Handle utility beam sound cleanup
function TurretSystem.handleUtilityBeamCleanup(turret, allow)
    if not allow and (turret.kind == "mining_laser" or turret.kind == "salvaging_laser" or turret.kind == "healing_laser") then
        local TurretSystemCore = require("src.systems.turret.system")
        TurretSystemCore.stopEffects(turret)
    end
end

-- Check if turret can fire (weapon vs utility rules)
function TurretSystem.canTurretFire(turret, canFire)
    local isUtility = turret.kind == 'mining_laser' or turret.kind == 'salvaging_laser' or turret.kind == 'healing_laser'
    
    -- Utility turrets can fire even in safe zones
    if isUtility then
        return true
    end
    
    -- Weapon turrets follow normal rules
    return canFire
end

-- Get turret firing mode
function TurretSystem.getFiringMode(turret)
    return turret.fireMode or "manual"
end

-- Check if turret is utility type
function TurretSystem.isUtilityTurret(turret)
    return turret.kind == 'mining_laser' or turret.kind == 'salvaging_laser' or turret.kind == 'healing_laser'
end

-- Check if turret is weapon type
function TurretSystem.isWeaponTurret(turret)
    return turret.kind == 'cannon' or turret.kind == 'laser' or turret.kind == 'missile' or turret.kind == 'railgun'
end

-- Get weapon action name for hotbar
function TurretSystem.getActionName(slot)
    return 'slot_' .. tostring(slot)
end

-- Check if turret slot is active
function TurretSystem.isSlotActive(slot)
    local actionName = TurretSystem.getActionName(slot)
    return HotbarSystem.isActive(actionName)
end

-- Get all active weapon slots
function TurretSystem.getActiveSlots(player)
    local activeSlots = {}
    for _, gridData in ipairs(player.components.equipment.grid) do
        if gridData.type == "turret" and TurretSystem.isSlotActive(gridData.slot) then
            table.insert(activeSlots, gridData)
        end
    end
    return activeSlots
end

-- Get weapons by type
function TurretSystem.getTurretsByType(player, turretType)
    local turrets = {}
    for _, gridData in ipairs(player.components.equipment.grid) do
        if gridData.type == "turret" and gridData.module and gridData.module.kind == turretType then
            table.insert(turrets, gridData)
        end
    end
    return turrets
end

-- Get all utility turrets
function TurretSystem.getUtilityTurrets(player)
    local utilityTurrets = {}
    for _, gridData in ipairs(player.components.equipment.grid) do
        if gridData.type == "turret" and gridData.module and TurretSystem.isUtilityTurret(gridData.module) then
            table.insert(utilityTurrets, gridData)
        end
    end
    return utilityTurrets
end

-- Get all weapon turrets
function TurretSystem.getWeaponTurrets(player)
    local weaponTurrets = {}
    for _, gridData in ipairs(player.components.equipment.grid) do
        if gridData.type == "turret" and gridData.module and TurretSystem.isWeaponTurret(gridData.module) then
            table.insert(weaponTurrets, gridData)
        end
    end
    return weaponTurrets
end

-- Stop all turret effects
function TurretSystem.stopAllEffects(player)
    for _, gridData in ipairs(player.components.equipment.grid) do
        if gridData.type == "turret" and gridData.module then
            local TurretSystemCore = require("src.systems.turret.system")
            TurretSystemCore.stopEffects(gridData.module)
        end
    end
end

-- Pause all turrets
function TurretSystem.pauseAllTurrets(player)
    for _, gridData in ipairs(player.components.equipment.grid) do
        if gridData.type == "turret" and gridData.module then
            gridData.module.firing = false
            gridData.module.autoFire = false
        end
    end
end

-- Resume all turrets
function TurretSystem.resumeAllTurrets(player)
    for _, gridData in ipairs(player.components.equipment.grid) do
        if gridData.type == "turret" and gridData.module then
            -- Turrets will be updated normally in the next update cycle
        end
    end
end

return TurretSystem
