-- Collision detection is now handled by Windfield physics
local TurretEffects = require("src.systems.turret.effects")
local CollisionEffects = require("src.systems.collision.effects")
local Effects = require("src.systems.effects")
local Skills = require("src.core.skills")
local Notifications = require("src.ui.notifications")
local Events = require("src.core.events")
local Log = require("src.core.log")
local TurretCore = require("src.systems.turret.core")
local Radius = require("src.systems.collision.radius")
local PhysicsSystem = require("src.systems.physics")

local UtilityBeams = {}

-- Check if two entities are in the same faction (can heal each other)
function UtilityBeams.isSameFaction(entity, other)
    if not other or entity == other then
        return false
    end

    if entity.isEnemy then
        return other.isEnemy == true
    end

    if entity.isPlayer or entity.isRemotePlayer then
        return other.isPlayer == true or other.isRemotePlayer == true
    end

    if entity.components and entity.components.ai and not entity.isEnemy then
        return other.components and other.components.ai and not other.isEnemy
    end

    return false
end

local function resetBeamState(turret)
    turret.beamActive = false
    turret.beamTarget = nil
    turret.beamStartX = nil
    turret.beamStartY = nil
    turret.beamEndX = nil
    turret.beamEndY = nil
end

local function computeBeamTarget(turret, world)
    local owner = turret.owner or {}
    local shipPos = owner.components and owner.components.position
    local cursorPos = owner.cursorWorldPos

    local initialAngle
    if cursorPos and shipPos then
        initialAngle = math.atan2(cursorPos.y - shipPos.y, cursorPos.x - shipPos.x)
    elseif shipPos then
        initialAngle = shipPos.angle
    else
        initialAngle = 0
    end

    turret.currentAimAngle = initialAngle

    local sx, sy = TurretCore.getTurretWorldPosition(turret)

    local angle = initialAngle
    if cursorPos then
        angle = math.atan2(cursorPos.y - sy, cursorPos.x - sx)
    end

    if angle ~= turret.currentAimAngle then
        turret.currentAimAngle = angle
        sx, sy = TurretCore.getTurretWorldPosition(turret)
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

    return {
        startX = sx,
        startY = sy,
        angle = angle,
        effectiveRange = effectiveRange,
        endX = endX,
        endY = endY,
        hitTarget = hitTarget,
        hitX = hitX,
        hitY = hitY,
        beamEndX = hitX or endX,
        beamEndY = hitY or endY
    }
end

local function updateEnergyAndWarnings(turret, dt, weaponName)
    -- Heat management replaces energy system
    -- Heat is managed in the main turret update loop
    -- No additional energy checks needed for utility beams
    local energyStarved = false
    local energyLevel = 1.0

    return energyStarved, energyLevel
end

local function applyBeamState(turret, sx, sy, beamEndX, beamEndY, hitTarget, energyLevel)
    turret.beamActive = true
    turret.beamStartX = sx
    turret.beamStartY = sy
    turret.beamEndX = beamEndX
    turret.beamEndY = beamEndY
    turret.beamTarget = hitTarget
    turret._currentEnergyLevel = energyLevel
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

local function updateBeamSound(turret, wasActive, stopSoundFn)
    if not wasActive then
        if isTurretInputActive(turret) then
            TurretEffects.playFiringSound(turret)
        end
    elseif wasActive and not isTurretInputActive(turret) then
        if stopSoundFn then
            stopSoundFn(turret)
        end
    end
end

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
        resetBeamState(turret)
        if turret.miningSoundActive or turret.miningSoundInstance then
            TurretEffects.stopMiningSound(turret)
        end
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

    local wasActive = turret.beamActive
    local beamData = computeBeamTarget(turret, world)
    local energyStarved, energyLevel = updateEnergyAndWarnings(turret, dt, "Mining laser")

    if energyStarved then
        resetBeamState(turret)
        if turret.miningSoundActive or turret.miningSoundInstance then
            TurretEffects.stopMiningSound(turret)
        end
        return
    end

    applyBeamState(
        turret,
        beamData.startX,
        beamData.startY,
        beamData.beamEndX,
        beamData.beamEndY,
        beamData.hitTarget,
        energyLevel
    )

    local requestSent = sendUtilityBeamWeaponFireRequest(
        turret,
        beamData.startX,
        beamData.startY,
        beamData.angle,
        beamData.effectiveRange,
        "mining"
    )

    if not requestSent then
        -- Host processes beam locally
    end

    local cycle = math.max(0.1, turret.cycle)
    local miningPower = turret.miningPower
    local damageRate = miningPower / cycle

    if beamData.hitTarget then
        if beamData.hitTarget.components and beamData.hitTarget.components.mineable then
            beamData.hitTarget.components.mineable.isBeingMined = true

            local damageValue = damageRate * dt
            UtilityBeams.applyMiningDamage(
                beamData.hitTarget,
                damageValue,
                turret.owner,
                world,
                beamData.hitX,
                beamData.hitY
            )
        else
            TurretEffects.createImpactEffect(
                turret,
                beamData.hitX,
                beamData.hitY,
                beamData.hitTarget,
                "laser"
            )
        end
    else
        local entities = world:get_entities_with_components("mineable")
        for _, entity in ipairs(entities) do
            if entity.components and entity.components.mineable then
                entity.components.mineable.isBeingMined = false
            end
        end
    end

    turret.cooldownOverride = 0

    updateBeamSound(turret, wasActive, TurretEffects.stopMiningSound)
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
        resetBeamState(turret)
        if turret.salvagingSoundActive or turret.salvagingSoundInstance then
            TurretEffects.stopSalvagingSound(turret)
        end
        return
    end

    local wasActive = turret.beamActive
    local beamData = computeBeamTarget(turret, world)
    local energyStarved, energyLevel = updateEnergyAndWarnings(turret, dt, "Salvaging laser")

    if energyStarved then
        resetBeamState(turret)
        if turret.salvagingSoundActive or turret.salvagingSoundInstance then
            TurretEffects.stopSalvagingSound(turret)
        end
        return
    end

    applyBeamState(
        turret,
        beamData.startX,
        beamData.startY,
        beamData.beamEndX,
        beamData.beamEndY,
        beamData.hitTarget,
        energyLevel
    )

    local requestSent = sendUtilityBeamWeaponFireRequest(
        turret,
        beamData.startX,
        beamData.startY,
        beamData.angle,
        beamData.effectiveRange,
        "salvaging"
    )

    if not requestSent then
        -- Host processes beam locally
    end

    local cycle = math.max(0.1, turret.cycle)
    local salvagePower = turret.salvagePower
    local salvageRate = salvagePower / cycle

    if beamData.hitTarget then
        if beamData.hitTarget.components and beamData.hitTarget.components.wreckage then
            if not beamData.hitTarget.components.wreckage.isBeingSalvaged then
                beamData.hitTarget.components.wreckage.isBeingSalvaged = true
            end

            local removed = UtilityBeams.applySalvageDamage(
                beamData.hitTarget,
                salvageRate * dt,
                turret.owner,
                world
            )
            TurretEffects.createImpactEffect(
                turret,
                beamData.hitX,
                beamData.hitY,
                beamData.hitTarget,
                "salvage"
            )
        else
            TurretEffects.createImpactEffect(
                turret,
                beamData.hitX,
                beamData.hitY,
                beamData.hitTarget,
                "laser"
            )
        end
    else
        local entities = world:get_entities_with_components("wreckage")
        for _, entity in ipairs(entities) do
            if entity.components and entity.components.wreckage then
                entity.components.wreckage.isBeingSalvaged = false
            end
        end
    end

    turret.cooldownOverride = 0

    updateBeamSound(turret, wasActive, TurretEffects.stopSalvagingSound)
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
    if not world then
        return nil, endX, endY
    end

    local physicsManager = PhysicsSystem.getManager()
    if not physicsManager then
        return nil, endX, endY
    end

    local isHealingLaser = turret.kind == "healing_laser" or turret.type == "healing_laser"

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
            if isHealingLaser then
                return UtilityBeams.isSameFaction(turret.owner, entity)
            end
            return true
        end
    })

    if not result then
        return nil, endX, endY
    end

    local entity = result.entity
    local hitX = result.x
    local hitY = result.y

    local targetRadius = Radius.getHullRadius(entity)
    if (not targetRadius or targetRadius <= 0) and result.collider and result.collider.getRadius then
        targetRadius = result.collider:getRadius()
    end
    targetRadius = targetRadius or 20

    local CollisionEffects = require("src.systems.collision.effects")
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

    if isHardSurface and Effects.spawnLaserSparks then
        local impactAngle = math.atan2(hitY - startY, hitX - startX)
        local sparkColor = {1.0, 0.8, 0.3, 0.8}

        if turret.type == "mining_laser" then
            sparkColor = {1.0, 0.7, 0.2, 0.8}
        elseif turret.type == "salvaging_laser" then
            sparkColor = {1.0, 0.2, 0.6, 0.8}
        elseif turret.type == "healing_laser" then
            sparkColor = {0.0, 1.0, 0.5, 0.8}
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

    return entity, hitX, hitY
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

    -- Check for turret recovery chance during salvaging
    if not target.turretsRecovered and target.equippedTurrets and #target.equippedTurrets > 0 and source then
        local salvagingLevel = Skills.getLevel("salvaging")
        
        -- Calculate recovery chance for each turret based on its level
        local turretsToRecover = {}
        for _, turret in ipairs(target.equippedTurrets) do
            local turretLevel = 1
            if turret.meta and turret.meta.level then
                turretLevel = turret.meta.level
            end
            
            -- Base chance = 15% - (turret_level × 0.8%), minimum 1%
            local baseChance = math.max(0.01, 0.15 - (turretLevel * 0.008))
            -- Add salvaging skill bonus (+0.3% per level)
            local skillBonus = salvagingLevel * 0.003
            local totalChance = baseChance + skillBonus
            
            if math.random() <= totalChance then
                table.insert(turretsToRecover, turret)
            end
        end
        
        if #turretsToRecover > 0 then
            -- Recover turrets!
            local ItemPickup = require("src.entities.item_pickup")
            local pos = target.components.position
            
            for _, turret in ipairs(turretsToRecover) do
                local angle = math.random() * math.pi * 2
                local dist = math.random(20, 40)
                local px = pos.x + math.cos(angle) * dist
                local py = pos.y + math.sin(angle) * dist
                
                local pickup = ItemPickup.new(px, py, turret.id, turret.qty, 0.8, 0, 0, turret.meta)
                if pickup and world then
                    world:addEntity(pickup)
                end
            end
            
            target.turretsRecovered = true
            -- Grant bonus salvaging XP for turret recovery
            local xpGain = 25 * #turretsToRecover
            Skills.addXp("salvaging", xpGain)
            
            -- Show notification for turret recovery
            if Notifications and Notifications.add then
                Notifications.add("Recovered " .. #turretsToRecover .. " turret(s) from wreckage!", "success")
            end
        end
    end

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

-- Handle healing laser operation (continuous beam with continuous healing)
function UtilityBeams.updateHealingLaser(turret, dt, target, locked, world)
    if locked or not isTurretInputActive(turret) or not turret:canFire() then
        resetBeamState(turret)
        if turret.healingSoundActive or turret.healingSoundInstance then
            TurretEffects.stopHealingSound(turret)
        end
        if world then
            local entities = world:get_entities_with_components("hull")
            for _, entity in ipairs(entities) do
                if entity.components and entity.components.hull then
                    entity.components.hull.isBeingHealed = false
                end
            end
        end
        return
    end

    -- Set target position for AI-controlled healing drones
    if target and target.components and target.components.position then
        local owner = turret.owner or {}
        owner.cursorWorldPos = {
            x = target.components.position.x,
            y = target.components.position.y
        }
    end

    local wasActive = turret.beamActive
    local beamData = computeBeamTarget(turret, world)
    local energyStarved, energyLevel = updateEnergyAndWarnings(turret, dt, "Healing laser")

    if energyStarved then
        resetBeamState(turret)
        if turret.healingSoundActive or turret.healingSoundInstance then
            TurretEffects.stopHealingSound(turret)
        end
        return
    end

    applyBeamState(
        turret,
        beamData.startX,
        beamData.startY,
        beamData.beamEndX,
        beamData.beamEndY,
        beamData.hitTarget,
        energyLevel
    )

    local requestSent = sendUtilityBeamWeaponFireRequest(
        turret,
        beamData.startX,
        beamData.startY,
        beamData.angle,
        beamData.effectiveRange,
        "healing"
    )

    if not requestSent then
        -- Host processes beam locally
    end

    local cycle = math.max(0.1, turret.cycle)
    local healingPower = turret.healingPower or 2.0
    local healingRate = healingPower / cycle

    if beamData.hitTarget then
        if beamData.hitTarget.components and beamData.hitTarget.components.hull then
            beamData.hitTarget.components.hull.isBeingHealed = true

            local healingValue = healingRate * dt
            UtilityBeams.applyHealingDamage(
                beamData.hitTarget,
                healingValue,
                turret,
                world,
                beamData.hitX,
                beamData.hitY,
                dt
            )
            
            -- Spawn healing circle while beam is active (less frequently for subtlety)
            if beamData.hitTarget.components.position then
                local Effects = require("src.systems.effects")
                local targetRadius = 25
                if beamData.hitTarget.components.collidable and beamData.hitTarget.components.collidable.radius then
                    targetRadius = beamData.hitTarget.components.collidable.radius * 1.5
                end
                
                -- Only spawn circle every 0.2 seconds to avoid spam
                if not turret._lastCircleSpawn or (love.timer.getTime() - turret._lastCircleSpawn) > 0.2 then
                    Effects.spawnHealingCircle(beamData.hitTarget.components.position.x, beamData.hitTarget.components.position.y, targetRadius)
                    turret._lastCircleSpawn = love.timer.getTime()
                end
            end
        else
            TurretEffects.createImpactEffect(
                turret,
                beamData.hitX,
                beamData.hitY,
                beamData.hitTarget,
                "laser"
            )
        end
    else
        local entities = world:get_entities_with_components("hull")
        for _, entity in ipairs(entities) do
            if entity.components and entity.components.hull then
                entity.components.hull.isBeingHealed = false
            end
        end
    end

    turret.cooldownOverride = 0

    updateBeamSound(turret, wasActive, TurretEffects.stopHealingSound)
end

-- Apply healing damage to target (hull only, not shield)
function UtilityBeams.applyHealingDamage(target, healing, turret, world, impactX, impactY, dt)
    if not target.components or not target.components.hull then
        return
    end

    dt = dt or 0
    if turret then
        turret._healingParticleCooldown = math.max((turret._healingParticleCooldown or 0) - dt, 0)
    end

    local hull = target.components.hull
    local oldHp = hull.hp or 0

    -- Only heal hull, not shield
    if hull.hp and hull.hp < (hull.maxHP or 0) then
        local hullHealing = math.min(healing, (hull.maxHP or 0) - hull.hp)
        hull.hp = hull.hp + hullHealing
    end

    -- Create healing visual effects
    if (hull.hp or 0) > oldHp then
        local Effects = require("src.systems.effects")
        local canSpawn = true
        if turret and turret._healingParticleCooldown > 0 then
            canSpawn = false
        end

        if canSpawn and Effects.spawnHealingParticles then
            Effects.spawnHealingParticles(impactX, impactY)
            if turret then
                local interval = turret.healingParticleInterval or 0.25
                turret._healingParticleCooldown = interval
            end
        end
        
        -- Spawn healing circle around target
        if target.components.position then
            local targetRadius = 25 -- Base radius for the healing circle
            if target.components.collidable and target.components.collidable.radius then
                targetRadius = target.components.collidable.radius * 1.5 -- Make circle slightly larger than target
            end
            Effects.spawnHealingCircle(target.components.position.x, target.components.position.y, targetRadius)
        end
        
        -- Spawn floating healing number (only for significant healing amounts)
        local healingAmount = (hull.hp or 0) - oldHp
        if healingAmount > 0.5 then -- Only show numbers for healing > 0.5
            Effects.spawnHealingNumber(impactX, impactY, healingAmount)
        end
    end
end

return UtilityBeams
