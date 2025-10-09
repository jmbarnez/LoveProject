local Sound = require("src.core.sound")
local Effects = require("src.systems.effects")
local Radius = require("src.systems.collision.radius")
local StationShields = require("src.systems.collision.station_shields")
local Log = require("src.core.log")

local TurretEffects = {}

-- Global sound tracking for utility beams
local activeUtilitySounds = {}

-- Play firing sound effects based on turret type and ID
function TurretEffects.playFiringSound(turret)
    if not turret or not turret.kind then return end

    local x, y = 0, 0
    if turret.owner and turret.owner.components and turret.owner.components.position then
        x = turret.owner.components.position.x
        y = turret.owner.components.position.y
    end

    -- Use specific weapon sounds based on turret ID for better audio variety
    if turret.id == "railgun_turret" then
        Sound.triggerEvent('weapon_railgun_turret_fire', x, y)
    elseif turret.id == "low_power_laser" then
        Sound.triggerEvent('weapon_low_power_laser_fire', x, y)
    elseif turret.id == "missile_launcher_mk1" then
        Sound.triggerEvent('weapon_missile_launcher_fire', x, y)
    -- Fallback to generic weapon sounds for other turrets
    elseif turret.kind == "missile" then
        Sound.triggerEvent('weapon_missile_fire', x, y)
    elseif turret.kind == "laser" then
        Sound.triggerEvent('weapon_laser_fire', x, y)
    elseif turret.kind == "gun" or turret.kind == "projectile" then
        Sound.triggerEvent('weapon_gun_fire', x, y)
    elseif turret.kind == "mining_laser" then
        -- Always stop any existing sound first, then start new one
        if turret.miningSoundInstance then
            TurretEffects.stopMiningSound(turret)
        end
        -- Store the sound instance for continuous mining laser
        turret.miningSoundInstance = Sound.triggerEvent('weapon_mining_laser', x, y)
        turret.miningSoundActive = true
        -- Track this sound globally
        if turret.miningSoundInstance then
            activeUtilitySounds[turret.miningSoundInstance] = turret
        end
    elseif turret.kind == "salvaging_laser" then
        -- Always stop any existing sound first, then start new one
        if turret.salvagingSoundInstance then
            TurretEffects.stopSalvagingSound(turret)
        end
        turret.salvagingSoundInstance = Sound.triggerEvent('weapon_salvaging_laser', x, y)
        turret.salvagingSoundActive = true
        -- Track this sound globally
        if turret.salvagingSoundInstance then
            activeUtilitySounds[turret.salvagingSoundInstance] = turret
        end
    end
end

-- Stop mining laser sound
function TurretEffects.stopMiningSound(turret)
    if turret then
        -- Stop the continuous mining sound
        if turret.miningSoundInstance then
            -- Remove from global tracking
            activeUtilitySounds[turret.miningSoundInstance] = nil
            -- Force stop the sound instance
            if turret.miningSoundInstance.stop then
                turret.miningSoundInstance:stop()
            end
            -- Also try to pause it as a backup
            if turret.miningSoundInstance.pause then
                turret.miningSoundInstance:pause()
            end
            -- Set volume to 0 as additional safety
            if turret.miningSoundInstance.setVolume then
                turret.miningSoundInstance:setVolume(0)
            end
        end
        turret.miningSoundInstance = nil
        turret.miningSoundActive = false
    end
end

-- Stop salvaging laser sound
function TurretEffects.stopSalvagingSound(turret)
    if turret then
        if turret.salvagingSoundInstance then
            -- Remove from global tracking
            activeUtilitySounds[turret.salvagingSoundInstance] = nil
            -- Force stop the sound instance
            if turret.salvagingSoundInstance.stop then
                turret.salvagingSoundInstance:stop()
            end
            -- Also try to pause it as a backup
            if turret.salvagingSoundInstance.pause then
                turret.salvagingSoundInstance:pause()
            end
            -- Set volume to 0 as additional safety
            if turret.salvagingSoundInstance.setVolume then
                turret.salvagingSoundInstance:setVolume(0)
            end
        end
        turret.salvagingSoundInstance = nil
        turret.salvagingSoundActive = false
    end
end

-- Stop all utility beam sounds (cleanup function)
function TurretEffects.stopAllUtilityBeamSounds()
    -- This function can be called to stop any orphaned utility beam sounds
    -- It's a safety net for cleanup
    for soundInstance, turret in pairs(activeUtilitySounds) do
        if soundInstance and soundInstance.stop then
            soundInstance:stop()
        end
        if soundInstance and soundInstance.pause then
            soundInstance:pause()
        end
        if soundInstance and soundInstance.setVolume then
            soundInstance:setVolume(0)
        end
        -- Clear turret references
        if turret then
            turret.miningSoundInstance = nil
            turret.miningSoundActive = false
            turret.salvagingSoundInstance = nil
            turret.salvagingSoundActive = false
        end
    end
    activeUtilitySounds = {}
end

-- Stop all sounds for a specific turret
function TurretEffects.stopAllTurretSounds(turret)
    if turret then
        if turret.kind == "mining_laser" then
            TurretEffects.stopMiningSound(turret)
        elseif turret.kind == "salvaging_laser" then
            TurretEffects.stopSalvagingSound(turret)
        end
    end
end

-- Force stop all utility beam sounds (emergency cleanup)
function TurretEffects.forceStopAllUtilityBeamSounds()
    for soundInstance, turret in pairs(activeUtilitySounds) do
        if soundInstance then
            -- Try all possible stop methods
            if soundInstance.stop then
                soundInstance:stop()
            end
            if soundInstance.pause then
                soundInstance:pause()
            end
            if soundInstance.setVolume then
                soundInstance:setVolume(0)
            end
            -- Try to release the source
            if soundInstance.release then
                soundInstance:release()
            end
        end
    end
    activeUtilitySounds = {}
end

-- Clean up orphaned sounds (call this periodically)
function TurretEffects.cleanupOrphanedSounds()
    local toRemove = {}
    for soundInstance, turret in pairs(activeUtilitySounds) do
        if not soundInstance or not soundInstance.isPlaying or not soundInstance:isPlaying() then
            table.insert(toRemove, soundInstance)
        end
    end
    for _, soundInstance in ipairs(toRemove) do
        activeUtilitySounds[soundInstance] = nil
    end
    if #toRemove > 0 then
    end
end



-- Create impact effects
function TurretEffects.createImpactEffect(turret, x, y, target, impactType)
    -- If turret has no impact config and there's no global Effects.spawnImpact, nothing to do
    local impactConfig = turret and turret.impact
    if not Effects or not Effects.spawnImpact then return end

    if not target or not target.components or not target.components.position then
        return
    end

    local ex = target.components.position.x
    local ey = target.components.position.y

    -- Determine effective radius for impact visuals
    local targetRadius = Radius.calculateEffectiveRadius and Radius.calculateEffectiveRadius(target)

    -- Determine whether the hit affected shields
    local hasShields = false
    if target.components and target.components.health and target.components.health.shield > 0 then
        hasShields = true
    elseif StationShields and StationShields.hasActiveShield and StationShields.isStation(target) and StationShields.hasActiveShield(target) then
        hasShields = true
    end

    local impactKind = hasShields and 'shield' or 'hull'
    local impactAngle = 0
    if ex and ey and x and y then
        impactAngle = math.atan2(y - ey, x - ex)
    end

    -- Pass through bullet kind for styling (laser/mining/missile)
    local bulletKind = turret and turret.kind

    -- Collision effects are now handled exclusively by the unified collision system
end


-- Handle beam rendering for continuous weapons
function TurretEffects.renderBeam(turret, startX, startY, endX, endY, hitTarget)
    if turret.kind ~= "laser" and turret.kind ~= "mining_laser" and turret.kind ~= "salvaging_laser" then
        return
    end

    if not turret.tracer then return end

    local color = turret.tracer.color
    local width = turret.tracer.width
    local coreRadius = turret.tracer.coreRadius
    
    -- Apply energy-based visual effects
    local energyLevel = turret._currentEnergyLevel or 1.0
    local smoothing = turret._energySmoothing
    
    if energyLevel < 1.0 and smoothing then
        -- Calculate visual intensity based on energy level
        local visualIntensity = 1.0
        
        if energyLevel <= smoothing.criticalEnergyThreshold then
            -- Critical energy: pulsing effect
            local time = love.timer.getTime()
            visualIntensity = 0.3 + 0.4 * math.sin(time * 8) -- Pulse between 0.3 and 0.7
        elseif energyLevel <= smoothing.lowEnergyThreshold then
            -- Low energy: dimmed
            visualIntensity = 0.4 + (energyLevel / smoothing.lowEnergyThreshold) * 0.4 -- 0.4 to 0.8
        else
            -- Normal energy: slight dimming
            visualIntensity = 0.8 + (energyLevel - smoothing.lowEnergyThreshold) / (1.0 - smoothing.lowEnergyThreshold) * 0.2 -- 0.8 to 1.0
        end
        
        -- Apply intensity to color
        color = {
            color[1] * visualIntensity,
            color[2] * visualIntensity,
            color[3] * visualIntensity,
            color[4] * visualIntensity
        }
        
        -- Reduce width for low energy
        width = width * (0.5 + 0.5 * visualIntensity)
        coreRadius = coreRadius * (0.5 + 0.5 * visualIntensity)
    end

    -- Calculate beam properties
    local dx = endX - startX
    local dy = endY - startY
    local distance = math.sqrt(dx * dx + dy * dy)
    local angle = math.atan2(dy, dx)
    
    -- Special rendering for different laser types
    if turret.kind == "mining_laser" then
        TurretEffects.renderWavyBeam(startX, startY, endX, endY, color, width, coreRadius, distance, angle)
    elseif turret.kind == "salvaging_laser" then
        -- Salvaging laser uses wavy beam effect like mining laser
        TurretEffects.renderWavyBeam(startX, startY, endX, endY, color, width, coreRadius, distance, angle)
    elseif turret.kind == "laser" then
        -- Combat laser uses simple straight beam
        TurretEffects.renderStraightBeam(startX, startY, endX, endY, color, width, coreRadius)
    else
        -- Draw straight beam for other lasers
        love.graphics.setColor(color[1], color[2], color[3], color[4])
        love.graphics.setLineWidth(width)
        love.graphics.line(startX, startY, endX, endY)

        -- Draw beam core (brighter center)
        if coreRadius > 0 then
            love.graphics.setColor(math.min(1, color[1] + 0.2), math.min(1, color[2] + 0.2), math.min(1, color[3] + 0.2), color[4] * 0.9)
            love.graphics.setLineWidth(coreRadius)
            love.graphics.line(startX, startY, endX, endY)
        end
    end

    -- Reset graphics state
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

-- Render a wavy beam for mining laser
function TurretEffects.renderWavyBeam(startX, startY, endX, endY, color, width, coreRadius, distance, angle)
    local time = love.timer.getTime()
    local waveAmplitude = 8  -- How wavy the beam is
    local waveFrequency = 0.02  -- How many waves per pixel
    local waveSpeed = 3  -- How fast the waves move
    local straightLength = 30  -- Length of straight section from muzzle
    
    -- Calculate number of segments for smooth wave
    local segments = math.max(20, math.floor(distance / 10))
    
    -- Create wave points
    local points = {}
    for i = 0, segments do
        local t = i / segments
        local x = startX + (endX - startX) * t
        local y = startY + (endY - startY) * t
        
        -- Calculate distance from start point
        local currentDistance = t * distance
        
        -- Only apply wave offset after the straight section
        local waveOffset = 0
        if currentDistance > straightLength then
            -- Gradually increase wave amplitude from 0 to full amplitude
            local waveProgress = (currentDistance - straightLength) / (distance - straightLength)
            local perpAngle = angle + math.pi / 2
            waveOffset = math.sin(t * distance * waveFrequency + time * waveSpeed) * waveAmplitude * waveProgress
        end
        
        local waveX = x + math.cos(angle + math.pi / 2) * waveOffset
        local waveY = y + math.sin(angle + math.pi / 2) * waveOffset
        
        table.insert(points, waveX)
        table.insert(points, waveY)
    end
    
    -- Draw wavy beam
    love.graphics.setColor(color[1], color[2], color[3], color[4])
    love.graphics.setLineWidth(width)
    love.graphics.line(points)
    
    -- Draw wavy beam core (brighter center)
    if coreRadius > 0 then
        love.graphics.setColor(math.min(1, color[1] + 0.2), math.min(1, color[2] + 0.2), math.min(1, color[3] + 0.2), color[4] * 0.9)
        love.graphics.setLineWidth(coreRadius)
        love.graphics.line(points)
    end
end

-- Render a simple straight beam for combat lasers
function TurretEffects.renderStraightBeam(startX, startY, endX, endY, color, width, coreRadius)
    -- Draw outer glow (very faint)
    love.graphics.setColor(color[1], color[2], color[3], color[4] * 0.15)
    love.graphics.setLineWidth(width + 1.5)
    love.graphics.line(startX, startY, endX, endY)
    
    -- Draw main beam
    love.graphics.setColor(color[1], color[2], color[3], color[4])
    love.graphics.setLineWidth(width)
    love.graphics.line(startX, startY, endX, endY)
    
    -- Draw bright core
    if coreRadius > 0 then
        love.graphics.setColor(math.min(1, color[1] + 0.2), math.min(1, color[2] + 0.2), math.min(1, color[3] + 0.2), color[4])
        love.graphics.setLineWidth(coreRadius)
        love.graphics.line(startX, startY, endX, endY)
    end
end

-- Render a tazer-style electrical beam for salvaging laser
function TurretEffects.renderTazerBeam(startX, startY, endX, endY, color, width, coreRadius, distance, angle)
    local time = love.timer.getTime()
    local segments = math.max(30, math.floor(distance / 8))  -- More segments for jagged effect
    local perpAngle = angle + math.pi / 2
    local straightLength = 25  -- Length of straight section from muzzle
    
    -- Create jagged electrical points
    local points = {}
    for i = 0, segments do
        local t = i / segments
        local x = startX + (endX - startX) * t
        local y = startY + (endY - startY) * t
        
        -- Calculate distance from start point
        local currentDistance = t * distance
        
        -- Only apply electrical crackling after the straight section
        local crackleOffset = 0
        if currentDistance > straightLength then
            -- Gradually increase crackle amplitude from 0 to full amplitude
            local crackleProgress = (currentDistance - straightLength) / (distance - straightLength)
            
            -- Add random electrical crackling perpendicular to beam
            local crackleAmplitude = (12 + math.random() * 8) * crackleProgress  -- Variable crackle intensity
            local crackleFreq = 0.05 + math.random() * 0.03  -- Random frequency variation
            crackleOffset = math.sin(t * distance * crackleFreq + time * 8 + math.random() * 10) * crackleAmplitude
            
            -- Add some randomness for electrical effect
            local randomOffset = (math.random() - 0.5) * 6 * crackleProgress
            crackleOffset = crackleOffset + randomOffset
        end
        
        local crackleX = x + math.cos(perpAngle) * crackleOffset
        local crackleY = y + math.sin(perpAngle) * crackleOffset
        
        table.insert(points, crackleX)
        table.insert(points, crackleY)
    end
    
    -- Draw main electrical beam with jagged appearance
    love.graphics.setColor(color[1], color[2], color[3], color[4])
    love.graphics.setLineWidth(width)
    love.graphics.line(points)
    
    -- Draw electrical core (brighter, more intense)
    if coreRadius > 0 then
        love.graphics.setColor(math.min(1, color[1] + 0.3), math.min(1, color[2] + 0.3), math.min(1, color[3] + 0.3), color[4])
        love.graphics.setLineWidth(coreRadius)
        love.graphics.line(points)
    end
    
    -- Add electrical sparks along the beam
    local sparkCount = math.floor(distance / 20)
    for i = 1, sparkCount do
        local sparkT = (i / sparkCount) + (math.random() - 0.5) * 0.1
        if sparkT >= 0 and sparkT <= 1 then
            local sparkX = startX + (endX - startX) * sparkT
            local sparkY = startY + (endY - startY) * sparkT
            
            -- Add random spark offset
            local sparkOffsetX = (math.random() - 0.5) * 15
            local sparkOffsetY = (math.random() - 0.5) * 15
            
            -- Draw small spark
            love.graphics.setColor(1, 1, 1, 0.8)  -- Bright white sparks
            love.graphics.setLineWidth(1)
            love.graphics.line(sparkX, sparkY, sparkX + sparkOffsetX, sparkY + sparkOffsetY)
        end
    end
end

-- Handle special effects for different weapon types
function TurretEffects.handleSpecialEffects(turret, target, hitX, hitY)
    if turret.kind == "mining_laser" and target and target.components and target.components.mineable then
        TurretEffects.createMiningParticles(hitX, hitY)
    elseif turret.kind == "salvaging_laser" and target and target.components and target.components.wreckage then
        TurretEffects.createSalvageParticles(hitX, hitY)
    end
end



function TurretEffects.createMiningParticles(x, y)
    for i=1, 6 do
        local a = math.random() * math.pi * 2
        local s = 80 + math.random()*60
        Effects.add({ type='spark', x=x, y=y, vx=math.cos(a)*s, vy=math.sin(a)*s, t=0,
            life=0.3 + math.random()*0.2, color={0.8,0.6,0.3,0.9}, size=2 })
    end
    Effects.add({ type='ring', x=x, y=y, r0=3, r1=20, w0=4, w1=1, t=0, life=0.3, color={0.7,0.5,0.2,0.5} })
end

function TurretEffects.createSalvageParticles(x, y)
    for i=1, 8 do
        local a = math.random() * math.pi * 2
        local s = 50 + math.random()*100
        Effects.add({ type='spark', x=x, y=y, vx=math.cos(a)*s, vy=math.sin(a)*s, t=0,
            life=0.5 + math.random()*0.3, color={0.7,0.7,0.7,0.8}, size=1.5 })
    end
    for i=1,3 do
        local a = math.random()*math.pi*2
        local rr = 5 + math.random()*10
        Effects.add({ type='smoke', x=x+math.cos(a)*rr, y=y+math.sin(a)*rr, r0=4, rg=20, t=0, life=0.6+math.random()*0.4,
            color={0.5,0.5,0.5,0.3} })
    end
end

return TurretEffects
