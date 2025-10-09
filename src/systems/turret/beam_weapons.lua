local CollisionHelpers = require("src.systems.turret.collision_helpers")
local TurretEffects = require("src.systems.turret.effects")
local Log = require("src.core.log")
local TargetUtils = require("src.core.target_utils")

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

    local hitTarget, hitX, hitY = BeamWeapons.performLaserHitscan(
        sx, sy, endX, endY, turret, world
    )

    local wasActive = turret.beamActive

    local beamEndX = hitX or endX
    local beamEndY = hitY or endY

    local energyStarved = false
    if turret.energyPerSecond and turret.energyPerSecond > 0 and turret.owner and turret.owner.components and turret.owner.components.health and turret.owner.isPlayer then
        local currentEnergy = turret.owner.components.health.energy or 0
        local energyCost = turret.energyPerSecond * dt
        local resumeMultiplier = turret.resumeEnergyMultiplier or 2
        local resumeThreshold = turret.minResumeEnergy or (resumeMultiplier * energyCost)
        resumeThreshold = math.max(resumeThreshold, energyCost)

        if turret._energyStarved then
            if currentEnergy >= resumeThreshold then
                turret._energyStarved = false
            else
                energyStarved = true
            end
        end

        if not energyStarved then
            if currentEnergy >= energyCost then
                turret.owner.components.health.energy = math.max(0, currentEnergy - energyCost)
            else
                turret._energyStarved = true
                energyStarved = true
            end
        end
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
        return nil 
    end

    local bestTarget = nil
    local bestDistance = math.huge
    local bestHitX, bestHitY = endX, endY

    -- Get ALL collidable entities from world (beam stops at first object hit)
    local entities = world:get_entities_with_components("collidable", "position")

    for _, entity in ipairs(entities) do
        if entity ~= turret.owner and not entity.dead then

            local targetRadius = CollisionHelpers.calculateEffectiveRadius(entity)
            local hit, hx, hy = CollisionHelpers.performCollisionCheck(
                startX, startY, endX, endY, entity, targetRadius
            )

            if hit then
                local distance = math.sqrt((hx - startX)^2 + (hy - startY)^2)
                if distance < bestDistance then
                    bestDistance = distance
                    bestTarget = entity
                    bestHitX, bestHitY = hx, hy
                    
                    -- Create collision effects for beam hits
                    local CollisionEffects = require("src.systems.collision.effects")
                    local now = (love and love.timer and love.timer.getTime and love.timer.getTime()) or 0
                    if CollisionEffects.canEmitCollisionFX(turret, entity, now) then
                        local beamRadius = 1 -- Beams are line segments
                        local targetRadius = targetRadius
                        
                        -- Use the precise hit position for collision effects
                        CollisionEffects.createCollisionEffects(turret, entity, hx, hy, hx, hy, 0, 0, beamRadius, targetRadius, nil, nil)
                    end
                end
            end
        end
    end

    return bestTarget, bestHitX, bestHitY
end


-- Apply damage from laser weapons
function BeamWeapons.applyLaserDamage(target, damage, source, skillId, damageMeta)
    if not target.components or not target.components.health then
        return
    end

    -- Validate damage value
    if not damage or damage <= 0 then
        return -- No damage to apply
    end

    local health = target.components.health

    -- Apply global enemy damage multiplier (x2)
    local baseDamage = damage
    if source and (source.isEnemy or (source.components and source.components.ai)) then
        baseDamage = damage * 2
    end

    -- Laser weapons: 15% more damage to shields, half damage to hulls
    -- Use the same calculation logic as CollisionEffects.applyDamage for consistency
    local shieldBefore = health.shield or 0
    local shieldDamage = math.min(shieldBefore, baseDamage * 1.15) -- 15% more damage to shields
    local remainingDamage = baseDamage - (shieldDamage / 1.15) -- Convert back to original damage for hull calculation
    local hullDamage = 0
    
    if remainingDamage > 0 then
        hullDamage = remainingDamage * 0.5 -- Half damage to hull
    end

    -- Apply shield damage
    if shieldDamage > 0 then
        health.shield = math.max(0, shieldBefore - shieldDamage)
    end

    -- Apply hull damage
    local hullDamageApplied = false
    if hullDamage > 0 then
        health.hp = math.max(0, (health.hp or 0) - hullDamage)
        hullDamageApplied = true
        if health.hp <= 0 then
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
