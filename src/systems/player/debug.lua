-- Player Debug Module
-- Centralized debug logging for player system
-- Replaces scattered debug statements throughout player.lua

local Log = require("src.core.log")
local Config = require("src.content.config")

local PlayerDebug = {}

-- Debug configuration
local DEBUG_ENABLED = Config.DEBUG and Config.DEBUG.PLAYER_SYSTEM or false

-- Debug levels
local DEBUG_LEVELS = {
    NONE = 0,
    BASIC = 1,
    VERBOSE = 2,
    ALL = 3
}

local currentDebugLevel = DEBUG_LEVELS.BASIC

function PlayerDebug.setDebugLevel(level)
    currentDebugLevel = level
end

function PlayerDebug.isDebugEnabled(level)
    level = level or DEBUG_LEVELS.BASIC
    return DEBUG_ENABLED and currentDebugLevel >= level
end

-- Log player state issues (docked, dead, frozen, etc.)
function PlayerDebug.logStateIssue(player, state, docking, body)
    if not PlayerDebug.isDebugEnabled() then return end
    
    local debugInfo = {
        docked = docking and docking.docked or false,
        dead = player.dead,
        frozen = player.frozen,
        weaponsDisabled = state.weapons_disabled,
        hasPhysics = player.components and player.components.physics ~= nil,
        hasBody = player.components and player.components.physics and player.components.physics.body ~= nil
    }

    -- Only log if there's an actual issue
    if debugInfo.docked or not debugInfo.hasBody then
        Log.warn("PlayerSystem - Issue detected:",
            "docked=", debugInfo.docked,
            "dead=", debugInfo.dead,
            "frozen=", debugInfo.frozen,
            "weaponsDisabled=", debugInfo.weaponsDisabled,
            "hasPhysics=", debugInfo.hasPhysics,
            "hasBody=", debugInfo.hasBody
        )
    end
end

-- Log physics body issues
function PlayerDebug.logPhysicsIssue(player, body, inputs)
    if not PlayerDebug.isDebugEnabled() then return end
    
    if not body then
        Log.warn("PlayerSystem - No physics body found for player after respawn!")
        return
    end
    
    -- Log detailed physics state only if there's an issue
    local PhysicsSystem = require("src.systems.physics")
    local vx, vy = PhysicsSystem.getVelocity(player)
    local pos = player.components.position
    
    if vx == 0 and vy == 0 and (inputs.w or inputs.s or inputs.a or inputs.d) then
        Log.warn("PlayerSystem - Input detected but no movement:",
            "x=", pos.x, "y=", pos.y,
            "vx=", vx, "vy=", vy,
            "angle=", pos.angle
        )
    end
end

-- Log docking status
function PlayerDebug.logDockingStatus(docking)
    if not PlayerDebug.isDebugEnabled() then return end
    
    if docking and docking.docked then
        Log.warn("PlayerSystem - Player is docked, skipping update")
    end
end

-- Log physics body missing
function PlayerDebug.logMissingBody(player)
    if not PlayerDebug.isDebugEnabled() then return end
    
    Log.warn("PlayerSystem - No physics body found for player, skipping update")
end

-- Log physics component issues
function PlayerDebug.logPhysicsComponentIssue(player)
    if not PlayerDebug.isDebugEnabled() then return end
    
    if not player.components.physics then
        Log.warn("PlayerSystem - Physics component missing!")
    elseif not player.components.physics.update then
        Log.warn("PlayerSystem - Physics component has no update method!")
    elseif not player.components.physics.body then
        Log.warn("PlayerSystem - Physics body is nil after update!")
    end
end

-- Log respawn events
function PlayerDebug.logRespawn(player, docking)
    if not PlayerDebug.isDebugEnabled(DEBUG_LEVELS.VERBOSE) then return end
    
    Log.debug("PlayerSystem - Player respawned, state reset. docked:", 
        docking and docking.docked, "frozen:", player.frozen)
end

-- Log movement input
function PlayerDebug.logMovementInput(inputs)
    if not PlayerDebug.isDebugEnabled(DEBUG_LEVELS.ALL) then return end
    
    Log.debug("PlayerSystem - Movement input:",
        "w=", inputs.w, "s=", inputs.s, 
        "a=", inputs.a, "d=", inputs.d,
        "boost=", inputs.boost, "brake=", inputs.brake
    )
end

-- Log thruster state
function PlayerDebug.logThrusterState(thrusterState)
    if not PlayerDebug.isDebugEnabled(DEBUG_LEVELS.ALL) then return end
    
    Log.debug("PlayerSystem - Thruster state:",
        "forward=", thrusterState.forward,
        "reverse=", thrusterState.reverse,
        "strafeLeft=", thrusterState.strafeLeft,
        "strafeRight=", thrusterState.strafeRight,
        "boost=", thrusterState.boost,
        "brake=", thrusterState.brake,
        "isThrusting=", thrusterState.isThrusting
    )
end

-- Log turret firing
function PlayerDebug.logTurretFiring(turret, firing, allow)
    if not PlayerDebug.isDebugEnabled(DEBUG_LEVELS.VERBOSE) then return end
    
    Log.debug("PlayerSystem - Turret firing:",
        "kind=", turret.kind,
        "firing=", firing,
        "allow=", allow,
        "fireMode=", turret.fireMode
    )
end

-- Log warp gate detection
function PlayerDebug.logWarpGateDetection(inWarpRange, wasInWarpRange, canWarp)
    if not PlayerDebug.isDebugEnabled(DEBUG_LEVELS.VERBOSE) then return end
    
    Log.debug("PlayerSystem - Warp gate detection:",
        "inWarpRange=", inWarpRange,
        "wasInWarpRange=", wasInWarpRange,
        "canWarp=", canWarp
    )
end

-- Log weapon disable zones
function PlayerDebug.logWeaponDisableZone(inWeaponDisableZone, stationCount)
    if not PlayerDebug.isDebugEnabled(DEBUG_LEVELS.VERBOSE) then return end
    
    Log.debug("PlayerSystem - Weapon disable zone:",
        "inZone=", inWeaponDisableZone,
        "stationCount=", stationCount
    )
end

-- Log energy/shield regeneration
function PlayerDebug.logRegeneration(energyRegen, shieldRegen, currentEnergy, currentShield)
    if not PlayerDebug.isDebugEnabled(DEBUG_LEVELS.ALL) then return end
    
    Log.debug("PlayerSystem - Regeneration:",
        "energyRegen=", energyRegen,
        "shieldRegen=", shieldRegen,
        "currentEnergy=", currentEnergy,
        "currentShield=", currentShield
    )
end

-- Log dash system
function PlayerDebug.logDash(dashQueued, cooldown, canEnergy, energy)
    if not PlayerDebug.isDebugEnabled(DEBUG_LEVELS.VERBOSE) then return end
    
    Log.debug("PlayerSystem - Dash:",
        "queued=", dashQueued,
        "cooldown=", cooldown,
        "canEnergy=", canEnergy,
        "energy=", energy
    )
end

-- Log wreckage pushing
function PlayerDebug.logWreckagePush(wreckageCount, playerSpeed, pushCount)
    if not PlayerDebug.isDebugEnabled(DEBUG_LEVELS.ALL) then return end
    
    Log.debug("PlayerSystem - Wreckage push:",
        "wreckageCount=", wreckageCount,
        "playerSpeed=", playerSpeed,
        "pushCount=", pushCount
    )
end

return PlayerDebug
