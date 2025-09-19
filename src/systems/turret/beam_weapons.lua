local CollisionHelpers = require("src.systems.turret.collision_helpers")
local HeatManager = require("src.systems.turret.heat_manager")
local Targeting = require("src.systems.turret.targeting")
local TurretEffects = require("src.systems.turret.effects")

local BeamWeapons = {}

-- Handle laser turret firing (hitscan beam weapons)
function BeamWeapons.updateLaserTurret(turret, dt, target, locked, world)
    if locked or not turret:canFire() then
        return
    end

    -- Manual shooting - fire in the direction the player is facing
    local angle = turret.owner.components.position.angle or 0
    local sx = turret.owner.components.position.x
    local sy = turret.owner.components.position.y

    -- Perform hitscan collision check
    local maxRange = turret.maxRange or 1500
    local endX = sx + math.cos(angle) * maxRange
    local endY = sy + math.sin(angle) * maxRange

    local hitTarget, hitX, hitY = BeamWeapons.performLaserHitscan(
        sx, sy, endX, endY, turret, world
    )

    if hitTarget then
        -- Only apply damage if target is an enemy
        if BeamWeapons.isEnemyTarget(hitTarget, turret.owner) then
            -- Apply damage
            local damage = turret.damage_range and {
                min = turret.damage_range.min,
                max = turret.damage_range.max
            } or {min = 1, max = 2}

            local dmgValue = math.random(damage.min, damage.max)
            BeamWeapons.applyLaserDamage(hitTarget, dmgValue, turret.owner)

            -- Create combat impact effects
            TurretEffects.createImpactEffect(turret, hitX, hitY, hitTarget, "laser")
        else
            -- Hit a non-enemy object - no damage, but still create impact effect
            TurretEffects.createImpactEffect(turret, hitX, hitY, hitTarget, "laser")
        end
    end

    -- Store beam data for rendering during draw phase
    local beamEndX = hitX or endX
    local beamEndY = hitY or endY
    turret.beamActive = true
    turret.beamStartX = sx
    turret.beamStartY = sy
    turret.beamEndX = beamEndX
    turret.beamEndY = beamEndY
    turret.beamTarget = hitTarget

    -- Add heat and play effects
    HeatManager.addHeat(turret, turret.heatPerShot or 25)
    TurretEffects.playFiringSound(turret)
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
function BeamWeapons.applyLaserDamage(target, damage, source)
    if not target.components or not target.components.health then
        return
    end

    local health = target.components.health

    -- Apply damage to shields first, then hull
    local shieldDamage = math.min(health.shield or 0, damage)
    health.shield = (health.shield or 0) - shieldDamage

    local remainingDamage = damage - shieldDamage
    if remainingDamage > 0 then
        health.hp = (health.hp or 0) - remainingDamage
        if health.hp <= 0 then
            target.dead = true
            target._killedBy = source
        end
    end
end

-- Handle continuous beam rendering
function BeamWeapons.renderContinuousBeam(turret, startX, startY, targetX, targetY, dt)
    if not turret.beamActive then
        turret.beamActive = true
        turret.beamStartTime = love.timer and love.timer.getTime() or 0
    end

    -- Calculate beam intensity based on duration
    local beamDuration = (love.timer and love.timer.getTime() or 0) - turret.beamStartTime
    local intensity = math.min(1.0, beamDuration / 0.5) -- Fade in over 0.5 seconds

    -- Render beam with variable intensity
    if turret.tracer then
        local color = turret.tracer.color or {1, 1, 1, 0.8}
        local alpha = color[4] * intensity

        love.graphics.setColor(color[1], color[2], color[3], alpha)
        love.graphics.setLineWidth(turret.tracer.width or 2)
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
    return HeatManager.canFire(turret) and
           Targeting.isValidTarget(turret, target) and
           (not turret.maxRange or Targeting.canEngageTarget(turret, target,
            math.sqrt((target.components.position.x - turret.owner.components.position.x)^2 +
                     (target.components.position.y - turret.owner.components.position.y)^2)))
end

return BeamWeapons