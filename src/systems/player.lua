-- PlayerSystem: Handles all player-specific logic, including input processing.
local Util = require("src.core.util")
local Events = require("src.core.events")
local Config = require("src.content.config")
local Input = require("src.core.input")
local HotbarSystem = require("src.systems.hotbar")
local WarpGateSystem = require("src.systems.warp_gate_system")
local Log = require("src.core.log")

local PlayerSystem = {}

local function onPlayerDamaged(eventData)
  local player = eventData.entity
  -- Player damage is already applied in CollisionSystem.applyDamage.
  -- This listener can be used for UI/feedback if needed.
end

function PlayerSystem.init(world)
  Events.on(Events.GAME_EVENTS.PLAYER_DAMAGED, onPlayerDamaged)
end

function PlayerSystem.update(dt, player, input, world, hub)
    if not player or player.docked then return end
    
    -- Call the player's update method if it exists
    if type(player.update) == "function" then
        player:update(dt, world, function(projectile) 
            world:addEntity(projectile) 
        end)
    end
    
    -- Engine effects are now updated after physics in game.lua to avoid thruster state reset issues

    -- Initialize thruster state if not present
    player.thrusterState = player.thrusterState or {
        forward = 0,
        reverse = 0,
        strafeLeft = 0,
        strafeRight = 0,
        boost = 0,
        brake = 0,
        isThrusting = false
    }
    
    -- Initialize warp-related flags
    player.canWarp = player.canWarp or false
    player.wasInWarpRange = player.wasInWarpRange or false

    -- Update lock-on targeting system for missile launchers
    if player.updateLockOn and player:hasMissileLauncher() then
        player:updateLockOn(dt, world)
    end

    local ppos = player.components.position
    local body = player.components.physics and player.components.physics.body
    
    -- Reset thrust state tracking for visual effects
    player.thrusterState.forward = 0      -- W key thrust forward
    player.thrusterState.reverse = 0      -- S key reverse thrust  
    player.thrusterState.strafeLeft = 0   -- A key strafe left
    player.thrusterState.strafeRight = 0  -- D key strafe right
    player.thrusterState.boost = 0        -- Boost multiplier effect
    player.thrusterState.brake = 0        -- Space key braking
    player.thrusterState.isThrusting = false  -- Overall thrusting state
    
    if not body then return end
    -- Face the mouse cursor with smooth, high-turn-rate tracking
    if input and input.aimx and input.aimy then
        local dx = input.aimx - ppos.x
        local dy = input.aimy - ppos.y
        local desiredAngle = math.atan2(dy, dx)
        local currentAngle = body.angle or 0
        local diff = (desiredAngle - currentAngle + math.pi) % (2 * math.pi) - math.pi
        -- Limit how fast we can turn for a more skill-based feel (radians/sec)
        local maxTurnRate = 6.0
        local step = math.max(-maxTurnRate * dt, math.min(maxTurnRate * dt, diff))
        body.angle = currentAngle + step
        player.components.position.angle = body.angle
        -- Zero out residual angular velocity to avoid wobble
        body.angularVel = 0
    end

    -- Movement system: WASD moves in that screen/world direction; ship still faces cursor
    body:resetThrusters() -- Ensure physics thrusters don't add extra forces

    local w = love.keyboard.isDown("w")
    local s = love.keyboard.isDown("s")
    local a = love.keyboard.isDown("a")
    local d = love.keyboard.isDown("d")
    -- Boost is now an action hotkey: hold Shift = thrusters
    local braking = love.keyboard.isDown("space")
    local boostHeld = love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")

    local h = player.components and player.components.health
    local boosting = (boostHeld and ((not h) or ((h.energy or 0) > 0))) or false
    
    -- Get thrust power with boost multiplier
    local baseThrust = (body.thrusterPower and body.thrusterPower.main) or 600000
    local thrust = baseThrust
    
    -- Apply boost multiplier
    if boosting then
        local mult = (Config.COMBAT and Config.COMBAT.BOOST_THRUST_MULT) or 1.5
        thrust = thrust * mult
        player.thrusterState.boost = 1.0
    end
    
    -- Apply slow when actively channeling shields
    if player.shieldChannel then
        local slow = (Config.COMBAT and Config.COMBAT.SHIELD_CHANNEL_SLOW) or 0.5
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
            maxSpeed = maxSpeed * ((Config.COMBAT and Config.COMBAT.BOOST_THRUST_MULT) or 1.5)
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
    
    -- Update thruster state based on input
    if w then 
        player.thrusterState.forward = 1.0
        player.thrusterState.isThrusting = true
    end
    if s then 
        player.thrusterState.reverse = 0.7
        player.thrusterState.isThrusting = true
    end
    if a then 
        player.thrusterState.strafeLeft = 0.8
        player.thrusterState.isThrusting = true
    end
    if d then 
        player.thrusterState.strafeRight = 0.8
        player.thrusterState.isThrusting = true
    end
    

    -- Boost multiplies thrust power when active
    -- (Boost effect is already applied above by increasing thrust power)

    -- Handle boost drain and auto-stop on empty capacitor (drains even when not moving)
    if boosting then
        if h then
            local drain = (Config.COMBAT and Config.COMBAT.BOOST_ENERGY_DRAIN) or 20
            h.energy = math.max(0, (h.energy or 0) - drain * dt)
            if (h.energy or 0) <= 0 then
                boosting = false -- capacitor empty; stop boosting
            end
        end
    end

    -- Dash: press dash key (Shift tap) to dash toward cursor
    do
        player._dashCd = math.max(0, (player._dashCd or 0) - dt)
        if player._dashQueued then
            player._dashQueued = false
            if (player._dashCd or 0) <= 0 then
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
                    player._dashCd = (Config.DASH and Config.DASH.COOLDOWN) or 0.9
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
        player.thrusterState.brake = 1.0
    else
        body:setThruster("brake", false)
        player.thrusterState.brake = 0
    end

    -- Store cursor world position for turret aiming in render system
    if input and input.aimx and input.aimy then
        player.cursorWorldPos = { x = input.aimx, y = input.aimy }
    end

    -- Ship body now faces cursor; turrets inherit via renderer

    -- Update physics and sync components
    if player.components.physics and player.components.physics.update then
        player.components.physics:update(dt)
        local b = player.components.physics.body
        if b then
            player.components.position.x = b.x
            player.components.position.y = b.y
            player.components.position.angle = b.angle
        end
    end

    -- World boundaries enforced globally in game.lua

    -- Capacitor regen (use ship-specific regen if provided)
    local regenRate = (player.energyRegen or 10)
    player.components.health.energy = math.min(player.components.health.maxEnergy, player.components.health.energy + regenRate * dt)
    -- i-frames decay (kept for compatibility with other effects)
    player.iFrames = math.max(0, (player.iFrames or 0) - dt)

    -- Parry removed in simple manual mode

    -- No locking system: manual fire only
    player.locked = true
    player.lockProgress = 1

    -- Docking and weapon disable logic
    local SpaceStationSystem = require("src.systems.hub")
    if hub and hub.components and hub.components.position then
        local inSpaceStation = SpaceStationSystem.isInside(hub, ppos.x, ppos.y)

        if inSpaceStation and not player.wasInSpaceStation then
            player.weaponsDisabled = true
            Events.emit(Events.GAME_EVENTS.CAN_DOCK, { canDock = true, station = hub })
        elseif not inSpaceStation and player.wasInSpaceStation then
            player.weaponsDisabled = false
            Events.emit(Events.GAME_EVENTS.CAN_DOCK, { canDock = false })
        end
        player.wasInSpaceStation = inSpaceStation
    else
        player.wasInSpaceStation = false
        player.weaponsDisabled = false
        Events.emit(Events.GAME_EVENTS.CAN_DOCK, { canDock = false })
    end

    -- Warp gate proximity detection
    local closestGate = WarpGateSystem.getClosestWarpGate(world, ppos.x, ppos.y, 1500)
    local inWarpRange = false
    if closestGate and closestGate.components.position then
        local gx, gy = closestGate.components.position.x, closestGate.components.position.y
        local distance = Util.distance(ppos.x, ppos.y, gx, gy)
        inWarpRange = distance <= 1500
    end

    if inWarpRange and not player.wasInWarpRange then
        player.canWarp = true
        Events.emit(Events.GAME_EVENTS.CAN_WARP, { canWarp = true, gate = closestGate })
    elseif not inWarpRange and player.wasInWarpRange then
        player.canWarp = false
        Events.emit(Events.GAME_EVENTS.CAN_WARP, { canWarp = false, gate = nil })
    end

    player.wasInWarpRange = inWarpRange

    -- Update turrets - only assigned turrets fire, global selection just locks
    -- Allow firing inside friendly zone if targeting an enemy (permission override)
    -- Also allow utility turrets (mining/salvaging) even in safe zones
    local canFire = (not player.weaponsDisabled) or (player.target and player.targetType == 'enemy')
    -- Hotbar-driven actions: turret fire and shield channel
    local manualFireAll = false -- legacy 'turret' action removed; use per-slot hotkeys only
    
    -- Special handling for missile lock-on firing with left-click
    local missileLockFire = false
    if player.lockOnState and player.lockOnState.isLocked and player:hasMissileLauncher() then
        -- Check if left mouse button is pressed (will be handled by input system)
        missileLockFire = input and input.leftClick
    end

    -- Shield active ability: 50% damage reduction with duration/cooldown system
    do
        local h = player.components and player.components.health
        local isPressed = (HotbarSystem and HotbarSystem.isActive and HotbarSystem.isActive('shield')) or false
        
        -- Initialize shield state if not present
        player._shieldState = player._shieldState or {
            active = false,
            duration = 0,
            cooldown = 0
        }
        
        local shieldState = player._shieldState
        
        -- Update timers
        shieldState.duration = math.max(0, shieldState.duration - dt)
        shieldState.cooldown = math.max(0, shieldState.cooldown - dt)
        
        -- Handle activation
        if isPressed and not shieldState.active and shieldState.cooldown <= 0 then
            local energyCost = (Config.COMBAT and Config.COMBAT.SHIELD_ENERGY_COST) or 50
            if h and (h.energy or 0) >= energyCost then
                -- Activate shield
                shieldState.active = true
                shieldState.duration = (Config.COMBAT and Config.COMBAT.SHIELD_DURATION) or 3.0
                h.energy = math.max(0, (h.energy or 0) - energyCost)
            end
        end
        
        -- Deactivate when duration expires
        if shieldState.active and shieldState.duration <= 0 then
            shieldState.active = false
            shieldState.cooldown = (Config.COMBAT and Config.COMBAT.SHIELD_COOLDOWN) or 5.0
        end
        
        -- Set the shield channel flag for compatibility with other systems
        player.shieldChannel = shieldState.active
    end

    -- Process all turrets, but apply different rules for weapons vs utility turrets
    for _, slot in ipairs(player.components.equipment.turrets) do
        local t = slot.turret

        -- Clean up dead assigned targets
        if slot.assignedTarget and slot.assignedTarget.dead then
            slot.assignedTarget = nil
            slot.assignedType = nil
            slot.lockProgress = 0
            slot.lockTime = nil
        end

        -- Manual fire: ignore targets; fire when aligned with cursor and LMB held
        if t and t.kind == "mining_laser" and t.miningTarget and t.miningTarget.stopMining then
            -- Stop any mining beam (no targeting)
            t.miningTarget:stopMining()
            t.beamActive = false
        end
        if t then
            -- Manual fire per turret slot if bound, or all via global 'turret'
            local isMissile = t.kind == 'missile'
            local isUtility = t.kind == 'mining_laser' or t.kind == 'salvaging_laser'
            local actionName = 'turret_slot_' .. tostring(slot.slot)
            local perSlotActive = (HotbarSystem and HotbarSystem.isActive and HotbarSystem.isActive(actionName)) or false

            -- Allow utility turrets even in safe zones, but require canFire for weapons
            local allow = false
            if isUtility then
                allow = (perSlotActive or manualFireAll) and (not isMissile)
            else
                allow = canFire and (perSlotActive or manualFireAll) and (not isMissile)
            end

            -- Debug: log hotbar/turret gating decisions

            -- Special case: allow missiles to fire when locked onto a target
            if isMissile and missileLockFire then
                allow = true
            end

            t:update(dt, nil, not allow, world)
        end
    end

    
end

return PlayerSystem
