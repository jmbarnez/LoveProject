-- Player Dash System
-- Handles dash mechanics, cooldown, and energy management
-- Extracted from main PlayerSystem.update()

local Config = require("src.content.config")
local PlayerDebug = require("src.systems.player.debug")

local DashSystem = {}

-- Process dash input and execute dash if conditions are met
function DashSystem.processDash(player, state, input, body, dt, modalActive)
    if modalActive then
        return -- Don't process dash when modal is active
    end

    -- Update cooldown
    state.dash_cooldown = math.max(0, (state.dash_cooldown or 0) - dt)
    
    -- Check if dash is queued
    if not player._dashQueued then
        return
    end

    -- Clear dash queue
    player._dashQueued = false

    -- Check cooldown
    if (state.dash_cooldown or 0) > 0 then
        PlayerDebug.logDash(true, state.dash_cooldown, false, 0)
        return
    end

    -- Check energy requirements
    local energy = player.components and player.components.energy
    local canEnergy = not energy or (energy.energy or 0) >= ((Config.DASH and Config.DASH.ENERGY_COST) or 0)
    
    if not canEnergy then
        PlayerDebug.logDash(true, 0, false, energy and energy.energy or 0)
        return
    end

    -- Calculate dash direction
    local dashDirX, dashDirY = DashSystem.calculateDashDirection(player, input, body)
    
    if dashDirX == 0 and dashDirY == 0 then
        return -- No valid dash direction
    end

    -- Execute dash
    DashSystem.executeDash(player, state, body, dashDirX, dashDirY, energy)
    
    PlayerDebug.logDash(true, 0, true, energy and energy.energy or 0)
end

-- Calculate dash direction (toward cursor or forward)
function DashSystem.calculateDashDirection(player, input, body)
    local ppos = player.components.position
    local dashDirX, dashDirY = 0, 0
    
    -- Try to dash toward cursor first
    if input and input.aimx and input.aimy then
        local dx = input.aimx - ppos.x
        local dy = input.aimy - ppos.y
        local dist = math.sqrt(dx*dx + dy*dy)
        if dist > 1 then
            dashDirX, dashDirY = dx / dist, dy / dist
        end
    end
    
    -- Fallback: dash in facing direction
    if dashDirX == 0 and dashDirY == 0 then
        dashDirX = math.cos(body.angle or 0)
        dashDirY = math.sin(body.angle or 0)
    end
    
    return dashDirX, dashDirY
end

-- Execute the actual dash
function DashSystem.executeDash(player, state, body, dashDirX, dashDirY, health)
    -- Get dash configuration
    local dashConfig = Config.DASH or {}
    local desiredSpeed = dashConfig.SPEED or 900
    local iframes = dashConfig.IFRAMES or 0.25
    local cooldown = dashConfig.COOLDOWN or 0.9
    local energyCost = dashConfig.ENERGY_COST or 0
    
    -- Apply dash impulse
    local impulseX = dashDirX * desiredSpeed * (body.mass or 500)
    local impulseY = dashDirY * desiredSpeed * (body.mass or 500)
    
    if body.applyImpulse then 
        body:applyImpulse(impulseX, impulseY) 
    end
    
    -- Apply i-frames during dash
    player.iFrames = math.max(player.iFrames or 0, iframes)
    
    -- Consume energy
    if health then
        health.energy = math.max(0, (health.energy or 0) - energyCost)
    end
    
    -- Set cooldown
    state.dash_cooldown = cooldown
    
    -- Play sound effect
    DashSystem.playDashSound(player)
end

-- Play dash sound effect
function DashSystem.playDashSound(player)
    local Sound = require("src.core.sound")
    if Sound and Sound.triggerEvent then
        if player.components and player.components.position then
            Sound.triggerEvent('thruster_activate', player.components.position.x, player.components.position.y)
        else
            Sound.triggerEvent('thruster_activate')
        end
    end
end

-- Queue a dash for the next update
function DashSystem.queueDash(player)
    player._dashQueued = true
end

-- Check if dash is available (not on cooldown and has energy)
function DashSystem.isDashAvailable(player, state)
    local energy = player.components and player.components.energy
    local hasEnergy = not energy or (energy.energy or 0) >= ((Config.DASH and Config.DASH.ENERGY_COST) or 0)
    local offCooldown = (state.dash_cooldown or 0) <= 0
    
    return hasEnergy and offCooldown
end

-- Get dash cooldown remaining
function DashSystem.getCooldownRemaining(state)
    return state.dash_cooldown or 0
end

-- Get dash energy cost
function DashSystem.getEnergyCost()
    local dashConfig = Config.DASH or {}
    return dashConfig.ENERGY_COST or 0
end

-- Get dash speed
function DashSystem.getDashSpeed()
    local dashConfig = Config.DASH or {}
    return dashConfig.SPEED or 900
end

-- Get dash iframes duration
function DashSystem.getIframesDuration()
    local dashConfig = Config.DASH or {}
    return dashConfig.IFRAMES or 0.25
end

return DashSystem
