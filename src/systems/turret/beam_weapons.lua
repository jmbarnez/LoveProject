local CollisionHelpers = require("src.systems.turret.collision_helpers")
local TurretEffects = require("src.systems.turret.effects")
local Log = require("src.core.log")
local TargetUtils = require("src.core.target_utils")

local BeamWeapons = {}

-- Helper function to send beam weapon fire request to host
local function sendBeamWeaponFireRequest(turret, sx, sy, angle, beamLength, damageConfig)
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
            ownerId = turret.owner and turret.owner.id or nil
        }
        
        -- Send via network manager
        if networkManager.sendWeaponFireRequest then
            local json = require("src.libs.json")
            Log.info("Client -> sendBeamWeaponFireRequest", json.encode(request))
            networkManager:sendWeaponFireRequest(request)
        end
        return true
    end
    
    return false
end

-- Handle laser turret firing (hitscan beam weapons)
function BeamWeapons.updateLaserTurret(turret, dt, target, locked, world)
    Log.info("updateLaserTurret: Called for turret", turret.id or "unknown", "locked:", locked, "canFire:", turret:canFire())
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

    local sx, sy = Turret.getTurretWorldPosition(turret)

    local angle
    local desiredDistance
    local cursorPos = turret.owner.cursorWorldPos

    if cursorPos then
        local cursorX, cursorY = cursorPos.x, cursorPos.y
        local dx = cursorX - sx
        local dy = cursorY - sy
        angle = math.atan2(dy, dx)
        desiredDistance = math.sqrt(dx * dx + dy * dy)
    elseif target and target.components and target.components.position then
        local tx = target.components.position.x
        local ty = target.components.position.y
        angle = math.atan2(ty - sy, tx - sx)
        desiredDistance = math.sqrt((tx - sx) ^ 2 + (ty - sy) ^ 2)
    elseif shipPos then
        angle = shipPos.angle
        desiredDistance = turret.maxRange or 0
    else
        angle = 0
        desiredDistance = turret.maxRange or 0
    end

    turret.currentAimAngle = angle

    local maxRange = turret.maxRange or 0
    local beamLength = math.min(desiredDistance or maxRange, maxRange)

    local endX = sx + math.cos(angle) * beamLength
    local endY = sy + math.sin(angle) * beamLength

    local hitTarget, hitX, hitY = BeamWeapons.performLaserHitscan(
        sx, sy, endX, endY, turret, world
    )
    Log.info("updateLaserTurret: Hitscan result - hitTarget:", hitTarget and (hitTarget.id or "unknown") or "nil", "hitX:", hitX, "hitY:", hitY)

    local wasActive = turret.beamActive

    local beamEndX = hitX or endX
    local beamEndY = hitY or endY
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
            skill = turret.skillId
        }
    else
        damageConfig = { min = 1, max = 2, skill = turret.skillId }
    end
    
    local requestSent = sendBeamWeaponFireRequest(turret, sx, sy, angle, beamLength, damageConfig)
    
    -- If not a client or request failed, process beam locally (for host)
    if not requestSent then
        -- Host processes beam locally
    end

    if turret.energyPerSecond and turret.energyPerSecond > 0 and turret.owner and turret.owner.components and turret.owner.components.health and turret.owner.isPlayer then
        local currentEnergy = turret.owner.components.health.energy or 0
        local energyCost = turret.energyPerSecond * dt
        if currentEnergy >= energyCost then
            turret.owner.components.health.energy = math.max(0, currentEnergy - energyCost)
        else
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
                    Log.info("Laser hitting target:", hitTarget.id or "unknown", "damage:", damageAmount, "dt:", dt)
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
                    Log.debug("Laser damage amount is 0 or negative:", damageAmount)
                end
            else
                Log.debug("Laser damagePerSecond is 0 or nil:", damagePerSecond)
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
        Log.debug("performLaserHitscan: No world provided")
        return nil 
    end

    local bestTarget = nil
    local bestDistance = math.huge
    local bestHitX, bestHitY = endX, endY

    -- Get ALL collidable entities from world (beam stops at first object hit)
    local entities = world:get_entities_with_components("collidable", "position")
    Log.info("performLaserHitscan: Checking", #entities, "entities for collision")

    for _, entity in ipairs(entities) do
        if entity ~= turret.owner and not entity.dead then

            local targetRadius = CollisionHelpers.calculateEffectiveRadius(entity)
            local hit, hx, hy = CollisionHelpers.performCollisionCheck(
                startX, startY, endX, endY, entity, targetRadius
            )

            if hit then
                local distance = math.sqrt((hx - startX)^2 + (hy - startY)^2)
                Log.info("performLaserHitscan: Hit entity", entity.id or "unknown", "at distance", distance)
                if distance < bestDistance then
                    bestDistance = distance
                    bestTarget = entity
                    bestHitX, bestHitY = hx, hy
                    Log.info("performLaserHitscan: New best target", entity.id or "unknown")
                end
            end
        end
    end

    return bestTarget, bestHitX, bestHitY
end


-- Apply damage from laser weapons
function BeamWeapons.applyLaserDamage(target, damage, source, skillId, damageMeta)
    if not target.components or not target.components.health then
        Log.debug("applyLaserDamage: Target has no health component")
        return
    end

    local health = target.components.health
    Log.info("applyLaserDamage: Applying", damage, "damage to target", target.id or "unknown", "shield:", health.shield, "hp:", health.hp)

    -- Apply global enemy damage multiplier (x2)
    local baseDamage = damage
    if source and (source.isEnemy or (source.components and source.components.ai)) then
        baseDamage = damage * 2
        Log.debug("applyLaserDamage: Enemy source, damage multiplied to", baseDamage)
    end

    -- Laser weapons: 15% more damage to shields, half damage to hulls
    local shieldDamage = math.min(health.shield, baseDamage * 1.15) -- 15% more damage to shields
    health.shield = health.shield - shieldDamage
    Log.info("applyLaserDamage: Shield damage:", shieldDamage, "new shield:", health.shield)

    local hullDamageApplied = false
    local remainingDamage = baseDamage - (shieldDamage / 1.15) -- Convert back to original damage for hull calculation
    Log.info("applyLaserDamage: Remaining damage after shield:", remainingDamage)
    if remainingDamage > 0 then
        local hullDamage = remainingDamage * 0.5 -- Half damage to hull
        Log.info("applyLaserDamage: Hull damage:", hullDamage, "new hp:", health.hp - hullDamage)
        if hullDamage > 0 then
            health.hp = health.hp - hullDamage
            hullDamageApplied = true
        end
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
