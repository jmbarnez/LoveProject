local CollisionHelpers = require("src.systems.turret.collision_helpers")
local HeatManager = require("src.systems.turret.heat_manager")
local TurretEffects = require("src.systems.turret.effects")
local CollisionEffects = require("src.systems.collision.effects")
local Effects = require("src.systems.effects")

local UtilityBeams = {}
local IMPACT_INTERVAL = 0.18

local function spawnSalvagePickup(target, amount, world)
    if not world or amount <= 0 then
        return
    end

    if not target.components or not target.components.position then
        return
    end

    local ItemPickup = require("src.entities.item_pickup")
    local pickup = ItemPickup.new(
        target.components.position.x,
        target.components.position.y,
        "scraps",
        amount
    )

    if pickup then
        world:addEntity(pickup)
    end
end

-- Handle mining laser operation (continuous beam with ticking damage)
function UtilityBeams.updateMiningLaser(turret, dt, target, locked, world)
    if locked or not turret:canFire() then
        turret.beamActive = false
        turret.beamTarget = nil
        -- Clear mining flags when beam is not active
        if world then
            local entities = world:get_entities_with_components("mineable")
            for _, entity in ipairs(entities) do
                if entity.components and entity.components.mineable then
                    entity.components.mineable.isBeingMined = false
                end
            end
        end
        return
    end

    turret._beamImpactTimer = math.max(0, (turret._beamImpactTimer or 0) - dt)

    -- Manual shooting - fire in the direction of the cursor
    local angle = 0
    if turret.owner.cursorWorldPos and turret.owner.components and turret.owner.components.position then
        local shipX, shipY = turret.owner.components.position.x, turret.owner.components.position.y
        local cursorX, cursorY = turret.owner.cursorWorldPos.x, turret.owner.cursorWorldPos.y
        local dx = cursorX - shipX
        local dy = cursorY - shipY
        angle = math.atan2(dy, dx)
    else
        -- Fallback to ship facing if cursor position not available
        angle = turret.owner.components.position.angle or 0
    end

    local sx = turret.owner.components.position.x
    local sy = turret.owner.components.position.y

    -- Perform hitscan collision check for ALL collidable objects (like combat laser)
    local maxRange = turret.maxRange or 850
    local endX = sx + math.cos(angle) * maxRange
    local endY = sy + math.sin(angle) * maxRange
    print("UtilityBeams: Mining beam fired from (" .. sx .. ", " .. sy .. ") to (" .. endX .. ", " .. endY .. ")")

    local hitTarget, hitX, hitY = UtilityBeams.performMiningHitscan(
        sx, sy, endX, endY, turret, world
    )

    local wasActive = turret.beamActive
    local beamEndX = hitX or endX
    local beamEndY = hitY or endY

    turret.beamActive = true
    turret.beamStartX = sx
    turret.beamStartY = sy
    turret.beamEndX = beamEndX
    turret.beamEndY = beamEndY
    turret.beamTarget = hitTarget

    local cycle = math.max(0.1, turret.cycle or 1.0)
    local miningPower = turret.miningPower or 1
    local damageRate = miningPower / cycle

    if hitTarget then
        print("UtilityBeams: Hit target found, has mineable: " .. tostring(hitTarget.components and hitTarget.components.mineable ~= nil))
        if hitTarget.components and hitTarget.components.mineable then
            -- Set mining flag to enable hotspot generation
            if not hitTarget.components.mineable.isBeingMined then
                print("Mining started on asteroid!")
            end
            hitTarget.components.mineable.isBeingMined = true
            print("UtilityBeams: Set isBeingMined to true")
            
            local damageValue = damageRate * dt
            UtilityBeams.applyMiningDamage(hitTarget, damageValue, turret.owner, world, hitX, hitY)

            if turret._beamImpactTimer <= 0 then
                TurretEffects.createImpactEffect(turret, hitX, hitY, hitTarget, "mining")
                turret._beamImpactTimer = IMPACT_INTERVAL
            end
        else
            if turret._beamImpactTimer <= 0 then
                TurretEffects.createImpactEffect(turret, hitX, hitY, hitTarget, "laser")
                turret._beamImpactTimer = IMPACT_INTERVAL
            end
        end
    else
        -- No target hit, clear mining flags on all asteroids
        local entities = world:get_entities_with_components("mineable")
        for _, entity in ipairs(entities) do
            if entity.components and entity.components.mineable then
                entity.components.mineable.isBeingMined = false
            end
        end
    end

    turret.cooldownOverride = 0

    local heatPerSecond = (turret.heatPerShot or 5.0) / cycle
    HeatManager.addHeat(turret, heatPerSecond * dt)

    if not wasActive then
        TurretEffects.playFiringSound(turret)
    end
end

-- Apply mining damage to asteroid durability
function UtilityBeams.applyMiningDamage(target, damage, source, world, impactX, impactY)
    if not target.components or not target.components.mineable then
        return
    end

    local mineable = target.components.mineable
    local oldDurability = mineable.durability or 5.0

    -- Initialize maxDurability if not set
    if not mineable.maxDurability then
        mineable.maxDurability = oldDurability
    end

    -- Check for hotspot burst damage
    local burstDamage = 0
    local hotspotConsumed = false
    if mineable.hotspots and mineable.hotspots.activateAt and impactX and impactY then
        burstDamage = mineable.hotspots:activateAt(target, world, impactX, impactY)
        hotspotConsumed = (burstDamage > 0)
    end

    -- Apply base damage plus burst damage
    local finalDamage = damage + burstDamage

    -- Create visual effect for hotspot consumption
    if hotspotConsumed then
        local effectX = impactX or (source and source.cursorWorldPos and source.cursorWorldPos.x)
        local effectY = impactY or (source and source.cursorWorldPos and source.cursorWorldPos.y)
        if effectX and effectY and TurretEffects and TurretEffects.createImpactEffect then
            TurretEffects.createImpactEffect(nil, effectX, effectY, target, "hotspot_burst")
        end
    end
    mineable.durability = math.max(0, mineable.durability - finalDamage)

    -- Update progress for cracking visual effects
    mineable._durabilityProgress = mineable.maxDurability - mineable.durability

    -- Check if asteroid is completely mined
    if mineable.durability <= 0 then
        if mineable.hotspots and mineable.hotspots.clear then
            mineable.hotspots:clear()
        else
            mineable.hotspots = {}
        end
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
    if mineable.hotspots and mineable.hotspots.clear then
        mineable.hotspots:clear()
    else
        mineable.hotspots = {}
    end
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

-- Handle salvaging laser operation (continuous beam with ticking damage)
function UtilityBeams.updateSalvagingLaser(turret, dt, target, locked, world)
    if locked or not turret:canFire() then
        turret.beamActive = false
        turret.beamTarget = nil
        return
    end

    turret._beamImpactTimer = math.max(0, (turret._beamImpactTimer or 0) - dt)

    -- Manual shooting - fire in the direction of the cursor
    local angle = 0
    if turret.owner.cursorWorldPos and turret.owner.components and turret.owner.components.position then
        local shipX, shipY = turret.owner.components.position.x, turret.owner.components.position.y
        local cursorX, cursorY = turret.owner.cursorWorldPos.x, turret.owner.cursorWorldPos.y
        local dx = cursorX - shipX
        local dy = cursorY - shipY
        angle = math.atan2(dy, dx)
    else
        -- Fallback to ship facing if cursor position not available
        angle = turret.owner.components.position.angle or 0
    end

    local sx = turret.owner.components.position.x
    local sy = turret.owner.components.position.y

    -- Perform hitscan collision check for ALL collidable objects (like combat laser)
    local maxRange = turret.maxRange or 800
    local endX = sx + math.cos(angle) * maxRange
    local endY = sy + math.sin(angle) * maxRange

    local hitTarget, hitX, hitY = UtilityBeams.performSalvageHitscan(
        sx, sy, endX, endY, turret, world
    )

    local wasActive = turret.beamActive
    local beamEndX = hitX or endX
    local beamEndY = hitY or endY

    turret.beamActive = true
    turret.beamStartX = sx
    turret.beamStartY = sy
    turret.beamEndX = beamEndX
    turret.beamEndY = beamEndY
    turret.beamTarget = hitTarget

    local cycle = math.max(0.1, turret.cycle or 1.0)
    local salvagePower = turret.salvagePower or 1
    local salvageRate = salvagePower / cycle

    if hitTarget then
        if hitTarget.components and hitTarget.components.wreckage then
            local removed = UtilityBeams.applySalvageDamage(hitTarget, salvageRate * dt, turret.owner, world)
            if removed and turret._beamImpactTimer <= 0 then
                TurretEffects.createImpactEffect(turret, hitX, hitY, hitTarget, "salvage")
                turret._beamImpactTimer = IMPACT_INTERVAL
            end
        elseif turret._beamImpactTimer <= 0 then
            TurretEffects.createImpactEffect(turret, hitX, hitY, hitTarget, "laser")
            turret._beamImpactTimer = IMPACT_INTERVAL
        end
    end

    turret.cooldownOverride = 0

    local heatPerSecond = (turret.heatPerShot or 5.0) / cycle
    HeatManager.addHeat(turret, heatPerSecond * dt)

    if not wasActive then
        TurretEffects.playFiringSound(turret)
    end
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
        return false
    end

    if damage <= 0 then
        return false
    end

    local wreckage = target.components.wreckage
    local remaining = wreckage.salvageAmount or 0
    if remaining <= 0 then
        return false
    end

    local applied = math.min(damage, remaining)
    remaining = remaining - applied
    wreckage.salvageAmount = remaining

    wreckage._partialSalvage = (wreckage._partialSalvage or 0) + applied
    wreckage._salvageDropped = wreckage._salvageDropped or 0
    local whole = math.floor(wreckage._partialSalvage)
    if whole >= 1 then
        wreckage._partialSalvage = wreckage._partialSalvage - whole
        wreckage._salvageDropped = wreckage._salvageDropped + whole
        spawnSalvagePickup(target, whole, world)
    end

    if remaining <= 0 then
        local initialTotal = wreckage.maxSalvageAmount or wreckage._salvageDropped
        local remainingToDrop = math.max(0, math.floor((initialTotal or 0) - wreckage._salvageDropped + 0.0001))
        if remainingToDrop > 0 then
            wreckage._salvageDropped = wreckage._salvageDropped + remainingToDrop
            spawnSalvagePickup(target, remainingToDrop, world)
        end
        wreckage._partialSalvage = 0
        UtilityBeams.completeSalvage(nil, target, world)
        target.dead = true
    end

    return applied > 0
end


return UtilityBeams
