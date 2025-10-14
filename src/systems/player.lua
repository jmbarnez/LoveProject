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
local DashSystem = require("src.systems.player.dash")
local BrakingSystem = require("src.systems.player.braking")
local RegenSystem = require("src.systems.player.regen")
local TurretSystem = require("src.systems.player.turrets")
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
    thrusterState.forward = 0
    thrusterState.reverse = 0
    thrusterState.strafeLeft = 0
    thrusterState.strafeRight = 0
    thrusterState.boost = 0
    thrusterState.brake = 0
    thrusterState.isThrusting = false

    -- Get movement inputs
    local inputs = {
        w = (not modalActive) and intent.forward or false,
        s = (not modalActive) and intent.reverse or false,
        a = (not modalActive) and intent.strafeLeft or false,
        d = (not modalActive) and intent.strafeRight or false,
        boost = (not modalActive) and intent.boost or false,
        brake = (not modalActive) and intent.brake or false,
        modalActive = modalActive
    }
    
    -- Check if player is boosting
    local energy = player.components and player.components.energy
    local boosting = (inputs.boost and ((not energy) or ((energy.energy or 0) > 0))) or false
    inputs.boosting = boosting

    -- Reset physics thrusters (not needed for Windfield)
    -- body:resetThrusters()

    -- Movement is now handled by Ship Physics System
    -- Just update thruster state for visual effects
    local w = inputs.w
    local s = inputs.s
    local a = inputs.a
    local d = inputs.d
    
    -- Update thruster state for visual effects
    thrusterState.forward = w and 1.0 or 0
    thrusterState.reverse = s and 1.0 or 0
    thrusterState.strafeLeft = a and 1.0 or 0
    thrusterState.strafeRight = d and 1.0 or 0
    thrusterState.boost = boosting and 1.0 or 0
    thrusterState.isThrusting = w or s or a or d
    
    -- Update windfield physics component's thruster state
    if player.components.windfield_physics then
        player.components.windfield_physics.thrusterState.forward = thrusterState.forward
        player.components.windfield_physics.thrusterState.reverse = thrusterState.reverse
        player.components.windfield_physics.thrusterState.strafeLeft = thrusterState.strafeLeft
        player.components.windfield_physics.thrusterState.strafeRight = thrusterState.strafeRight
        player.components.windfield_physics.thrusterState.boost = thrusterState.boost
        player.components.windfield_physics.thrusterState.isThrusting = thrusterState.isThrusting
    end

    -- Handle boost energy drain
    if boosting then
        local energy = player.components and player.components.energy
        if energy then
            local drain = 20 -- BOOST_ENERGY_DRAIN
            energy.energy = math.max(0, (energy.energy or 0) - drain * dt)
            if (energy.energy or 0) <= 0 then
                boosting = false
            end
        end
    end

    -- Process dash
    DashSystem.processDash(player, state, input, body, dt, modalActive)

    -- Process afterburner
    local AfterburnerSystem = require("src.systems.player.afterburner")
    AfterburnerSystem.processAfterburner(player, state, input, body, dt, modalActive)
    AfterburnerSystem.updateAfterburner(player, state, body, dt)

    -- Process braking
    local baseThrust = 600000 -- Base thrust power
    BrakingSystem.processBraking(player, body, inputs.brake, baseThrust, dt, thrusterState)

    -- Update cursor position for turret aiming
    if not modalActive and input and input.aimx and input.aimy then
        player.cursorWorldPos = { x = input.aimx, y = input.aimy }
    elseif modalActive then
        player.cursorWorldPos = nil
    end

    -- Process regeneration systems
    RegenSystem.processAll(player, dt)

    -- Process weapon systems
    WeaponsSystem.processWeaponDisableZones(player, state, world)
    WeaponsSystem.processWarpGateDetection(player, state, world)

    -- Process turrets
    local canFire = WeaponsSystem.canFireWeapons(state)
    TurretSystem.processTurrets(player, state, modalActive, canFire, dt, world)

    -- Apply ship physics forces
    local ShipPhysics = require("src.systems.physics.ship_physics")
    local PhysicsSystem = require("src.systems.physics")
    local physicsManager = PhysicsSystem.getManager()
    if physicsManager then
        ShipPhysics.updateShipPhysics(player, physicsManager, dt)
    end

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
