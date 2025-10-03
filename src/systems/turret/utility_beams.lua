local CollisionHelpers = require("src.systems.turret.collision_helpers")
local TurretEffects = require("src.systems.turret.effects")
local CollisionEffects = require("src.systems.collision.effects")
local Effects = require("src.systems.effects")
local Skills = require("src.core.skills")
local Notifications = require("src.ui.notifications")
local Events = require("src.core.events")

local UtilityBeams = {}

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


-- Handle mining laser operation (continuous beam with continuous damage)
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

    -- Continuous visual effects - no timer needed

    -- Get turret world position first for accurate aiming
    local Turret = require("src.systems.turret.core")
    local sx, sy = Turret.getTurretWorldPosition(turret)

    -- Manual shooting - fire in the direction of the cursor from turret position
    local angle = 0
    local cursorDistance = math.huge
    if turret.owner.cursorWorldPos then
        local cursorX, cursorY = turret.owner.cursorWorldPos.x, turret.owner.cursorWorldPos.y
        local dx = cursorX - sx
        local dy = cursorY - sy
        angle = math.atan2(dy, dx)
        cursorDistance = math.sqrt(dx * dx + dy * dy)
    else
        -- Fallback to ship facing if cursor position not available
        angle = turret.owner.components.position.angle
    end

    turret.currentAimAngle = angle

    -- Calculate beam length - limit to cursor distance (up to max range)
    local maxRange = turret.maxRange
    local beamLength = maxRange
    if turret.owner.cursorWorldPos then
        beamLength = math.min(cursorDistance, maxRange)
    end
    
    local endX = sx + math.cos(angle) * beamLength
    local endY = sy + math.sin(angle) * beamLength

    local hitTarget, hitX, hitY = UtilityBeams.performMiningHitscan(
        sx, sy, endX, endY, turret, world
    )

    local wasActive = turret.beamActive
    -- Use collision point if hit, otherwise use max range end point
    local beamEndX = hitX
    local beamEndY = hitY

    turret.beamActive = true
    turret.beamStartX = sx
    turret.beamStartY = sy
    turret.beamEndX = beamEndX
    turret.beamEndY = beamEndY
    turret.beamTarget = hitTarget

    -- Consume energy per second while beam is active
    if turret.energyPerSecond and turret.owner and turret.owner.components and turret.owner.components.health then
        local currentEnergy = turret.owner.components.health.energy or 0
        local energyCost = turret.energyPerSecond * dt
        if currentEnergy >= energyCost then
            turret.owner.components.health.energy = math.max(0, currentEnergy - energyCost)
        else
            -- Not enough energy, stop the beam
            turret.beamActive = false
            return
        end
    else
        -- Debug logging for missing energyPerSecond
        if turret.owner.isPlayer then
            Log.debug("Mining laser energyPerSecond: " .. tostring(turret.energyPerSecond))
        end
    end

    local cycle = math.max(0.1, turret.cycle)
    local miningPower = turret.miningPower
    local damageRate = miningPower / cycle

    if hitTarget then
        if hitTarget.components and hitTarget.components.mineable then
            -- Set mining flag to enable hotspot generation
            hitTarget.components.mineable.isBeingMined = true
            
            local damageValue = damageRate * dt
            UtilityBeams.applyMiningDamage(hitTarget, damageValue, turret.owner, world, hitX, hitY)

            -- Continuous visual effects while beam is active
            TurretEffects.createImpactEffect(turret, hitX, hitY, hitTarget, "mining")
        else
            -- Continuous visual effects for non-mining targets
            TurretEffects.createImpactEffect(turret, hitX, hitY, hitTarget, "laser")
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
    local oldDurability = mineable.durability

    -- Initialize maxDurability if not set
    if not mineable.maxDurability then
        mineable.maxDurability = oldDurability
    end

    -- Check for hotspot burst damage (only if hotspots exist)
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
    -- Create resource pickups based on asteroid type
    local ItemPickup = require("src.entities.item_pickup")
    
    -- Drop ore based on asteroid type
    local mineable = target.components.mineable
    local resourceType = mineable and mineable.resourceType or "ore_tritanium"
    local oreCount = 2 + math.random(1)
    for i = 1, oreCount do
        local angle = math.random() * math.pi * 2
        local dist = 8 + math.random() * 16
        local spawnX = target.components.position.x + math.cos(angle) * dist
        local spawnY = target.components.position.y + math.sin(angle) * dist

        local speed = 100 + math.random() * 140
        local spreadAngle = angle + (math.random() - 0.5) * 0.5
        local vx = math.cos(spreadAngle) * speed
        local vy = math.sin(spreadAngle) * speed

        local pickup = ItemPickup.new(
            spawnX,
            spawnY,
            resourceType,  -- Drop the ore type this asteroid contains
            1,
            0.8 + math.random() * 0.4,
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
    local radius = (target.components.collidable and target.components.collidable.radius)

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

    -- Award mining XP for completing the asteroid
    local Skills = require("src.core.skills")
    local Notifications = require("src.ui.notifications")
    local Events = require("src.core.events")
    
    -- Find the player to award XP to
    local player = nil
    if world and world.entities then
        for _, entity in ipairs(world.entities) do
            if entity.components and entity.components.player then
                player = entity
                break
            end
        end
    end
    
    if player then
        local xpBase = 12
        local miningLevel = Skills.getLevel("mining")
        local xpGain = xpBase * (1 + miningLevel * 0.06)
        local leveledUp = Skills.addXp("mining", xpGain)
        player:addXP(xpGain)

        if leveledUp then
            Notifications.action("Mining level up!")
        end

        Events.emit(Events.GAME_EVENTS.ASTEROID_MINED, {
            item = { id = "ore_tritanium", name = "Tritanium Ore" },
            amount = 1,
            player = player,
            asteroid = target
        })
    end
end

-- Handle salvaging laser operation (continuous beam with continuous damage)
function UtilityBeams.updateSalvagingLaser(turret, dt, target, locked, world)
    if locked or not turret:canFire() then
        turret.beamActive = false
        turret.beamTarget = nil
        return
    end

    -- Continuous visual effects - no timer needed

    -- Get turret world position first for accurate aiming
    local Turret = require("src.systems.turret.core")
    local sx, sy = Turret.getTurretWorldPosition(turret)

    -- Manual shooting - fire in the direction of the cursor from turret position
    local angle = 0
    local cursorDistance = math.huge
    if turret.owner.cursorWorldPos then
        local cursorX, cursorY = turret.owner.cursorWorldPos.x, turret.owner.cursorWorldPos.y
        local dx = cursorX - sx
        local dy = cursorY - sy
        angle = math.atan2(dy, dx)
        cursorDistance = math.sqrt(dx * dx + dy * dy)
    else
        -- Fallback to ship facing if cursor position not available
        angle = turret.owner.components.position.angle
    end

    turret.currentAimAngle = angle

    -- Calculate beam length - limit to cursor distance (up to max range)
    local maxRange = turret.maxRange
    local beamLength = maxRange
    if turret.owner.cursorWorldPos then
        beamLength = math.min(cursorDistance, maxRange)
    end
    
    local endX = sx + math.cos(angle) * beamLength
    local endY = sy + math.sin(angle) * beamLength

    local hitTarget, hitX, hitY = UtilityBeams.performMiningHitscan(
        sx, sy, endX, endY, turret, world
    )

    local wasActive = turret.beamActive
    -- Use collision point if hit, otherwise use max range end point
    local beamEndX = hitX
    local beamEndY = hitY

    turret.beamActive = true
    turret.beamStartX = sx
    turret.beamStartY = sy
    turret.beamEndX = beamEndX
    turret.beamEndY = beamEndY
    turret.beamTarget = hitTarget

    -- Consume energy per second while beam is active
    if turret.energyPerSecond and turret.owner and turret.owner.components and turret.owner.components.health then
        local currentEnergy = turret.owner.components.health.energy or 0
        local energyCost = turret.energyPerSecond * dt
        if currentEnergy >= energyCost then
            turret.owner.components.health.energy = math.max(0, currentEnergy - energyCost)
        else
            -- Not enough energy, stop the beam
            turret.beamActive = false
            return
        end
    else
        -- Debug logging for missing energyPerSecond
        if turret.owner.isPlayer then
            Log.debug("Salvaging laser energyPerSecond: " .. tostring(turret.energyPerSecond))
        end
    end

    local cycle = math.max(0.1, turret.cycle)
    local salvagePower = turret.salvagePower
    local salvageRate = salvagePower / cycle

    if hitTarget then
        if hitTarget.components and hitTarget.components.wreckage then
            -- Mark wreckage as being salvaged
            if not hitTarget.components.wreckage.isBeingSalvaged then
                hitTarget.components.wreckage.isBeingSalvaged = true
            end
            
            local removed = UtilityBeams.applySalvageDamage(hitTarget, salvageRate * dt, turret.owner, world)
            -- Continuous visual effects while beam is active
            TurretEffects.createImpactEffect(turret, hitX, hitY, hitTarget, "salvage")
        else
            -- Continuous visual effects for non-salvage targets
            TurretEffects.createImpactEffect(turret, hitX, hitY, hitTarget, "laser")
        end
    else
        -- No target hit, clear salvage flags on all wreckage
        local entities = world:get_entities_with_components("wreckage")
        for _, entity in ipairs(entities) do
            if entity.components and entity.components.wreckage then
                entity.components.wreckage.isBeingSalvaged = false
            end
        end
    end

    turret.cooldownOverride = 0

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


-- Apply salvage damage to wreckage
function UtilityBeams.applySalvageDamage(target, damage, source, world)
    if not target.components or not target.components.wreckage then
        return false
    end

    if damage <= 0 then
        return false
    end

    local wreckage = target.components.wreckage
    local remaining = wreckage.salvageAmount
    if remaining <= 0 then
        return false
    end

    local applied = math.min(damage, remaining)
    remaining = remaining - applied
    wreckage.salvageAmount = remaining

    -- Initialize partial salvage tracking fields if they don't exist (for legacy wreckage)
    if wreckage._partialSalvage == nil then
        wreckage._partialSalvage = 0
    end
    if wreckage._salvageDropped == nil then
        wreckage._salvageDropped = 0
    end

    wreckage._partialSalvage = wreckage._partialSalvage + applied
    wreckage._salvageDropped = wreckage._salvageDropped
    local whole = math.floor(wreckage._partialSalvage)
    if whole >= 1 then
        wreckage._partialSalvage = wreckage._partialSalvage - whole
        wreckage._salvageDropped = wreckage._salvageDropped + whole
        spawnSalvagePickup(target, whole, world)
        
        -- Give XP and skill progression for salvaged resources
        if source then
            local xpBase = 10 -- base XP per salvaged resource
            local salvagingLevel = Skills.getLevel("salvaging")
            local xpGain = xpBase * (1 + salvagingLevel * 0.06) -- mild scaling per level
            local leveledUp = Skills.addXp("salvaging", xpGain)

            if leveledUp then
                Notifications.action("Salvaging level up!")
            end

            -- Emit salvage event
            Events.emit(Events.GAME_EVENTS.WRECKAGE_SALVAGED, {
                player = source,
                amount = whole,
                resourceId = wreckage.resourceType or "scraps",
                wreckage = target,
                wreckageId = target.id
            })
        end
    end

    if remaining <= 0 then
        local initialTotal = wreckage.maxSalvageAmount
        local remainingToDrop = math.max(0, math.floor(initialTotal - wreckage._salvageDropped + 0.0001))
        if remainingToDrop > 0 then
            wreckage._salvageDropped = wreckage._salvageDropped + remainingToDrop
            spawnSalvagePickup(target, remainingToDrop, world)
            
            -- Give XP for remaining resources
            if source then
                local xpBase = 10
                local salvagingLevel = Skills.getLevel("salvaging")
                local xpGain = xpBase * (1 + salvagingLevel * 0.06) * remainingToDrop
                local leveledUp = Skills.addXp("salvaging", xpGain)

                if leveledUp then
                    Notifications.action("Salvaging level up!")
                end

                -- Emit salvage event for remaining resources
                Events.emit(Events.GAME_EVENTS.WRECKAGE_SALVAGED, {
                    player = source,
                    amount = remainingToDrop,
                    resourceId = wreckage.resourceType or "scraps",
                    wreckage = target,
                    wreckageId = target.id
                })
            end
        end
        wreckage._partialSalvage = 0
        UtilityBeams.completeSalvage(nil, target, world)
        target.dead = true
    end

    return applied > 0
end


return UtilityBeams
