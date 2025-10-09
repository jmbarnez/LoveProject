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
    local energyLevel = 1.0 -- Full energy by default
    
    if turret.energyPerSecond and turret.owner and turret.owner.components and turret.owner.components.health and turret.owner.isPlayer then
        local currentEnergy = turret.owner.components.health.energy or 0
        local maxEnergy = turret.owner.components.health.maxEnergy or 100
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
                turret.owner.components.health.energy = math.max(0, currentEnergy - energyCost)
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
                    local weaponName = turret.kind == "mining_laser" and "Mining laser" or "Salvaging laser"
                    if currentWarningLevel == "critical" then
                        Notifications.add("Critical energy! " .. weaponName .. " power failing!", "warning")
                    elseif currentWarningLevel == "low" then
                        Notifications.add("Low energy - " .. weaponName .. " power reduced", "info")
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
    
    -- Store energy level for rendering system
    turret._currentEnergyLevel = energyLevel

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
            -- Set mining flag
            hitTarget.components.mineable.isBeingMined = true
            
            local damageValue = damageRate * dt
            UtilityBeams.applyMiningDamage(hitTarget, damageValue, turret.owner, world, hitX, hitY)

            -- Only create visual effects, no collision sound for mining
            -- Collision effects are now handled exclusively by the unified collision system
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

    -- Apply base damage
    local finalDamage = damage

    -- Play asteroid impact sound based on damage amount
    local Sound = require("src.core.sound")
    local x = target.components.position.x
    local y = target.components.position.y
    -- Removed impact sounds for mining lasers - only keep the laser firing sound

    mineable.durability = math.max(0, mineable.durability - finalDamage)

    -- Update progress for cracking visual effects
    mineable._durabilityProgress = mineable.maxDurability - mineable.durability

    -- Check if asteroid is completely mined
    if mineable.durability <= 0 then
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
    -- Create resource pickups based on asteroid type
    local ItemPickup = require("src.entities.item_pickup")
    
    -- Drop ore based on asteroid type
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
    local energyLevel = 1.0 -- Full energy by default
    
    if turret.energyPerSecond and turret.owner and turret.owner.components and turret.owner.components.health and turret.owner.isPlayer then
        local currentEnergy = turret.owner.components.health.energy or 0
        local maxEnergy = turret.owner.components.health.maxEnergy or 100
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
                turret.owner.components.health.energy = math.max(0, currentEnergy - energyCost)
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
                    local weaponName = turret.kind == "mining_laser" and "Mining laser" or "Salvaging laser"
                    if currentWarningLevel == "critical" then
                        Notifications.add("Critical energy! " .. weaponName .. " power failing!", "warning")
                    elseif currentWarningLevel == "low" then
                        Notifications.add("Low energy - " .. weaponName .. " power reduced", "info")
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
    
    -- Store energy level for rendering system
    turret._currentEnergyLevel = energyLevel

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
                    
                    -- Create collision effects for beam hits
                    local CollisionEffects = require("src.systems.collision.effects")
                    local now = (love and love.timer and love.timer.getTime and love.timer.getTime()) or 0
                    if CollisionEffects.canEmitCollisionFX(turret, entity, now) then
                        local beamRadius = 1 -- Beams are line segments
                        
                        -- Use the precise hit position for collision effects
                        CollisionEffects.createCollisionEffects(turret, entity, hx, hy, hx, hy, 0, 0, beamRadius, targetRadius, nil, nil)
                    end
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

    -- Only give resources when wreckage is completely destroyed
    if remaining <= 0 then
        local initialTotal = wreckage.maxSalvageAmount or wreckage.salvageAmount
        local totalToDrop = math.max(1, math.floor(initialTotal))
        
        if totalToDrop > 0 then
            spawnSalvagePickup(target, totalToDrop, world)
            
            -- Give XP for all salvaged resources at once
            if source then
                local xpBase = 10
                local salvagingLevel = Skills.getLevel("salvaging")
                local xpGain = xpBase * (1 + salvagingLevel * 0.06) * totalToDrop
                local leveledUp = Skills.addXp("salvaging", xpGain)

                if leveledUp then
                    Notifications.action("Salvaging level up!")
                end

                -- Emit salvage event for all resources
                Events.emit(Events.GAME_EVENTS.WRECKAGE_SALVAGED, {
                    player = source,
                    amount = totalToDrop,
                    resourceId = wreckage.resourceType or "scraps",
                    wreckage = target,
                    wreckageId = target.id
                })
            end
        end
        
        UtilityBeams.completeSalvage(nil, target, world)
        target.dead = true
    end

    return applied > 0
end

return UtilityBeams
