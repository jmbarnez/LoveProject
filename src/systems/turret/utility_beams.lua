local CollisionHelpers = require("src.systems.turret.collision_helpers")
local HeatManager = require("src.systems.turret.heat_manager")
local Targeting = require("src.systems.turret.targeting")
local TurretEffects = require("src.systems.turret.effects")
local Content = require("src.content.content")

local UtilityBeams = {}

-- Handle mining laser operation (pulsed weapon like combat laser)
function UtilityBeams.updateMiningLaser(turret, dt, target, locked, world)
    if locked or not turret:canFire() then
        return
    end

    -- Manual shooting - fire in the direction the player is facing
    local angle = turret.owner.components.position.angle or 0
    local sx = turret.owner.components.position.x
    local sy = turret.owner.components.position.y

    -- Perform hitscan collision check for ALL collidable objects (like combat laser)
    local maxRange = turret.maxRange or 850
    local endX = sx + math.cos(angle) * maxRange
    local endY = sy + math.sin(angle) * maxRange

    local hitTarget, hitX, hitY = UtilityBeams.performMiningHitscan(
        sx, sy, endX, endY, turret, world
    )

    if hitTarget then
        -- Only apply mining damage if target is an asteroid
        if hitTarget.components and hitTarget.components.mineable then
            -- Apply mining damage
            local damageValue = turret.miningPower or math.random(1, 2)
            UtilityBeams.applyMiningDamage(hitTarget, damageValue, turret.owner, world)
            TurretEffects.createImpactEffect(turret, hitX, hitY, hitTarget, "mining")
        else
            -- Hit a non-mineable object - no damage, but still create impact effect
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
    HeatManager.addHeat(turret, turret.heatPerShot or 5.0)
    TurretEffects.playFiringSound(turret)
end

-- Apply mining damage to asteroid durability
function UtilityBeams.applyMiningDamage(target, damage, source, world)
    if not target.components or not target.components.mineable then
        return
    end

    local mineable = target.components.mineable
    local oldDurability = mineable.durability or 5.0

    -- Initialize maxDurability if not set
    if not mineable.maxDurability then
        mineable.maxDurability = oldDurability
    end

    -- Apply damage to durability
    mineable.durability = math.max(0, mineable.durability - damage)

    -- Update progress for cracking visual effects
    mineable._durabilityProgress = mineable.maxDurability - mineable.durability

    -- Check if asteroid is completely mined
    if mineable.durability <= 0 then
        UtilityBeams.completeMining(nil, target, world)
        target.dead = true
    end
end

-- Complete mining operation and yield resources
function UtilityBeams.completeMining(turret, target, world)
    if not target.components or not target.components.mineable then
        return
    end

    local mineable = target.components.mineable
    local resourceType = mineable.resourceType or "stones"
    local resourceAmount = math.max(1, mineable.amount or mineable.resources or 1)

    -- Create resource pickup
    local ItemPickup = require("src.entities.item_pickup")
    for i = 1, math.max(1, resourceAmount) do
        local angle = math.random() * math.pi * 2
        local dist = 6 + math.random() * 18
        local spawnX = target.components.position.x + math.cos(angle) * dist
        local spawnY = target.components.position.y + math.sin(angle) * dist

        local speed = 120 + math.random() * 180
        local spreadAngle = angle + (math.random() - 0.5) * 0.6
        local vx = math.cos(spreadAngle) * speed
        local vy = math.sin(spreadAngle) * speed

        local pickup = ItemPickup.new(
            spawnX,
            spawnY,
            resourceType,
            1,
            0.85 + math.random() * 0.35,
            vx,
            vy
        )

        if pickup and world then
            world:addEntity(pickup)
        end
    end

    local Effects = require("src.systems.effects")
    local Sound = require("src.core.sound")
    local x = target.components.position.x
    local y = target.components.position.y
    local radius = (target.components.collidable and target.components.collidable.radius) or 30

    if Effects and Effects.spawnExtractionFlash then
        Effects.spawnExtractionFlash(x, y, radius * 0.6)
    end

    if Effects and Effects.spawnExtractionParticles then
        Effects.spawnExtractionParticles(x, y, radius * 0.8)
    end

    if Effects and Effects.spawnDetonation then
        Effects.spawnDetonation(x, y, "asteroid", {0.9, 0.75, 0.4, 0.4})
    end

    -- Mining completion effects
    TurretEffects.createMiningParticles(
        target.components.position.x,
        target.components.position.y
    )
end

-- Handle salvaging laser operation (pulsed weapon like mining laser)
function UtilityBeams.updateSalvagingLaser(turret, dt, target, locked, world)
    if locked or not turret:canFire() then
        return
    end

    -- Manual shooting - fire in the direction the player is facing
    local angle = turret.owner.components.position.angle or 0
    local sx = turret.owner.components.position.x
    local sy = turret.owner.components.position.y

    -- Perform hitscan collision check for ALL collidable objects (like combat laser)
    local maxRange = turret.maxRange or 800
    local endX = sx + math.cos(angle) * maxRange
    local endY = sy + math.sin(angle) * maxRange

    local hitTarget, hitX, hitY = UtilityBeams.performSalvageHitscan(
        sx, sy, endX, endY, turret, world
    )

    if hitTarget then
        -- Only apply salvage damage if target is wreckage
        if hitTarget.components and hitTarget.components.wreckage then
            -- Apply salvage damage
            local damageValue = turret.salvagePower or math.random(1, 2)
            UtilityBeams.applySalvageDamage(hitTarget, damageValue, turret.owner, world)
            TurretEffects.createImpactEffect(turret, hitX, hitY, hitTarget, "salvage")
        else
            -- Hit a non-wreckage object - no damage, but still create impact effect
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
    HeatManager.addHeat(turret, turret.heatPerShot or 5.0)
    TurretEffects.playFiringSound(turret)
end

-- Complete salvage operation (cleanup after all materials yielded)
function UtilityBeams.completeSalvage(turret, target, world)
    -- Salvage completion effects
    TurretEffects.createSalvageParticles(
        target.components.position.x,
        target.components.position.y
    )
end


-- Perform hitscan collision detection for mining lasers
function UtilityBeams.performMiningHitscan(startX, startY, endX, endY, turret, world)
    if not world then return nil end

    local CollisionHelpers = require("src.systems.turret.collision_helpers")
    local bestTarget = nil
    local bestDistance = math.huge
    local bestHitX, bestHitY = endX, endY

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

-- Perform hitscan collision detection for salvaging lasers
function UtilityBeams.performSalvageHitscan(startX, startY, endX, endY, turret, world)
    if not world then return nil end

    local CollisionHelpers = require("src.systems.turret.collision_helpers")
    local bestTarget = nil
    local bestDistance = math.huge
    local bestHitX, bestHitY = endX, endY

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

-- Apply salvage damage to wreckage
function UtilityBeams.applySalvageDamage(target, damage, source, world)
    if not target.components or not target.components.wreckage then
        return
    end

    local wreckage = target.components.wreckage
    local amountThisPulse = math.min(damage, wreckage.salvageAmount or 1)
    wreckage.salvageAmount = math.max(0, (wreckage.salvageAmount or 1) - damage)

    -- Create scrap pickup for this pulse
    if amountThisPulse > 0 then
        local ItemPickup = require("src.entities.item_pickup")
        local pickup = ItemPickup.new(
            target.components.position.x,
            target.components.position.y,
            "scraps",
            amountThisPulse
        )
        if pickup and world then
            world:addEntity(pickup)
        end
    end

    -- Check if wreckage is completely salvaged
    if wreckage.salvageAmount <= 0 then
        UtilityBeams.completeSalvage(nil, target, world)
        target.dead = true
    end
end


return UtilityBeams