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

local function getPlayerState(player)
    if not player or not player.components then return nil end
    return player.components.player_state
end

local function getDockingStatus(player)
    if not player or not player.components then return nil end
    return player.components.docking_status
end

local function ensureThrusterState(state)
    if not state then return nil end
    state.thruster_state = state.thruster_state or {
        forward = 0,
        reverse = 0,
        strafeLeft = 0,
        strafeRight = 0,
        boost = 0,
        brake = 0,
        isThrusting = false,
    }
    return state.thruster_state
end

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
    if not player then
        Log.warn("PlayerSystem - No player entity provided")
        return
    end

    local state = getPlayerState(player)
    if not state then
        Log.warn("PlayerSystem - Player missing player_state component")
        return
    end
    local docking = getDockingStatus(player)
    local thrusterState = ensureThrusterState(state)

    -- Comprehensive debug logging for respawn issues
    local debugInfo = {
        docked = docking and docking.docked or false,
        dead = player.dead,
        frozen = player.frozen,
        weaponsDisabled = state.weapons_disabled,
        hasPhysics = player.components and player.components.physics ~= nil,
        hasBody = player.components and player.components.physics and player.components.physics.body ~= nil
    }

    -- Log detailed state only if there's an issue
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

    if docking and docking.docked then
        Log.warn("PlayerSystem - Player is docked, skipping update")
        return
    end

    -- Run shared ship update behaviour
    Ship.update(player, dt, player, function(projectile)
        world:addEntity(projectile)
    end, world)

    -- Initialize warp-related flags
    state.can_warp = state.can_warp or false
    state.was_in_warp_range = state.was_in_warp_range or false

    local ppos = player.components.position
    local body = player.components.physics and player.components.physics.body
    
    -- Debug physics body state (only if missing)
    if not body then
        Log.warn("PlayerSystem - No physics body found for player after respawn!")
    end
    
    -- Reset thrust state tracking for visual effects
    thrusterState.forward = 0      -- W key thrust forward
    thrusterState.reverse = 0      -- S key reverse thrust  
    thrusterState.strafeLeft = 0   -- A key strafe left
    thrusterState.strafeRight = 0  -- D key strafe right
    thrusterState.boost = 0        -- Boost multiplier effect
    thrusterState.brake = 0        -- Space key braking
    thrusterState.isThrusting = false  -- Overall thrusting state
    
    if not body then
        Log.warn("PlayerSystem - No physics body found for player, skipping update")
        return
    end
    -- Block gameplay controls when a modal UI is active (e.g., escape menu)
    local intent = latestIntent
    if not intent or intent.player ~= player then
        intent = defaultIntent
    end
    local modalActive = intent.modalActive or false

    -- Ship orientation is now independent of movement direction
    -- The ship maintains its current orientation and doesn't auto-rotate
    -- This allows for smooth 360-degree movement in any direction

    -- Movement system: WASD moves in that screen/world direction; ship still faces cursor
    body:resetThrusters() -- Ensure physics thrusters don't add extra forces

    local w = (not modalActive) and intent.forward or false
    local s = (not modalActive) and intent.reverse or false
    local a = (not modalActive) and intent.strafeLeft or false
    local d = (not modalActive) and intent.strafeRight or false
    -- Boost is now an action hotkey: hold Shift = thrusters
    local braking = (not modalActive) and intent.brake or false
    local boostHeld = (not modalActive) and intent.boost or false

    -- Debug input state (only log if input is detected but player is stuck)
    if (w or s or a or d) and (body.vx == 0 and body.vy == 0) then
        Log.warn("PlayerSystem - Input detected but player not moving! w=", w, "s=", s, "a=", a, "d=", d)
    end

    local h = player.components and player.components.health
    local boosting = (boostHeld and ((not h) or ((h.energy or 0) > 0))) or false
    
    -- Get thrust power with boost multiplier
    local baseThrust = (body.thrusterPower and body.thrusterPower.main) or 600000
    local thrust = baseThrust
    
    -- Apply boost multiplier
    if boosting then
        local mult = getCombatValue("BOOST_THRUST_MULT") or 1.5
        thrust = thrust * mult
        thrusterState.boost = 1.0
    end
    
    -- Apply slow when actively channeling shields
    if player.shieldChannel then
        local slow = getCombatValue("SHIELD_CHANNEL_SLOW") or 0.5
        thrust = thrust * math.max(0.1, slow)
    end
    
    -- WASD direct input vector (screen/world axes): W=up, S=down, A=left, D=right
    local ix, iy = 0, 0
    if w then iy = iy - 1 end
    if s then iy = iy + 1 end
    if a then ix = ix - 1 end
    if d then ix = ix + 1 end

    -- Normalize input vector
    local mag = math.sqrt(ix*ix + iy*iy)
    if mag > 0 then
        ix, iy = ix / mag, iy / mag

        -- Acceleration-based movement with speed cap, independent of facing
        local accel = (thrust / ((body.mass or 500))) * dt * 1.0
        local maxSpeed = (player.maxSpeed or 450)
        if boosting then
            maxSpeed = maxSpeed * (getCombatValue("BOOST_THRUST_MULT") or 1.5)
        end

        -- Apply acceleration
        local newVx = body.vx + ix * accel
        local newVy = body.vy + iy * accel

        -- Cap speed
        local newSpeed = math.sqrt(newVx*newVx + newVy*newVy)
        if newSpeed > maxSpeed then
            local scale = maxSpeed / newSpeed
            newVx, newVy = newVx * scale, newVy * scale
        end
        body.vx = newVx
        body.vy = newVy
    end
    
    -- Apply space drag every frame (regardless of thrusting)
    local CorePhysics = require("src.core.physics")
    local dragCoeff = body.dragCoefficient or CorePhysics.constants.SPACE_DRAG_COEFFICIENT
    body.vx = body.vx * dragCoeff
    body.vy = body.vy * dragCoeff
    
    -- Update thruster state based on input
    if w then 
        thrusterState.forward = 1.0
        thrusterState.isThrusting = true
    end
    if s then 
        thrusterState.reverse = 0.7
        thrusterState.isThrusting = true
    end
    if a then 
        thrusterState.strafeLeft = 0.8
        thrusterState.isThrusting = true
    end
    if d then 
        thrusterState.strafeRight = 0.8
        thrusterState.isThrusting = true
    end
    

    -- Boost multiplies thrust power when active
    -- (Boost effect is already applied above by increasing thrust power)

    -- Handle boost drain and auto-stop on empty capacitor (drains even when not moving)
    if boosting then
        if h then
            local drain = getCombatValue("BOOST_ENERGY_DRAIN") or 20
            h.energy = math.max(0, (h.energy or 0) - drain * dt)
            if (h.energy or 0) <= 0 then
                boosting = false -- capacitor empty; stop boosting
            end
        end
    end

    -- Dash: press dash key (Shift tap) to dash toward cursor
    if not modalActive then
        state.dash_cooldown = math.max(0, (state.dash_cooldown or 0) - dt)
        if player._dashQueued then
            player._dashQueued = false
            if (state.dash_cooldown or 0) <= 0 then
                local h = player.components and player.components.health
                local canEnergy = not h or (h.energy or 0) >= ((Config.DASH and Config.DASH.ENERGY_COST) or 0)
                
                -- Dash toward cursor if available, otherwise forward
                local dashDirX, dashDirY = 0, 0
                if input and input.aimx and input.aimy then
                    local dx = input.aimx - ppos.x
                    local dy = input.aimy - ppos.y
                    local dist = math.sqrt(dx*dx + dy*dy)
                    if dist > 1 then
                        dashDirX, dashDirY = dx / dist, dy / dist
                    end
                else
                    -- Fallback: dash in facing direction
                    dashDirX = math.cos(body.angle or 0)
                    dashDirY = math.sin(body.angle or 0)
                end
                
                if canEnergy and (dashDirX ~= 0 or dashDirY ~= 0) then
                    local desiredSpeed = (Config.DASH and Config.DASH.SPEED) or 900
                    local impulseX = dashDirX * desiredSpeed * (body.mass or 500)
                    local impulseY = dashDirY * desiredSpeed * (body.mass or 500)
                    if body.applyImpulse then body:applyImpulse(impulseX, impulseY) end
                    -- i-frames during dash
                    player.iFrames = math.max(player.iFrames or 0, (Config.DASH and Config.DASH.IFRAMES) or 0.25)
                    -- Energy cost
                    if h then
                        local cost = (Config.DASH and Config.DASH.ENERGY_COST) or 0
                        h.energy = math.max(0, (h.energy or 0) - cost)
                    end
                    -- Cooldown
                    state.dash_cooldown = (Config.DASH and Config.DASH.COOLDOWN) or 0.9
                    -- Optional SFX
                    local Sound = require("src.core.sound")
                    if Sound and Sound.triggerEvent then
                        if self.components and self.components.position then
                            Sound.triggerEvent('thruster_activate', self.components.position.x, self.components.position.y)
                        else
                            Sound.triggerEvent('thruster_activate')
                        end
                    end
                end
            end
        end
    end

    -- Active braking using realistic RCS thrusters (space key)
    if braking then
        body:setThruster("brake", true)
        thrusterState.brake = 1.0
    else
        body:setThruster("brake", false)
        thrusterState.brake = 0
    end

    -- Store cursor world position for turret aiming in render system
    if not modalActive and input and input.aimx and input.aimy then
        player.cursorWorldPos = { x = input.aimx, y = input.aimy }
    elseif modalActive then
        player.cursorWorldPos = nil
    end

    -- Ship maintains its heading (no cursor-facing rotation)
    -- Turret rotation is handled in the renderer system

    -- Update physics and sync components
    if player.components.physics and player.components.physics.update then
        player.components.physics:update(dt)
        local b = player.components.physics.body
        if b then
            player.components.position.x = b.x
            player.components.position.y = b.y
            player.components.position.angle = b.angle
            
            -- Debug physics body state only if there's an issue
            if b.vx == 0 and b.vy == 0 and (w or s or a or d) then
                Log.warn("PlayerSystem - Input detected but no movement:",
                    "x=", b.x, "y=", b.y,
                    "vx=", b.vx, "vy=", b.vy,
                    "angle=", b.angle
                )
            end
        else
            Log.warn("PlayerSystem - Physics body is nil after update!")
        end
    else
        Log.warn("PlayerSystem - Physics component missing or no update method!")
    end

    -- World boundaries enforced globally in game.lua

    -- Capacitor regen (use ship-specific regen if provided)
    local regenRate = (player.energyRegen or 10)
    player.components.health.energy = math.min(player.components.health.maxEnergy, player.components.health.energy + regenRate * dt)
    
    -- Shield regen from equipped modules (with non-linear slowdown)
    local shieldRegenRate = player:getShieldRegen()
    if shieldRegenRate > 0 and player.components.health then
        local currentShield = player.components.health.shield or 0
        local maxShield = player.components.health.maxShield or 0
        if currentShield < maxShield then
            -- Calculate non-linear regeneration rate
            -- Rate decreases exponentially as shields get closer to full
            local shieldPercent = currentShield / maxShield
            local regenMultiplier = math.pow(1 - shieldPercent, 2)  -- Quadratic slowdown

            -- Apply regeneration with multiplier
            local actualRegen = shieldRegenRate * regenMultiplier * dt
            player.components.health.shield = math.min(maxShield, currentShield + actualRegen)
        end
    end
    
    -- i-frames decay (kept for compatibility with other effects)
    player.iFrames = math.max(0, (player.iFrames or 0) - dt)


    -- No locking system: manual fire only

    -- Docking and weapon disable logic
    local stations = world:get_entities_with_components("station")
    local inWeaponDisableZone = false
    for _, station in ipairs(stations) do
        if station.components and station.components.position then
            local dx = ppos.x - station.components.position.x
            local dy = ppos.y - station.components.position.y
            local distSq = dx * dx + dy * dy
            if distSq <= (station.weaponDisableRadius or 0) ^ 2 then
                inWeaponDisableZone = true
                break
            end
        end
    end
    state.weapons_disabled = inWeaponDisableZone

    -- Warp gate proximity detection
    local closestGate = WarpGateSystem.getClosestWarpGate(world, ppos.x, ppos.y, 1500)
    local inWarpRange = false
    if closestGate and closestGate.components.position then
        local gx, gy = closestGate.components.position.x, closestGate.components.position.y
        local distance = Util.distance(ppos.x, ppos.y, gx, gy)
        inWarpRange = distance <= 1500
    end

    if inWarpRange and not state.was_in_warp_range then
        state.can_warp = true
        Events.emit(Events.GAME_EVENTS.CAN_WARP, { canWarp = true, gate = closestGate })
    elseif not inWarpRange and state.was_in_warp_range then
        state.can_warp = false
        Events.emit(Events.GAME_EVENTS.CAN_WARP, { canWarp = false, gate = nil })
    end

    state.was_in_warp_range = inWarpRange

    -- Update turrets - only assigned turrets fire, global selection just locks
    -- Allow firing inside friendly zone if weapons are enabled
    -- Also allow utility turrets (mining/salvaging) even in safe zones
    local canFire = not state.weapons_disabled
    -- Hotbar-driven actions: turret fire
    local manualFireAll = false


    -- Process all turrets from the grid, but apply different rules for weapons vs utility turrets
    for _, gridData in ipairs(player.components.equipment.grid) do
        if gridData.type == "turret" and gridData.module and gridData.module.update and type(gridData.module.update) == "function" then
            local t = gridData.module

            -- Clean up dead assigned targets
            if gridData.assignedTarget and gridData.assignedTarget.dead then
                gridData.assignedTarget = nil
                gridData.assignedType = nil
            end

            -- Manual fire: ignore targets; fire when aligned with cursor and LMB held
            if t and t.kind == "mining_laser" and t.miningTarget and t.miningTarget.stopMining then
                -- Stop any mining beam (no targeting)
                t.miningTarget:stopMining()
                t.beamActive = false
            end
            -- Handle turret firing based on fireMode
            local isMissile = t.kind == 'missile'
            local isUtility = t.kind == 'mining_laser' or t.kind == 'salvaging_laser'
            local actionName = 'turret_slot_' .. tostring(gridData.slot)
            local perSlotActive = HotbarSystem.isActive(actionName)

            local allow = (not modalActive) and canFire and (perSlotActive or manualFireAll)

            -- Handle firing mode logic
            local firing = false
            local autoFire = false

            if t.fireMode == "automatic" then
                -- For automatic mode: use toggle state
                autoFire = allow
                firing = autoFire
            else
                -- For manual mode: only fire when button is actively held
                firing = allow
                autoFire = false
            end

            -- Update turret with firing state
            if t.fireMode == "automatic" then
                t.autoFire = autoFire
            end

            -- Call update with firing state (for manual mode)
            t.firing = firing
            t:update(dt, nil, not allow, world)
            
            -- Force stop utility beam sounds if not allowed to fire
            if not allow and (t.kind == "mining_laser" or t.kind == "salvaging_laser") then
                local TurretSystem = require("src.systems.turret.system")
                TurretSystem.stopEffects(t)
            end
        end
    end
end


function PlayerSystem.dock(player, station)
    PlayerDocking.dock(player, station)
end

function PlayerSystem.undock(player)
    PlayerDocking.undock(player)
end

return PlayerSystem
