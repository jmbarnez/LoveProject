--[[
  AI Context System
  
  Gathers and maintains context information for AI decision making.
  Provides real-time data about the game state, entity status, and environment.
]]

local Log = require("src.core.log")

local AIContext = {}

-- Create context for an entity
function AIContext.createContext(entity)
    return {
        entity = entity,
        position = {x = 0, y = 0},
        healthPercent = 1.0,
        ammoPercent = 1.0,
        energyPercent = 1.0,
        speed = 0,
        maxSpeed = 500,
        distanceToPlayer = 0,
        distanceToNearestEnemy = 0,
        distanceToNearestAlly = 0,
        threatLevel = 0.0,
        equipment = {},
        nearbyEntities = {},
        lastUpdate = 0,
        gameTime = 0
    }
end

-- Update context for an entity
function AIContext.updateContext(context, entity, world, globalContext)
    if not context or not entity then return end
    
    context.gameTime = globalContext.gameTime or 0
    context.lastUpdate = context.gameTime
    
    -- Update position
    if entity.components and entity.components.position then
        context.position.x = entity.components.position.x
        context.position.y = entity.components.position.y
    end
    
    -- Update health
    if entity.components and entity.components.hull then
        local hull = entity.components.hull
        context.healthPercent = (hull.hp or 0) / (hull.maxHP or 100)
    end
    
    -- Update ammo/energy
    if entity.components and entity.components.energy then
        local energy = entity.components.energy
        context.energyPercent = (energy.energy or 0) / (energy.maxEnergy or 100)
    end
    
    -- Update speed
    if entity.components then
        local vx, vy = 0, 0
        local maxSpeed = 500
        
        -- Check Windfield physics first
        if entity.components.windfield_physics then
            local PhysicsSystem = require("src.systems.physics")
            local manager = PhysicsSystem.getManager()
            if manager then
                local collider = manager:getCollider(entity)
                if collider then
                    vx, vy = collider:getLinearVelocity()
                end
            end
        -- Check legacy physics
        elseif entity.components.physics and entity.components.physics.body then
            local body = entity.components.physics.body
            vx = body.vx or 0
            vy = body.vy or 0
            maxSpeed = body.maxSpeed or 500
        end
        
        context.speed = math.sqrt(vx * vx + vy * vy)
        context.maxSpeed = maxSpeed
    end
    
    -- Update distances
    AIContext.updateDistances(context, entity, world, globalContext)
    
    -- Update threat level
    AIContext.updateThreatLevel(context, entity, world, globalContext)
    
    -- Update equipment
    AIContext.updateEquipment(context, entity)
    
    -- Update nearby entities
    AIContext.updateNearbyEntities(context, entity, world)
end

-- Update distances to important entities
function AIContext.updateDistances(context, entity, world, globalContext)
    local pos = context.position
    local minEnemyDist = math.huge
    local minAllyDist = math.huge
    
    -- Distance to player
    if globalContext.playerPosition then
        local dx = pos.x - globalContext.playerPosition.x
        local dy = pos.y - globalContext.playerPosition.y
        context.distanceToPlayer = math.sqrt(dx * dx + dy * dy)
    end
    
    -- Find nearest enemy and ally
    if world and world.entities then
        for _, otherEntity in ipairs(world.entities) do
            if otherEntity ~= entity and otherEntity.components and otherEntity.components.position then
                local otherPos = otherEntity.components.position
                local dx = pos.x - otherPos.x
                local dy = pos.y - otherPos.y
                local distance = math.sqrt(dx * dx + dy * dy)
                
                if otherEntity.isEnemy then
                    minEnemyDist = math.min(minEnemyDist, distance)
                elseif otherEntity.isPlayer or otherEntity.isRemotePlayer then
                    minAllyDist = math.min(minAllyDist, distance)
                end
            end
        end
    end
    
    context.distanceToNearestEnemy = minEnemyDist == math.huge and 0 or minEnemyDist
    context.distanceToNearestAlly = minAllyDist == math.huge and 0 or minAllyDist
end

-- Update threat level based on nearby enemies and situation
function AIContext.updateThreatLevel(context, entity, world, globalContext)
    local threat = 0.0
    
    -- Base threat from nearby enemies
    if context.distanceToNearestEnemy > 0 and context.distanceToNearestEnemy < 300 then
        threat = threat + (300 - context.distanceToNearestEnemy) / 300
    end
    
    -- Health-based threat (more threatened when damaged)
    threat = threat + (1.0 - context.healthPercent) * 0.5
    
    -- Ammo-based threat (more threatened when low on ammo)
    if context.ammoPercent < 0.3 then
        threat = threat + 0.3
    end
    
    -- Player threat level
    if globalContext.playerThreat then
        threat = threat + globalContext.playerThreat * 0.3
    end
    
    -- Clamp threat between 0 and 1
    context.threatLevel = math.max(0, math.min(1, threat))
end

-- Update equipment information
function AIContext.updateEquipment(context, entity)
    context.equipment = {
        hasHealingWeapon = false,
        hasMiningWeapon = false,
        hasLongRangeWeapon = false,
        hasCloseRangeWeapon = false,
        hasMissileWeapon = false,
        weaponCount = 0
    }
    
    if entity.components and entity.components.equipment and entity.components.equipment.grid then
        for _, slot in ipairs(entity.components.equipment.grid) do
            if slot and slot.type == "turret" and slot.module then
                context.equipment.weaponCount = context.equipment.weaponCount + 1
                
                local turret = slot.module
                local turretType = turret.kind or turret.type
                
                if turretType == "healing_laser" then
                    context.equipment.hasHealingWeapon = true
                elseif turretType == "mining_laser" or turretType == "salvaging_laser" then
                    context.equipment.hasMiningWeapon = true
                elseif turretType == "railgun_turret" or turretType == "missile_launcher" then
                    context.equipment.hasLongRangeWeapon = true
                elseif turretType == "basic_cannon" or turretType == "low_power_laser" then
                    context.equipment.hasCloseRangeWeapon = true
                elseif turretType == "missile_launcher" then
                    context.equipment.hasMissileWeapon = true
                end
            end
        end
    end
end

-- Update nearby entities
function AIContext.updateNearbyEntities(context, entity, world)
    context.nearbyEntities = {
        enemies = {},
        allies = {},
        neutrals = {},
        stations = {},
        asteroids = {}
    }
    
    if not world or not world.entities then return end
    
    local pos = context.position
    local detectionRange = 500 -- Detection range
    
    for _, otherEntity in ipairs(world.entities) do
        if otherEntity ~= entity and otherEntity.components and otherEntity.components.position then
            local otherPos = otherEntity.components.position
            local dx = pos.x - otherPos.x
            local dy = pos.y - otherPos.y
            local distance = math.sqrt(dx * dx + dy * dy)
            
            if distance <= detectionRange then
                local entityInfo = {
                    entity = otherEntity,
                    distance = distance,
                    position = {x = otherPos.x, y = otherPos.y},
                    health = 1.0,
                    threat = 0.0
                }
                
                -- Get health info
                if otherEntity.components and otherEntity.components.hull then
                    local hull = otherEntity.components.hull
                    entityInfo.health = (hull.hp or 0) / (hull.maxHP or 100)
                end
                
                -- Categorize entity
                if otherEntity.isEnemy then
                    table.insert(context.nearbyEntities.enemies, entityInfo)
                elseif otherEntity.isPlayer or otherEntity.isRemotePlayer then
                    table.insert(context.nearbyEntities.allies, entityInfo)
                elseif otherEntity.components and otherEntity.components.station then
                    table.insert(context.nearbyEntities.stations, entityInfo)
                elseif otherEntity.components and otherEntity.components.mineable then
                    table.insert(context.nearbyEntities.asteroids, entityInfo)
                else
                    table.insert(context.nearbyEntities.neutrals, entityInfo)
                end
            end
        end
    end
end

-- Get context summary for debugging
function AIContext.getSummary(context)
    return {
        health = string.format("%.1f%%", context.healthPercent * 100),
        ammo = string.format("%.1f%%", context.ammoPercent * 100),
        energy = string.format("%.1f%%", context.energyPercent * 100),
        speed = string.format("%.0f/%.0f", context.speed, context.maxSpeed),
        distanceToPlayer = string.format("%.0f", context.distanceToPlayer),
        threatLevel = string.format("%.2f", context.threatLevel),
        nearbyEnemies = #context.nearbyEntities.enemies,
        nearbyAllies = #context.nearbyEntities.allies,
        weaponCount = context.equipment.weaponCount
    }
end

-- Check if entity is in combat
function AIContext.isInCombat(context)
    return context.threatLevel > 0.3 or context.distanceToNearestEnemy < 200
end

-- Check if entity is safe
function AIContext.isSafe(context)
    return context.threatLevel < 0.1 and context.distanceToNearestEnemy > 400
end

-- Check if entity needs healing
function AIContext.needsHealing(context)
    return context.healthPercent < 0.5
end

-- Check if entity needs ammo
function AIContext.needsAmmo(context)
    return context.ammoPercent < 0.2
end

-- Check if entity can engage
function AIContext.canEngage(context)
    return context.healthPercent > 0.3 and context.ammoPercent > 0.1 and context.equipment.weaponCount > 0
end

-- Get recommended action based on context
function AIContext.getRecommendedAction(context)
    if context.threatLevel > 0.8 then
        return "flee"
    elseif context.threatLevel > 0.5 then
        return "retreat"
    elseif context.needsHealing(context) then
        return "support"
    elseif context.needsAmmo(context) then
        return "dock"
    elseif context.canEngage(context) and context.distanceToNearestEnemy < 300 then
        return "engage"
    elseif context.equipment.hasMiningWeapon and context.distanceToNearestEnemy > 400 then
        return "mine"
    else
        return "patrol"
    end
end

return AIContext
