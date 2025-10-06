local CollisionHelpers = require("src.systems.turret.collision_helpers")
local TurretEffects = require("src.systems.turret.effects")
local CollisionEffects = require("src.systems.collision.effects")
local Effects = require("src.systems.effects")
local Skills = require("src.core.skills")
local Notifications = require("src.ui.notifications")
local Events = require("src.core.events")
local Log = require("src.core.log")

local UtilityBeams = {}

-- Helper function to send utility beam weapon fire request to host
local function sendUtilityBeamWeaponFireRequest(turret, sx, sy, angle, beamLength, beamType)
    local NetworkSession = require("src.core.network.session")
    local networkManager = NetworkSession.getManager()
    
    if networkManager and networkManager:isMultiplayer() and not networkManager:isHost() then
        -- Client: send utility beam weapon fire request to host
        local request = {
            type = "utility_beam_weapon_fire_request",
            turretId = turret.id or tostring(turret),
            position = { x = sx, y = sy },
            angle = angle,
            beamLength = beamLength,
            beamType = beamType, -- "mining" or "salvaging"
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

local function isTurretInputActive(turret)
    if not turret then
        return false
    end

    if turret.fireMode == "automatic" then
        return turret.autoFire == true
    end

    if turret.firing ~= nil then
        return turret.firing == true
    end

    -- For manual turrets, if firing is nil, there's no active input
    return false
end

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
    if locked or not isTurretInputActive(turret) or not turret:canFire() then
        turret.beamActive = false
        turret.beamTarget = nil
        -- Stop mining laser sound if it was playing
        if turret.miningSoundActive or turret.miningSoundInstance then
            TurretEffects.stopMiningSound(turret)
        end
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

    -- Determine aim angle first relative to ship, then compute muzzle and precise distance from muzzle to cursor
    local Turret = require("src.systems.turret.core")
    local shipPos = turret.owner.components and turret.owner.components.position
    local cursorPos = turret.owner.cursorWorldPos
    local initialAngle

    if cursorPos and shipPos then
        initialAngle = math.atan2(cursorPos.y - shipPos.y, cursorPos.x - shipPos.x)
    elseif shipPos then
        initialAngle = shipPos.angle
    else
        initialAngle = 0
    end

    turret.currentAimAngle = initialAngle

    -- Now compute turret muzzle position using the provisional aim
    local sx, sy = Turret.getTurretWorldPosition(turret)

    -- Refine aim so the beam originates at the muzzle and points directly at the cursor
    local angle = initialAngle
    if cursorPos then
        angle = math.atan2(cursorPos.y - sy, cursorPos.x - sx)
    end

    if angle ~= turret.currentAimAngle then
        turret.currentAimAngle = angle
        sx, sy = Turret.getTurretWorldPosition(turret)
    else
        turret.currentAimAngle = angle
    end

    local maxRange = turret.maxRange or 0
    local effectiveRange = maxRange
    local endX, endY

    if cursorPos then
        local dx = cursorPos.x - sx
        local dy = cursorPos.y - sy
        local cursorDistance = math.sqrt(dx * dx + dy * dy)

        if maxRange > 0 then
            effectiveRange = math.min(cursorDistance, maxRange)
        else
            effectiveRange = cursorDistance
        end

        if cursorDistance > 0 then
            local scale = effectiveRange / cursorDistance
            endX = sx + dx * scale
            endY = sy + dy * scale
        else
            effectiveRange = 0
            endX = sx
            endY = sy
        end
    else
        endX = sx + math.cos(angle) * effectiveRange
        endY = sy + math.sin(angle) * effectiveRange
    end

    local hitTarget, hitX, hitY = UtilityBeams.performMiningHitscan(
        sx, sy, endX, endY, turret, world
    )

    local wasActive = turret.beamActive
    -- Use collision point if hit, otherwise use effective range end point
    local beamEndX = hitX or endX
    local beamEndY = hitY or endY

    local energyStarved = false
    if turret.energyPerSecond and turret.owner and turret.owner.components and turret.owner.components.health and turret.owner.isPlayer then
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
        if turret.miningSoundActive or turret.miningSoundInstance then
            TurretEffects.stopMiningSound(turret)
        end
        return
    end

    turret.beamActive = true
    turret.beamStartX = sx
    turret.beamStartY = sy
    turret.beamEndX = beamEndX
    turret.beamEndY = beamEndY
    turret.beamTarget = hitTarget

    -- Try to send utility beam weapon fire request first (for clients)
    local requestSent = sendUtilityBeamWeaponFireRequest(turret, sx, sy, angle, effectiveRange, "mining")

    -- If not a client or request failed, process beam locally (for host)
    if not requestSent then
        -- Host processes beam locally
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

            -- Only create visual effects, no collision sound for mining
            if Effects and Effects.spawnImpact then
                local ex = hitTarget.components.position.x
                local ey = hitTarget.components.position.y
                local targetRadius = (hitTarget.components.collidable and hitTarget.components.collidable.radius) or 30
                local impactAngle = math.atan2(hitY - ey, hitX - ex)
                
                -- Create visual impact without sound
                Effects.spawnImpact('hull', ex, ey, targetRadius, hitX, hitY, impactAngle, nil, 'mining_laser', hitTarget, true)
            end
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

    -- Handle continuous mining laser sound
    if not wasActive then
        -- Start the mining laser sound (it will loop)
        if isTurretInputActive(turret) then
            TurretEffects.playFiringSound(turret)
        end
    elseif wasActive and not isTurretInputActive(turret) then
        -- Beam was active but input is no longer active, stop sound
        if turret.miningSoundActive or turret.miningSoundInstance then
            TurretEffects.stopMiningSound(turret)
        end
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
        
        -- Play asteroid pop sound immediately when destroyed
        local Sound = require("src.core.sound")
        local x = target.components.position.x
        local y = target.components.position.y
        Sound.triggerEventAt('asteroid_pop', x, y)
        
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
    if locked or not isTurretInputActive(turret) or not turret:canFire() then
        turret.beamActive = false
        turret.beamTarget = nil
        if turret.salvagingSoundActive or turret.salvagingSoundInstance then
            TurretEffects.stopSalvagingSound(turret)
        end
        return
    end

    -- Continuous visual effects - no timer needed

    -- Determine aim angle first relative to ship, then compute muzzle and precise distance from muzzle to cursor
    local Turret = require("src.systems.turret.core")
    local shipPos = turret.owner.components and turret.owner.components.position
    local cursorPos = turret.owner.cursorWorldPos
    local initialAngle

    if cursorPos and shipPos then
        initialAngle = math.atan2(cursorPos.y - shipPos.y, cursorPos.x - shipPos.x)
    elseif shipPos then
        initialAngle = shipPos.angle
    else
        initialAngle = 0
    end

    turret.currentAimAngle = initialAngle

    -- Now compute turret muzzle position using the provisional aim
    local sx, sy = Turret.getTurretWorldPosition(turret)

    -- Refine aim so the beam originates at the muzzle and points directly at the cursor
    local angle = initialAngle
    if cursorPos then
        angle = math.atan2(cursorPos.y - sy, cursorPos.x - sx)
    end

    if angle ~= turret.currentAimAngle then
        turret.currentAimAngle = angle
        sx, sy = Turret.getTurretWorldPosition(turret)
    else
        turret.currentAimAngle = angle
    end

    local maxRange = turret.maxRange or 0
    local effectiveRange = maxRange
    local endX, endY

    if cursorPos then
        local dx = cursorPos.x - sx
        local dy = cursorPos.y - sy
        local cursorDistance = math.sqrt(dx * dx + dy * dy)

        if maxRange > 0 then
            effectiveRange = math.min(cursorDistance, maxRange)
        else
            effectiveRange = cursorDistance
        end

        if cursorDistance > 0 then
            local scale = effectiveRange / cursorDistance
            endX = sx + dx * scale
            endY = sy + dy * scale
        else
            effectiveRange = 0
            endX = sx
            endY = sy
        end
    else
        endX = sx + math.cos(angle) * effectiveRange
        endY = sy + math.sin(angle) * effectiveRange
    end

    local hitTarget, hitX, hitY = UtilityBeams.performMiningHitscan(
        sx, sy, endX, endY, turret, world
    )

    local wasActive = turret.beamActive
    -- Use collision point if hit, otherwise use effective range end point
    local beamEndX = hitX or endX
    local beamEndY = hitY or endY

    local energyStarved = false
    if turret.energyPerSecond and turret.owner and turret.owner.components and turret.owner.components.health and turret.owner.isPlayer then
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
        if turret.salvagingSoundActive or turret.salvagingSoundInstance then
            TurretEffects.stopSalvagingSound(turret)
        end
        return
    end

    turret.beamActive = true
    turret.beamStartX = sx
    turret.beamStartY = sy
    turret.beamEndX = beamEndX
    turret.beamEndY = beamEndY
    turret.beamTarget = hitTarget

    -- Try to send utility beam weapon fire request first (for clients)
    local requestSent = sendUtilityBeamWeaponFireRequest(turret, sx, sy, angle, effectiveRange, "salvaging")

    -- If not a client or request failed, process beam locally (for host)
    if not requestSent then
        -- Host processes beam locally
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

    -- Handle continuous salvaging laser sound
    if not wasActive and isTurretInputActive(turret) then
        TurretEffects.playFiringSound(turret)
    elseif wasActive and not isTurretInputActive(turret) then
        -- Beam was active but input is no longer active, stop sound
        if turret.salvagingSoundActive or turret.salvagingSoundInstance then
            TurretEffects.stopSalvagingSound(turret)
        end
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

-- Handle plasma torch operation (continuous beam with area damage)
function UtilityBeams.updatePlasmaTorch(turret, dt, target, locked, world)
    if locked or not isTurretInputActive(turret) or not turret:canFire() then
        turret.beamActive = false
        turret.beamTarget = nil
        return
    end

    -- Determine aim angle first relative to ship, then compute muzzle and precise distance from muzzle to cursor
    local Turret = require("src.systems.turret.core")
    local shipPos = turret.owner.components and turret.owner.components.position
    local cursorPos = turret.owner.cursorWorldPos
    local angle = 0

    if cursorPos and shipPos then
        angle = math.atan2(cursorPos.y - shipPos.y, cursorPos.x - shipPos.x)
    elseif shipPos then
        angle = shipPos.angle or 0
    end

    turret.currentAimAngle = angle

    -- Get turret world position based on provisional aim
    local sx, sy = Turret.getTurretWorldPosition(turret)

    if cursorPos then
        angle = math.atan2(cursorPos.y - sy, cursorPos.x - sx)
        turret.currentAimAngle = angle
        sx, sy = Turret.getTurretWorldPosition(turret)
    end

    local maxRange = turret.maxRange or 400
    local beamEndX, beamEndY

    if cursorPos then
        local dx = cursorPos.x - sx
        local dy = cursorPos.y - sy
        local distance = math.sqrt(dx * dx + dy * dy)
        local effectiveRange = maxRange > 0 and math.min(distance, maxRange) or distance

        if distance > 0 then
            local scale = effectiveRange / distance
            beamEndX = sx + dx * scale
            beamEndY = sy + dy * scale
        else
            beamEndX = sx
            beamEndY = sy
        end
    else
        beamEndX = sx + math.cos(angle) * maxRange
        beamEndY = sy + math.sin(angle) * maxRange
    end

    -- Perform beam collision detection
    local hitTarget, hitX, hitY = UtilityBeams.performBeamCollision(sx, sy, beamEndX, beamEndY, world, turret.owner)

    local energyStarved = false
    if turret.energyPerSecond and turret.owner and turret.owner.components and turret.owner.components.health and turret.owner.isPlayer then
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
        return
    end

    -- Update beam state
    local wasActive = turret.beamActive
    turret.beamActive = true
    turret.beamStartX = sx
    turret.beamStartY = sy
    turret.beamEndX = beamEndX
    turret.beamEndY = beamEndY
    turret.beamTarget = hitTarget

    -- Calculate damage rate
    local cycle = math.max(0.1, turret.cycle)
    local damageRate = (turret.damagePerSecond or 30) / cycle

    if hitTarget then
        -- Apply damage to hit target
        local damageValue = damageRate * dt
        if hitTarget.components and hitTarget.components.health then
            local CollisionEffects = require("src.systems.collision.effects")
            CollisionEffects.applyDamage(hitTarget, damageValue, turret.owner)
        end

        -- Create impact effects
        TurretEffects.createImpactEffect(turret, hitX, hitY, hitTarget, "plasma_torch")
    end

    turret.cooldownOverride = 0

    -- Handle continuous plasma torch sound
    if not wasActive and isTurretInputActive(turret) then
        TurretEffects.playFiringSound(turret)
    elseif wasActive and not isTurretInputActive(turret) then
        -- Stop sound when beam stops
        if turret.plasmaTorchSoundActive or turret.plasmaTorchSoundInstance then
            TurretEffects.stopPlasmaTorchSound(turret)
        end
    end
end


return UtilityBeams
