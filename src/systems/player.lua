-- PlayerSystem: Handles all player-specific logic, including input processing.
local Util = require("src.core.util")
local Events = require("src.core.events")
local Constants = require("src.core.constants")
local Config = require("src.content.config")
local HotbarSystem = require("src.systems.hotbar")
local WarpGateSystem = require("src.systems.warp_gate_system")
local Log = require("src.core.log")
local Ship = require("src.templates.ship")
local PlayerDocking = require("src.systems.player.docking")

-- Player sub-systems
local PlayerDebug = require("src.systems.player.debug")
local StateValidator = require("src.systems.player.state_validator")
local MovementSystem = require("src.systems.player.movement")
local DashSystem = require("src.systems.player.dash")
local BrakingSystem = require("src.systems.player.braking")
local RegenSystem = require("src.systems.player.regen")
local TurretSystem = require("src.systems.player.turrets")
-- WreckagePushSystem removed - windfield physics handles wreckage interactions automatically
local WeaponsSystem = require("src.systems.player.weapons")

local PlayerSystem = {}

local latestIntent = {
    moveX = 0,
    moveY = 0,
    forward = false,
    reverse = false,
    strafeLeft = false,
    strafeRight = false,
    boost = false,
    brake = false,
    modalActive = false,
    anyMovement = false,
    player = nil,
}

local defaultIntent = {
    moveX = 0,
    moveY = 0,
    forward = false,
    reverse = false,
    strafeLeft = false,
    strafeRight = false,
    boost = false,
    brake = false,
    modalActive = false,
    anyMovement = false,
}


local combatOverrides = Config.COMBAT or {}
local combatConstants = Constants.COMBAT

-- Use StateValidator helper functions instead of local ones
local getPlayerState = StateValidator.getPlayerState
local getDockingStatus = StateValidator.getDockingStatus
local ensureThrusterState = StateValidator.ensureThrusterState

local function getCombatValue(key)
    local value = combatOverrides[key]
    if value ~= nil then return value end
    return combatConstants[key]
end

local function onPlayerDamaged(eventData)
  local player = eventData.entity
  -- Player damage is already applied in CollisionSystem.applyDamage.
  -- This listener can be used for UI/feedback if needed.
end

function PlayerSystem.init(world)
  Events.on(Events.GAME_EVENTS.PLAYER_DAMAGED, onPlayerDamaged)
  
  Events.on(Events.GAME_EVENTS.PLAYER_DIED, function(event)
    local player = event.player
    local state = getPlayerState(player)
    if state then
        local thrusters = ensureThrusterState(state)
        if thrusters then
            thrusters.forward = 0
            thrusters.reverse = 0
            thrusters.strafeLeft = 0
            thrusters.strafeRight = 0
            thrusters.boost = 0
            thrusters.brake = 0
            thrusters.isThrusting = false
        end
        state.dash_cooldown = 0
        state.shield_active = false
        state.weapons_disabled = true
    end
  end)

  Events.on(Events.GAME_EVENTS.PLAYER_RESPAWN, function(event)
    local player = event.player
    Log.debug("PlayerSystem - player_respawn event received for player:", player and player.id or "unknown")
    local state = getPlayerState(player)
    local docking = getDockingStatus(player)
    if docking then
        docking.docked = false
    end
    if state then
        state.weapons_disabled = false
        state.dash_cooldown = 0
        state.shield_active = false
        state.can_warp = false
        state.was_in_warp_range = false
    end
    player.iFrames = 0
    -- Ensure player is not frozen or stuck
    player.dead = false
    player.frozen = false
    Log.debug("PlayerSystem - Player respawned, state reset. docked:", docking and docking.docked, "frozen:", player.frozen)
  end)
  Events.on(Events.GAME_EVENTS.PLAYER_INTENT, function(intent)
    if intent and intent.player then
      latestIntent = intent
    end
  end)

end

function PlayerSystem.update(dt, player, input, world, hub)
    -- Single validation check replaces multiple early returns
    local state = getPlayerState(player)
    local docking = getDockingStatus(player)
    local body = StateValidator.getPhysicsBody(player)
    
    local validation = StateValidator.validate(player, state, body, docking)
    if not validation:isSuccess() then
        if validation.data.skipUpdate then
            PlayerDebug.logDockingStatus(docking)
        else
            Log.warn("PlayerSystem -", validation:getReason())
        end
        return
    end

    -- Debug state issues
    PlayerDebug.logStateIssue(player, state, docking, body)

    -- Run shared ship update behaviour
    Ship.update(player, dt, player, function(projectile)
        world:addEntity(projectile)
    end, world)

    -- Initialize warp-related flags
    WeaponsSystem.initializeWarpFlags(state)

    -- Get input intent
    local intent = latestIntent
    if not intent or intent.player ~= player then
        intent = defaultIntent
    end
    local modalActive = intent.modalActive or false

    -- Reset thruster state for visual effects
    local thrusterState = ensureThrusterState(state)
    MovementSystem.resetThrusterState(thrusterState)

    -- Get movement inputs
    local inputs = MovementSystem.getMovementInputs(intent, modalActive)
    local boosting = MovementSystem.isBoosting(player, inputs.boost)

    -- Reset physics thrusters (not needed for Windfield)
    -- body:resetThrusters()

    -- Process movement
    MovementSystem.processMovement(player, body, inputs, dt, thrusterState)

    -- Handle boost energy drain
    boosting = MovementSystem.handleBoostDrain(player, boosting, dt)

    -- Process dash
    DashSystem.processDash(player, state, input, body, dt, modalActive)

    -- Process braking
    local baseThrust = 600000 -- Base thrust power
    BrakingSystem.processBraking(player, body, inputs.brake, baseThrust, dt, thrusterState)

    -- Update cursor position for turret aiming
    MovementSystem.updateCursorPosition(player, input, modalActive)

    -- Update physics and sync components
    MovementSystem.updatePhysics(player, dt)

    -- Process regeneration systems
    RegenSystem.processAll(player, dt)

    -- Process weapon systems
    WeaponsSystem.processWeaponDisableZones(player, state, world)
    WeaponsSystem.processWarpGateDetection(player, state, world)

    -- Process turrets
    local canFire = WeaponsSystem.canFireWeapons(state)
    TurretSystem.processTurrets(player, state, modalActive, canFire, dt, world)

    -- Process wreckage pushing
    -- Wreckage push handled automatically by windfield physics
end


function PlayerSystem.dock(player, station)
    PlayerDocking.dock(player, station)
end

function PlayerSystem.undock(player)
    PlayerDocking.undock(player)
end

return PlayerSystem
