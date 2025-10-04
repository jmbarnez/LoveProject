local CollisionHelpers = require("src.systems.turret.collision_helpers")
local TurretEffects = require("src.systems.turret.effects")
local Log = require("src.core.log")

local BeamWeapons = {}

-- Handle laser turret firing (hitscan beam weapons)
function BeamWeapons.updateLaserTurret(turret, dt, target, locked, world)
    Log.debug("BeamWeapons.updateLaserTurret called for turret: " .. tostring(turret.id) .. ", cooldown: " .. tostring(turret.cooldown))
    if locked or not turret:canFire() then
        return
    end

    -- Reset beam state to allow new collisions each shot
    turret.has_hit = false
    turret.beamActive = false
    turret.beamStartX = nil
    turret.beamStartY = nil
    turret.beamEndX = nil
    turret.beamEndY = nil
    turret.beamTarget = nil

    -- Get turret world position instead of ship center
    local Turret = require("src.systems.turret.core")
    local shipPos = turret.owner.components and turret.owner.components.position

    -- Get turret world position first for accurate aiming
    local sx, sy = Turret.getTurretWorldPosition(turret)

    -- Aim in the direction of the target if provided, otherwise use cursor direction
    local angle
    local targetDistance = math.huge
    if target then
        -- For automatic firing (AI), aim from turret position to target
        local tx = target.components.position.x
        local ty = target.components.position.y
        angle = math.atan2(ty - sy, tx - sx)
        targetDistance = math.sqrt((tx - sx)^2 + (ty - sy)^2)
    elseif turret.owner.cursorWorldPos then
        -- For manual firing, use the cursor direction from turret position
        local cursorX, cursorY = turret.owner.cursorWorldPos.x, turret.owner.cursorWorldPos.y
        local dx = cursorX - sx
        local dy = cursorY - sy
        angle = math.atan2(dy, dx)
        targetDistance = math.sqrt(dx * dx + dy * dy)
    else
        -- Fallback to ship facing if cursor position not available
        angle = shipPos.angle
    end

    turret.currentAimAngle = angle

    -- Perform hitscan collision check
    local maxRange = turret.maxRange
    -- For manual firing, limit beam length to cursor distance (up to max range)
    local beamLength = maxRange
    if turret.owner.cursorWorldPos and not target then
        beamLength = math.min(targetDistance, maxRange)
    end
    
    local endX = sx + math.cos(angle) * beamLength
    local endY = sy + math.sin(angle) * beamLength

    local hitTarget, hitX, hitY = BeamWeapons.performLaserHitscan(
        sx, sy, endX, endY, turret, world
    )

    if hitTarget then
        Log.debug("BeamWeapons.performLaserHitscan found target: " .. tostring(hitTarget.id) .. " for turret: " .. tostring(turret.id))
        -- Only apply damage if target is an enemy
        if BeamWeapons.isEnemyTarget(hitTarget, turret.owner) then
            -- Apply damage
            local damage = turret.damage_range and {
                min = turret.damage_range.min,
                max = turret.damage_range.max,
                skill = turret.skillId
            }

            local dmgValue = math.random(damage.min, damage.max)
            damage.value = dmgValue
            Log.debug("Applying damage from turret: " .. tostring(turret.id) .. " to target: " .. tostring(hitTarget.id) .. " with value: " .. tostring(dmgValue))
            BeamWeapons.applyLaserDamage(hitTarget, dmgValue, turret.owner, turret.skillId, damage)

            -- Create combat impact effects
            TurretEffects.createImpactEffect(turret, hitX, hitY, hitTarget, "laser")
        else
            -- Hit a non-enemy object - no damage, but still create impact effect
            TurretEffects.createImpactEffect(turret, hitX, hitY, hitTarget, "laser")
        end
    else
        Log.debug("BeamWeapons.performLaserHitscan found no target for turret: " .. tostring(turret.id))
    end

    -- Store beam data for rendering during draw phase
    -- Use collision point if hit, otherwise use calculated end point
    local beamEndX = hitX
    local beamEndY = hitY
    turret.beamActive = true
    turret.beamStartX = sx
    turret.beamStartY = sy
    turret.beamEndX = beamEndX
    turret.beamEndY = beamEndY
    turret.beamTarget = hitTarget

    -- Add heat and play effects
    TurretEffects.playFiringSound(turret)
    
    -- Set cooldown after firing
    turret.cooldown = turret.cycle or 1.0
end

-- Perform hitscan collision detection for laser weapons (collides with ALL objects)
function BeamWeapons.performLaserHitscan(startX, startY, endX, endY, turret, world)
    if not world then return nil end

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
                end
            end
        end
    end

    return bestTarget, bestHitX, bestHitY
end

-- Check if target is an enemy (for combat lasers)
function BeamWeapons.isEnemyTarget(target, source)
    if not target or not target.components then
        return false
    end

    -- If source is player, enemies are anything marked as enemy
    if source and (source.isPlayer or source.isFriendly) then
        return target.isEnemy or (target.components.ai ~= nil)
    end

    -- If source is enemy, targets are player and friendlies
    if source and source.isEnemy then
        return target.isPlayer or target.isFriendly
    end

    -- Default: no damage to unclear relationships
    return false
end

-- Apply damage from laser weapons
function BeamWeapons.applyLaserDamage(target, damage, source, skillId, damageMeta)
    if not target.components or not target.components.health then
        return
    end

    local health = target.components.health

    -- Apply global enemy damage multiplier (x2)
    local baseDamage = damage
    if source and (source.isEnemy or (source.components and source.components.ai)) then
        baseDamage = damage * 2
    end

    -- Laser weapons: 15% more damage to shields, half damage to hulls
    local shieldDamage = math.min(health.shield, baseDamage * 1.15) -- 15% more damage to shields
    health.shield = health.shield - shieldDamage

    local remainingDamage = baseDamage - (shieldDamage / 1.15) -- Convert back to original damage for hull calculation
    if remainingDamage > 0 then
        local hullDamage = remainingDamage * 0.5 -- Half damage to hull
        health.hp = health.hp - hullDamage
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