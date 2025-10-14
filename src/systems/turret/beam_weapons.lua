-- Collision detection is now handled by Windfield physics
local TurretEffects = require("src.systems.turret.effects")
local Log = require("src.core.log")
local TargetUtils = require("src.core.target_utils")
local Radius = require("src.systems.collision.radius")
local Geometry = require("src.systems.collision.geometry")
local PhysicsSystem = require("src.systems.physics")

local BeamWeapons = {}

-- Helper function to send beam weapon fire request to host
local function sendBeamWeaponFireRequest(turret, sx, sy, angle, beamLength, damageConfig, deltaTime)
    local NetworkSession = require("src.core.network.session")
    local networkManager = NetworkSession.getManager()

    if networkManager and networkManager:isMultiplayer() and not networkManager:isHost() then
        -- Client: send beam weapon fire request to host
        local request = {
            type = "beam_weapon_fire_request",
            turretId = turret.id or tostring(turret),
            position = { x = sx, y = sy },
            angle = angle,
            beamLength = beamLength,
            damageConfig = damageConfig,
            deltaTime = deltaTime,
            ownerId = turret.owner and turret.owner.id or nil
        }
        
        -- Send via network manager
        if networkManager.sendWeaponFireRequest then
            local json = require("src.libs.json")
            networkManager:sendWeaponFireRequest(request)
        end
        return true
    end
    
    return false
end

-- Handle laser turret firing (hitscan beam weapons)
function BeamWeapons.updateLaserTurret(turret, dt, target, locked, world)
    if locked or not turret:canFire() then
        turret.beamActive = false
        turret.beamTarget = nil
        turret.beamStartX = nil
        turret.beamStartY = nil
        turret.beamEndX = nil
        turret.beamEndY = nil
        turret.has_hit = false
        turret.cooldown = 0
        turret.cooldownOverride = 0
        return
    end

    local Turret = require("src.systems.turret.core")
    local shipPos = turret.owner.components and turret.owner.components.position

    -- Determine aim angle first, then compute muzzle and precise distance from muzzle to cursor
    local cursorPos = turret.owner.cursorWorldPos
    local initialAngle
    local angle
    local desiredDistance

    if cursorPos and shipPos then
        initialAngle = math.atan2(cursorPos.y - shipPos.y, cursorPos.x - shipPos.x)
    elseif target and target.components and target.components.position then
        local tx = target.components.position.x
        local ty = target.components.position.y
        if shipPos then
            initialAngle = math.atan2(ty - shipPos.y, tx - shipPos.x)
        else
            initialAngle = math.atan2(ty, tx)
        end
    elseif shipPos then
        initialAngle = shipPos.angle
        desiredDistance = turret.maxRange or 0
    else
        initialAngle = 0
        desiredDistance = turret.maxRange or 0
    end

    turret.currentAimAngle = initialAngle

    -- Compute muzzle world position using the provisional aim
    local sx, sy = Turret.getTurretWorldPosition(turret)

    -- Refine aim using the muzzle as the origin so the beam terminates at the cursor/target
    if cursorPos then
        angle = math.atan2(cursorPos.y - sy, cursorPos.x - sx)
    elseif target and target.components and target.components.position then
        local tx = target.components.position.x
        local ty = target.components.position.y
        angle = math.atan2(ty - sy, tx - sx)
    else
        angle = initialAngle
    end

    if angle ~= turret.currentAimAngle then
        turret.currentAimAngle = angle
        sx, sy = Turret.getTurretWorldPosition(turret)
    else
        turret.currentAimAngle = angle
    end

    -- Compute desired distance from muzzle to cursor or target
    local dx, dy
    if cursorPos then
        dx = cursorPos.x - sx
        dy = cursorPos.y - sy
        desiredDistance = math.sqrt(dx * dx + dy * dy)
    elseif target and target.components and target.components.position then
        local tx = target.components.position.x
        local ty = target.components.position.y
        dx = tx - sx
        dy = ty - sy
        desiredDistance = math.sqrt(dx * dx + dy * dy)
    end

    local maxRange = turret.maxRange
    if not maxRange or maxRange <= 0 then
        maxRange = desiredDistance or 0
    end
    local beamLength = math.min(desiredDistance or maxRange, maxRange)

    local endX, endY
    if dx and dy then
        if desiredDistance and desiredDistance > 0 then
            local scale = beamLength / desiredDistance
            endX = sx + dx * scale
            endY = sy + dy * scale
        else
            beamLength = 0
            endX = sx
            endY = sy
        end
    else
        endX = sx + math.cos(angle) * beamLength
        endY = sy + math.sin(angle) * beamLength
    end

    local hitTarget, hitX, hitY, hitSurface = BeamWeapons.performLaserHitscan(
        sx, sy, endX, endY, turret, world
    )

    local wasActive = turret.beamActive

    local beamEndX = hitX or endX
    local beamEndY = hitY or endY

    local energyStarved = false
    local energyLevel = 1.0 -- Full energy by default
    
    if turret.energyPerSecond and turret.energyPerSecond > 0 and turret.owner and turret.owner.components and turret.owner.components.energy and turret.owner.isPlayer then
        local currentEnergy = turret.owner.components.energy.energy or 0
        local maxEnergy = turret.owner.components.energy.maxEnergy or 100
        local energyCost = turret.energyPerSecond * dt
        local resumeMultiplier = turret.resumeEnergyMultiplier or 2
        local resumeThreshold = turret.minResumeEnergy or (resumeMultiplier * energyCost)
        resumeThreshold = math.max(resumeThreshold, energyCost)

        -- Calculate energy level (0.0 to 1.0)
        energyLevel = math.max(0, currentEnergy / maxEnergy)
        
        -- Initialize energy smoothing variables
        if not turret._energySmoothing then
            turret._energySmoothing = {
                gracePeriod = 0.3, -- 300ms grace period before cutting off
                graceTimer = 0,
                lowEnergyThreshold = 0.15, -- Start dimming at 15% energy
                criticalEnergyThreshold = 0.05, -- Critical at 5% energy
                lastEnergyLevel = 1.0
            }
        end
        
        local smoothing = turret._energySmoothing
        
        -- Update grace timer
        if currentEnergy < energyCost then
            smoothing.graceTimer = smoothing.graceTimer + dt
        else
            smoothing.graceTimer = 0
        end
        
        -- Determine if we should cut off the beam
        local shouldCutOff = false
        if turret._energyStarved then
            if currentEnergy >= resumeThreshold then
                turret._energyStarved = false
                smoothing.graceTimer = 0
            else
                shouldCutOff = true
            end
        else
            if currentEnergy < energyCost then
                if smoothing.graceTimer >= smoothing.gracePeriod then
                    turret._energyStarved = true
                    shouldCutOff = true
                end
            else
                -- We have enough energy, consume it
                turret.owner.components.energy.energy = math.max(0, currentEnergy - energyCost)
            end
        end
        
        -- Energy warning notifications (only show once per energy state)
        local currentTime = love.timer.getTime()
        local lastEnergyWarning = turret._lastEnergyWarning or 0
        local energyWarningCooldown = 3.0 -- 3 seconds between warnings
        local lastWarningLevel = turret._lastWarningLevel or "none"
        
        if currentTime - lastEnergyWarning > energyWarningCooldown then
            local currentWarningLevel = "none"
            if energyLevel <= smoothing.criticalEnergyThreshold and not turret._energyStarved then
                currentWarningLevel = "critical"
            elseif energyLevel <= smoothing.lowEnergyThreshold and not turret._energyStarved then
                currentWarningLevel = "low"
            end
            
            -- Only show notification if warning level changed
            if currentWarningLevel ~= "none" and currentWarningLevel ~= lastWarningLevel then
                local Notifications = require("src.ui.notifications")
                if Notifications and Notifications.add then
                    if currentWarningLevel == "critical" then
                        Notifications.add("Critical energy! Laser power failing!", "warning")
                    elseif currentWarningLevel == "low" then
                        Notifications.add("Low energy - laser power reduced", "info")
                    end
                end
                turret._lastEnergyWarning = currentTime
                turret._lastWarningLevel = currentWarningLevel
            end
        end
        
        -- Reset warning level when energy is restored
        if energyLevel > smoothing.lowEnergyThreshold then
            turret._lastWarningLevel = "none"
        end
        
        energyStarved = shouldCutOff
    end

    if energyStarved then
        turret.beamActive = false
        turret.beamTarget = nil
        turret.beamStartX = nil
        turret.beamStartY = nil
        turret.beamEndX = nil
        turret.beamEndY = nil
        turret.has_hit = false
        turret.cooldown = 0
        turret.cooldownOverride = 0
        return
    end

    turret.beamActive = true
    turret.beamStartX = sx
    turret.beamStartY = sy
    turret.beamEndX = beamEndX
    turret.beamEndY = beamEndY
    turret.beamTarget = hitTarget
    turret.has_hit = hitTarget ~= nil
    
    -- Store energy level for rendering system
    turret._currentEnergyLevel = energyLevel

    -- Try to send beam weapon fire request first (for clients)
    local damageConfig
    if turret.damage_range then
        damageConfig = {
            min = turret.damage_range.min,
            max = turret.damage_range.max,
            skill = turret.skillId,
            damagePerSecond = turret.damagePerSecond
        }
    else
        damageConfig = {
            min = 1,
            max = 2,
            value = turret.damagePerSecond or 1,
            skill = turret.skillId,
            damagePerSecond = turret.damagePerSecond
        }
    end
    
    local requestSent = sendBeamWeaponFireRequest(turret, sx, sy, angle, beamLength, damageConfig, dt)

    -- If not a client or request failed, process beam locally (for host)
    if not requestSent then
        -- Host processes beam locally
    end

    if hitTarget then
        if TargetUtils.isEnemyTarget(hitTarget, turret.owner) then
            local damagePerSecond = turret.damagePerSecond
            if not damagePerSecond and turret.damage_range then
                damagePerSecond = (turret.damage_range.min + turret.damage_range.max) * 0.5
            end

            if damagePerSecond and damagePerSecond > 0 then
                local damageAmount = damagePerSecond * dt
                if damageAmount > 0 then
                    local damageMeta
                    if turret.damage_range then
                        damageMeta = {
                            min = turret.damage_range.min,
                            max = turret.damage_range.max,
                            value = damageAmount,
                            skill = turret.skillId
                        }
                    end

                    BeamWeapons.applyLaserDamage(hitTarget, damageAmount, turret.owner, turret.skillId, damageMeta)
                else
                end
            else
            end

            TurretEffects.createImpactEffect(turret, hitX, hitY, hitTarget, "laser")
        else
            TurretEffects.createImpactEffect(turret, hitX, hitY, hitTarget, "laser")
        end
    end

    turret.cooldown = 0
    turret.cooldownOverride = 0

    if not wasActive then
        TurretEffects.playFiringSound(turret)
    end
end

-- Perform hitscan collision detection for laser weapons (collides with ALL objects)
function BeamWeapons.performLaserHitscan(startX, startY, endX, endY, turret, world)
    if not world then
        return nil, endX, endY, nil
    end

    local physicsManager = PhysicsSystem.getManager()
    if not physicsManager then
        return nil, endX, endY, nil
    end

    local result = physicsManager:raycast(startX, startY, endX, endY, {
        ignore = { turret.owner },
        includeDead = false,
        filter = function(entity, collider)
            if entity == turret.owner then
                return false
            end
            if not entity or not entity.components then
                return false
            end
            if entity.dead then
                return false
            end
            if not entity.components.position then
                return false
            end
            if not entity.components.collidable and not entity.components.windfield_physics then
                return false
            end
            return true
        end
    })
    
    -- Debug logging for laser hitscan
    if result then
        Log.debug("beam_weapons", "Laser hitscan hit: %s (class: %s) at (%.1f, %.1f)", 
                 result.entity.id or "unknown", result.collisionClass or "unknown", 
                 result.x or 0, result.y or 0)
    else
        Log.debug("beam_weapons", "Laser hitscan missed - no targets in range")
    end

    if not result then
        return nil, endX, endY, nil
    end

    local entity = result.entity
    local hitX = result.x
    local hitY = result.y

    local CollisionEffects = require("src.systems.collision.effects")
    local targetHasShield = CollisionEffects.hasShield and CollisionEffects.hasShield(entity)

    local targetRadius
    if targetHasShield then
        targetRadius = Radius.getShieldRadius(entity) or Radius.getHullRadius(entity) or 20
        if entity.components and entity.components.position then
            local ex = entity.components.position.x or 0
            local ey = entity.components.position.y or 0
            local success, shieldX, shieldY = Geometry.calculateShieldHitPoint(startX, startY, hitX, hitY, ex, ey, targetRadius)
            if success then
                hitX, hitY = shieldX, shieldY
            else
                local dirX = hitX - ex
                local dirY = hitY - ey
                local dist = math.sqrt(dirX * dirX + dirY * dirY)
                if dist > 1e-4 then
                    local scale = targetRadius / dist
                    hitX = ex + dirX * scale
                    hitY = ey + dirY * scale
                end
            end
        end
    else
        targetRadius = Radius.getHullRadius(entity)
        if (not targetRadius or targetRadius <= 0) and result.collider and result.collider.getRadius then
            targetRadius = result.collider:getRadius()
        end
        targetRadius = targetRadius or 20
    end

    local Effects = require("src.systems.effects")
    local now = (love and love.timer and love.timer.getTime and love.timer.getTime()) or 0
    local isHardSurface = false
    if entity.components and entity.components.mineable then
        isHardSurface = true
    elseif entity.components and entity.components.station then
        isHardSurface = true
    elseif entity.tag == "station" then
        isHardSurface = true
    elseif entity.components and entity.components.interactable and entity.components.interactable.requiresKey == "reward_crate_key" then
        isHardSurface = true
    elseif entity.subtype == "reward_crate" then
        isHardSurface = true
    end

    local isHullSurface = entity.components and entity.components.hull ~= nil

    local hitSurface = targetHasShield and "shield" or (isHullSurface and "hull" or "surface")

    if (not targetHasShield) and (isHardSurface or isHullSurface) and Effects.spawnLaserSparks then
        local impactAngle = math.atan2(hitY - startY, hitX - startX)
        local sparkColor = {1.0, 0.8, 0.3, 0.8}

        if turret.type == "mining_laser" then
            sparkColor = {1.0, 0.7, 0.2, 0.8}
        elseif turret.type == "salvaging_laser" then
            sparkColor = {1.0, 0.2, 0.6, 0.8}
        elseif turret.type == "healing_laser" then
            sparkColor = {0.0, 1.0, 0.5, 0.8}
        elseif turret.type == "laser" then
            sparkColor = {0.3, 0.7, 1.0, 0.8}
        end

        Effects.spawnLaserSparks(hitX, hitY, impactAngle, sparkColor)
    elseif CollisionEffects.canEmitCollisionFX(turret, entity, now) then
        local beamRadius = 1
        CollisionEffects.createCollisionEffects(
            turret,
            entity,
            hitX,
            hitY,
            hitX,
            hitY,
            0,
            0,
            beamRadius,
            targetRadius,
            nil,
            nil,
            true
        )
    end

    return entity, hitX, hitY, hitSurface
end


-- Apply damage from laser weapons
function BeamWeapons.applyLaserDamage(target, damage, source, skillId, damageMeta)
    if not target.components or not target.components.hull then
        return
    end

    -- Validate damage value
    if not damage or damage <= 0 then
        return -- No damage to apply
    end

    local hull = target.components.hull
    local shield = target.components.shield

    -- Apply global enemy damage multiplier (x2)
    local baseDamage = damage
    if source and (source.isEnemy or (source.components and source.components.ai)) then
        baseDamage = damage * 2
    end

    -- Laser weapons: 15% more damage to shields, half damage to hulls
    -- Use the same calculation logic as CollisionEffects.applyDamage for consistency
    local shieldBefore = (shield and shield.shield) or 0
    local shieldDamage = math.min(shieldBefore, baseDamage * 1.15) -- 15% more damage to shields
    local remainingDamage = baseDamage - (shieldDamage / 1.15) -- Convert back to original damage for hull calculation
    local hullDamage = 0
    
    if remainingDamage > 0 then
        hullDamage = remainingDamage * 0.5 -- Half damage to hull
    end

    -- Apply shield damage
    if shieldDamage > 0 and shield then
        shield.shield = math.max(0, shieldBefore - shieldDamage)
    end

    -- Apply hull damage
    local hullDamageApplied = false
    if hullDamage > 0 then
        hull.hp = math.max(0, (hull.hp or 0) - hullDamage)
        hullDamageApplied = true
        if hull.hp <= 0 then
            target.dead = true
            target._killedBy = source
            if damageMeta then
                damageMeta.value = baseDamage
                if skillId and damageMeta.skill == nil then
                    damageMeta.skill = skillId
                end
                target._finalDamage = damageMeta
            else
                target._finalDamage = { value = baseDamage, skill = skillId }
            end
        end
    end

    if shieldDamage > 0 or hullDamageApplied then
        if love and love.timer and love.timer.getTime then
            target._hudDamageTime = love.timer.getTime()
        else
            target._hudDamageTime = os.clock()
        end
        
        -- Emit damage event for players
        if target.isPlayer or target.isRemotePlayer then
            local Events = require("src.core.events")
            local eventData = {
                entity = target,
                damage = baseDamage,
                shieldDamage = shieldDamage,
                hullDamage = hullDamage,
                hadShield = (shieldBefore > 0),
                source = source
            }
            Events.emit(Events.GAME_EVENTS.PLAYER_DAMAGED, eventData)
        end
    end
end

-- Handle continuous beam rendering
function BeamWeapons.renderContinuousBeam(turret, startX, startY, targetX, targetY, dt)
    if not turret.beamActive then
        turret.beamActive = true
        turret.beamStartTime = love.timer and love.timer.getTime()
    end

    -- Calculate beam intensity based on duration
    local beamDuration = (love.timer and love.timer.getTime()) - turret.beamStartTime
    local intensity = math.min(1.0, beamDuration / 0.5) -- Fade in over 0.5 seconds

    -- Render beam with variable intensity
    if turret.tracer then
        local color = turret.tracer.color
        local alpha = color[4] * intensity

        love.graphics.setColor(color[1], color[2], color[3], alpha)
        love.graphics.setLineWidth(turret.tracer.width)
        love.graphics.line(startX, startY, targetX, targetY)

        -- Beam core
        if turret.tracer.coreRadius and turret.tracer.coreRadius > 0 then
            love.graphics.setColor(color[1] * 1.2, color[2] * 1.2, color[3] * 1.2, alpha * 0.8)
            love.graphics.setLineWidth(turret.tracer.coreRadius)
            love.graphics.line(startX, startY, targetX, targetY)
        end
    end

    -- Reset graphics state
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

-- Stop beam rendering
function BeamWeapons.stopBeam(turret)
    turret.beamActive = false
    turret.beamStartTime = nil
end

-- Check if beam weapon can fire
function BeamWeapons.canFire(turret, target)
    return turret:canFire()
end

return BeamWeapons
