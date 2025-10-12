-- Player Weapons System
-- Handles weapon disable zones, warp gate detection, and weapon state
-- Extracted from main PlayerSystem.update()

local Util = require("src.core.util")
local Events = require("src.core.events")
local WarpGateSystem = require("src.systems.warp_gate_system")
local PlayerDebug = require("src.systems.player.debug")

local WeaponsSystem = {}

-- Process weapon disable zones
function WeaponsSystem.processWeaponDisableZones(player, state, world)
    local ppos = player.components.position
    local stations = world:get_entities_with_components("station")
    local inWeaponDisableZone = false
    
    for _, station in ipairs(stations) do
        if station.components and station.components.position then
            local dx = ppos.x - station.components.position.x
            local dy = ppos.y - station.components.position.y
            local distSq = dx * dx + dy * dy
            -- Use the actual safe zone radius from the visual ring
            local safeZoneRadius = station.actualSafeZoneRadius or station.weaponDisableRadius or (station.radius or 50) * 1.5
            if distSq <= safeZoneRadius ^ 2 then
                inWeaponDisableZone = true
                break
            end
        end
    end
    
    state.weapons_disabled = inWeaponDisableZone
    PlayerDebug.logWeaponDisableZone(inWeaponDisableZone, #stations)
    
    return inWeaponDisableZone
end

-- Process warp gate proximity detection
function WeaponsSystem.processWarpGateDetection(player, state, world)
    local ppos = player.components.position
    local closestGate = WarpGateSystem.getClosestWarpGate(world, ppos.x, ppos.y, 1500)
    local inWarpRange = false
    
    if closestGate and closestGate.components.position then
        local gx, gy = closestGate.components.position.x, closestGate.components.position.y
        local distance = Util.distance(ppos.x, ppos.y, gx, gy)
        inWarpRange = distance <= 1500
    end

    -- Handle warp range state changes
    if inWarpRange and not state.was_in_warp_range then
        state.can_warp = true
        Events.emit(Events.GAME_EVENTS.CAN_WARP, { canWarp = true, gate = closestGate })
    elseif not inWarpRange and state.was_in_warp_range then
        state.can_warp = false
        Events.emit(Events.GAME_EVENTS.CAN_WARP, { canWarp = false, gate = nil })
    end

    state.was_in_warp_range = inWarpRange
    PlayerDebug.logWarpGateDetection(inWarpRange, state.was_in_warp_range, state.can_warp)
    
    return inWarpRange, closestGate
end

-- Check if player can fire weapons
function WeaponsSystem.canFireWeapons(state)
    return not state.weapons_disabled
end

-- Check if player is in warp range
function WeaponsSystem.isInWarpRange(player, world, maxDistance)
    maxDistance = maxDistance or 1500
    local ppos = player.components.position
    local closestGate = WarpGateSystem.getClosestWarpGate(world, ppos.x, ppos.y, maxDistance)
    
    if not closestGate or not closestGate.components.position then
        return false, nil
    end
    
    local gx, gy = closestGate.components.position.x, closestGate.components.position.y
    local distance = Util.distance(ppos.x, ppos.y, gx, gy)
    
    return distance <= maxDistance, closestGate
end

-- Get distance to nearest warp gate
function WeaponsSystem.getDistanceToNearestWarpGate(player, world, maxDistance)
    maxDistance = maxDistance or 1500
    local ppos = player.components.position
    local closestGate = WarpGateSystem.getClosestWarpGate(world, ppos.x, ppos.y, maxDistance)
    
    if not closestGate or not closestGate.components.position then
        return math.huge, nil
    end
    
    local gx, gy = closestGate.components.position.x, closestGate.components.position.y
    local distance = Util.distance(ppos.x, ppos.y, gx, gy)
    
    return distance, closestGate
end

-- Check if player is in weapon disable zone
function WeaponsSystem.isInWeaponDisableZone(player, world)
    local ppos = player.components.position
    local stations = world:get_entities_with_components("station")
    
    for _, station in ipairs(stations) do
        if station.components and station.components.position then
            local dx = ppos.x - station.components.position.x
            local dy = ppos.y - station.components.position.y
            local distSq = dx * dx + dy * dy
            local safeZoneRadius = station.actualSafeZoneRadius or station.weaponDisableRadius or (station.radius or 50) * 1.5
            if distSq <= safeZoneRadius ^ 2 then
                return true, station
            end
        end
    end
    
    return false, nil
end

-- Get weapon disable radius for a station
function WeaponsSystem.getWeaponDisableRadius(station)
    return station.actualSafeZoneRadius or station.weaponDisableRadius or (station.radius or 50) * 1.5
end

-- Get warp gate detection range
function WeaponsSystem.getWarpGateRange()
    return 1500
end

-- Set weapons disabled state
function WeaponsSystem.setWeaponsDisabled(state, disabled)
    state.weapons_disabled = disabled
end

-- Set warp capability
function WeaponsSystem.setCanWarp(state, canWarp, gate)
    state.can_warp = canWarp
    if canWarp then
        Events.emit(Events.GAME_EVENTS.CAN_WARP, { canWarp = true, gate = gate })
    else
        Events.emit(Events.GAME_EVENTS.CAN_WARP, { canWarp = false, gate = nil })
    end
end

-- Initialize warp-related flags
function WeaponsSystem.initializeWarpFlags(state)
    state.can_warp = state.can_warp or false
    state.was_in_warp_range = state.was_in_warp_range or false
end

-- Get all stations in range
function WeaponsSystem.getStationsInRange(world, playerX, playerY, maxRange)
    local stations = world:get_entities_with_components("station")
    local inRange = {}
    
    for _, station in ipairs(stations) do
        if station.components and station.components.position then
            local dx = playerX - station.components.position.x
            local dy = playerY - station.components.position.y
            local distance = math.sqrt(dx * dx + dy * dy)
            
            if distance <= maxRange then
                table.insert(inRange, station)
            end
        end
    end
    
    return inRange
end

-- Check if position is in weapon disable zone
function WeaponsSystem.isPositionInWeaponDisableZone(x, y, world)
    local stations = world:get_entities_with_components("station")
    
    for _, station in ipairs(stations) do
        if station.components and station.components.position then
            local dx = x - station.components.position.x
            local dy = y - station.components.position.y
            local distSq = dx * dx + dy * dy
            local safeZoneRadius = WeaponsSystem.getWeaponDisableRadius(station)
            if distSq <= safeZoneRadius ^ 2 then
                return true, station
            end
        end
    end
    
    return false, nil
end

return WeaponsSystem
