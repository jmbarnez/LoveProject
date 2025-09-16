local Util = require("src.core.util")
local AIComponent = require("src.components.ai")
local Sound = require("src.core.sound")

local AISystem = {}

-- Constants for state management
local ENGAGE_RANGE_BUFFER = 150
local SAFE_DISTANCE = 1200

-- #################################################################################
-- ## State Handlers
-- #################################################################################

local function handleIdleState(entity, dt)
    local ai = entity.components.ai
    ai.wanderTimer = (ai.wanderTimer or 0) - dt
    if (ai.wanderTimer or 0) <= 0 then
        ai.wanderTimer = 1 + math.random() * 2.5
        local jitter = (math.random() * 0.6 - 0.3)
        if math.random() < 0.25 then jitter = jitter + (math.random() * math.pi - math.pi/2) * 0.2 end
        ai.wanderDir = ((ai.wanderDir or 0) + jitter) % (2*math.pi)
    end
    local speed = ai.wanderSpeed or 80
    local moveVx = math.cos(ai.wanderDir or 0) * speed
    local moveVy = math.sin(ai.wanderDir or 0) * speed
    
    local body = entity.components.physics and entity.components.physics.body
    if body then
        body.vx, body.vy = moveVx, moveVy
    else
        entity.components.velocity.x, entity.components.velocity.y = moveVx, moveVy
    end
end

local function handleHuntingState(entity, dt, world, spawnProjectile)
    local ai = entity.components.ai
    local target = ai.target
    if not target then return end

    if not target.components or not target.components.position then
        return
    end
    local ex, ey = entity.components.position.x, entity.components.position.y
    local px, py = target.components.position.x, target.components.position.y
    local dist = Util.distance(ex, ey, px, py)

    -- Predictive Targeting
    local optimalRange = 380  -- Default optimal range
    local projectileSpeed = 1000  -- Default projectile speed
    
    -- Try to get turret data if available
    if entity.components.equipment and entity.components.equipment.turrets and 
       entity.components.equipment.turrets[1] and entity.components.equipment.turrets[1].turret then
        local primaryTurret = entity.components.equipment.turrets[1].turret
        projectileSpeed = primaryTurret.projectile and primaryTurret.projectile.speed or 1000
        optimalRange = primaryTurret.optimal or 380
    end
    
    local timeToTarget = dist / projectileSpeed
    local targetVel = target.components.velocity or {x = 0, y = 0}
    local predictedPx = px + (targetVel.x or 0) * timeToTarget
    local predictedPy = py + (targetVel.y or 0) * timeToTarget

    -- Orbital Mechanics and Positioning
    local toPlayerAngle = Util.angleTo(ex, ey, predictedPx, predictedPy)
    local desired = optimalRange * 0.9
    local orbitAngle = toPlayerAngle + math.pi * 0.5
    local perpx, perpy = math.cos(orbitAngle), math.sin(orbitAngle)
    local baseSpeed, maxSpeed = 200, 240
    
    -- Range Correction
    local error = desired - dist
    local radialSpeed = math.max(-180, math.min(180, -error * 1.2))
    local rvx, rvy = math.cos(toPlayerAngle) * radialSpeed, math.sin(toPlayerAngle) * radialSpeed
    local tvx, tvy = perpx * baseSpeed, perpy * baseSpeed
    
    -- Calculate desired movement vector
    local moveX, moveY = rvx + tvx, rvy + tvy
    local moveMag = math.sqrt(moveX*moveX + moveY*moveY)
    if moveMag > 0 then
        -- Normalize and scale by max speed
        moveX, moveY = (moveX / moveMag) * maxSpeed, (moveY / moveMag) * maxSpeed
    end
    
    -- Apply physics-based movement similar to player
    local body = entity.components.physics and entity.components.physics.body
    if body then
        -- Calculate acceleration based on ship mass and thrust
        local thrust = body.thrusterPower and body.thrusterPower.main or 600000
        local accel = (thrust / (body.mass or 500)) * dt
        
        -- Calculate desired velocity change
        local targetVx, targetVy = moveX, moveY
        local currentVx, currentVy = body.vx or 0, body.vy or 0
        
        -- Apply acceleration towards target velocity
        local newVx = Util.lerp(currentVx, targetVx, accel * dt)
        local newVy = Util.lerp(currentVy, targetVy, accel * dt)
        
        -- Apply velocity with speed cap
        local newSpeed = math.sqrt(newVx*newVx + newVy*newVy)
        if newSpeed > maxSpeed then
            local scale = maxSpeed / newSpeed
            newVx, newVy = newVx * scale, newVy * scale
        end
        
        -- Apply the new velocity
        body.vx, body.vy = newVx, newVy
    else
        -- Fallback to simple movement if no physics body
        entity.components.velocity.x, entity.components.velocity.y = moveX, moveY
    end

    -- Smooth rotation with physics
    local currentAngle = entity.components.position.angle or 0
    local diff = (toPlayerAngle - currentAngle + math.pi) % (2*math.pi) - math.pi
    local maxTurnRate = 6.0  -- Same as player turn rate
    local step = math.max(-maxTurnRate * dt, math.min(maxTurnRate * dt, diff))
    
    if body then
        body.angle = currentAngle + step
        -- Zero out angular velocity to prevent wobble (like player)
        body.angularVel = 0
    else
        entity.components.position.angle = currentAngle + step
    end

    -- Firing Logic
    if not entity.components.equipment or not entity.components.equipment.turrets then
        print("AI Warning: No turrets found on entity")
        return
    end
    
    local turrets = entity.components.equipment.turrets
    if #turrets == 0 then
        print("AI Warning: Empty turrets table")
        return
    end
    
    -- Debug: Print turret info
    for i, turretData in ipairs(turrets) do
        if not turretData or not turretData.turret then
            print(string.format("AI Warning: Invalid turret data at index %d", i))
        end
    end
    
    for _, turretData in ipairs(turrets) do
        if turretData and turretData.turret and turretData.enabled ~= false then
            -- Calculate max range for this turret
            local turret = turretData.turret
            local maxRange = (turret.optimal or 0) + (turret.falloff or 0)
            local angleToTarget = Util.angleTo(entity.components.position.x, entity.components.position.y, 
                                            target.components.position.x, target.components.position.y)
            local currentAngle = entity.components.position.angle or 0
            local angleDiff = math.abs((angleToTarget - currentAngle + math.pi) % (2 * math.pi) - math.pi)
            
            -- Simple firing check - only check range and angle
            local shouldFire = dist <= maxRange and angleDiff < math.pi/4
            
            -- Debug logging
            if true then  -- Always show debug info for now
                local currentEnergy = entity.components.health and entity.components.health.energy or 0
                local maxEnergy = entity.components.health and entity.components.health.maxEnergy or 100
                local energyCost = turret.capCost or 10
                
                print(string.format("AI Debug: range=%.1f/%.1f, angle=%.2f/%.2f, energy=%.1f/%.1f (cost=%.1f)",
                    dist, maxRange,
                    math.deg(angleDiff), math.deg(math.pi/4),
                    currentEnergy, maxEnergy, energyCost
                ))
                if shouldFire then
                    print("==> FIRING!")
                end
            end
            
            -- Create a shooting callback
            local function shootCallback(x, y, angle, friendly, kind, damage, dist2, style, target, weaponDef)
                if not spawnProjectile then 
                    print("ERROR: No spawnProjectile function!")
                    return 
                end
                
                -- Deduct fixed energy cost if entity has energy
                local energyCost = turret.capCost or 10
                local hadEnergy = entity.components.health and entity.components.health.energy or 0
                
                if entity.components.health then
                    entity.components.health.energy = math.max(0, entity.components.health.energy - energyCost)
                end
                
                print(string.format("FIRING: energy %.1f -> %.1f (cost: %.1f)", 
                    hadEnergy, entity.components.health and entity.components.health.energy or 0, energyCost))
                
                spawnProjectile(x, y, angle, false, kind, damage, dist2, style, target, weaponDef)
            end
            
            -- Get the world reference from the entity if available
            local worldRef = entity.world or (entity.components and entity.components.world) or world
            
            -- Make sure we have a valid spawnProjectile function
            if type(spawnProjectile) ~= "function" then
                print("WARNING: No valid spawnProjectile function provided to AI system")
                return
            end
            
            -- Update turret with firing command
            turret:update(dt, target, not shouldFire, worldRef, shootCallback)
        end
    end
end

local function handleEvadingState(entity, dt)
    local ai = entity.components.ai
    ai.evadeTimer = (ai.evadeTimer or 0) - dt
    
    if not ai.evadeDir then
        local randomAngle = math.random() * math.pi * 2
        ai.evadeDir = {x = math.cos(randomAngle), y = math.sin(randomAngle)}
    end
    
    local speed = 300 -- Evasive speed
    local moveVx = ai.evadeDir.x * speed
    local moveVy = ai.evadeDir.y * speed
    
    local body = entity.components.physics and entity.components.physics.body
    if body then
        body.vx, body.vy = moveVx, moveVy
    else
        entity.components.velocity.x, entity.components.velocity.y = moveVx, moveVy
    end
end

local function handleRetreatingState(entity, dt)
    local ai = entity.components.ai
    local target = ai.target
    if not target then return end

    if not target.components or not target.components.position then
        return
    end
    local ex, ey = entity.components.position.x, entity.components.position.y
    local px, py = target.components.position.x, target.components.position.y
    
    local fromPlayerAngle = Util.angleTo(px, py, ex, ey)
    local speed = 250 -- Retreat speed
    local moveVx = math.cos(fromPlayerAngle) * speed
    local moveVy = math.sin(fromPlayerAngle) * speed
    
    local body = entity.components.physics and entity.components.physics.body
    if body then
        body.vx, body.vy = moveVx, moveVy
    else
        entity.components.velocity.x, entity.components.velocity.y = moveVx, moveVy
    end
end

-- #################################################################################
-- ## Core AI Logic
-- #################################################################################

local function findTarget(entity, world)
    local players = world:get_entities_with_components("player")
    if #players > 0 then
        return players[1] -- Return first player as the target
    end
    return nil
end

local function updateState(entity, dt)
    local ai = entity.components.ai
    local health = entity.components.health
    local target = ai.target
    
    -- Health-based state changes
    if health and health.hull and health.maxHull and health.maxHull > 0 and (health.hull / health.maxHull < ai.intelligence.retreatHealthPercent) then
        ai.state = "retreating"
        return
    end

    if not target then
        ai.state = "idle"
        return
    end

    if not target.components or not target.components.position then
        return
    end
    local ex, ey = entity.components.position.x, entity.components.position.y
    local px, py = target.components.position.x, target.components.position.y
    local dist = Util.distance(ex, ey, px, py)
    
    if ai.state == "retreating" and dist > SAFE_DISTANCE then
        ai.state = "idle" -- Cooldown before re-engaging
        return
    end

    ai.evadeTimer = (ai.evadeTimer or 0) - dt
    if ai.state == "hunting" and ai.evadeTimer <= 0 and math.random() < 0.2 then
        ai.state = "evading"
        ai.evadeTimer = 1 + math.random() * 1.5 -- Evade for a short duration
        ai.evadeDir = nil -- Reset evade direction
        return
    end
    
    if ai.state == "evading" and ai.evadeTimer <= 0 then
        ai.state = "hunting"
        return
    end

    local maxWeaponRange = 0
    if entity.components.equipment and entity.components.equipment.turrets then
        local turrets = entity.components.equipment.turrets
        if turrets and #turrets > 0 and turrets[1] and turrets[1].turret then
            local primaryTurret = turrets[1].turret
            maxWeaponRange = (primaryTurret.optimal or 0) + (primaryTurret.falloff or 0)
        end
    end
    
    if dist < maxWeaponRange + ENGAGE_RANGE_BUFFER and AIComponent.isAggressive(ai) then
        if ai.state ~= "evading" then
            ai.state = "hunting"
        end
    elseif ai.state ~= "retreating" then
        ai.state = "idle"
    end
end

function AISystem.update(dt, world, spawnProjectile)
    for _, entity in ipairs(world:get_entities_with_components("ai", "position", "velocity", "equipment")) do
        local ai = entity.components.ai
        
        -- Energy regeneration and debug
        if entity.components.health and entity.components.health.maxEnergy > 0 then
            local baseRegen = entity.energyRegen or 35
            local oldEnergy = entity.components.health.energy
            entity.components.health.energy = math.min(
                entity.components.health.maxEnergy,
                entity.components.health.energy + (baseRegen * dt)
            )
            
            -- Debug: Log energy changes
            if math.floor(oldEnergy) ~= math.floor(entity.components.health.energy) then
                print(string.format("Energy: %.1f -> %.1f (regen: %.1f/s)", 
                    oldEnergy, entity.components.health.energy, baseRegen))
            end
        end

        -- Core logic updates
        if not ai.target or ai.target.isDestroyed then
            ai.target = findTarget(entity, world)
        end
        updateState(entity, dt)

        -- Execute state-specific behavior
        if ai.state == "idle" then
            handleIdleState(entity, dt)
        elseif ai.state == "hunting" then
            handleHuntingState(entity, dt, world, spawnProjectile)
        elseif ai.state == "evading" then
            handleEvadingState(entity, dt)
        elseif ai.state == "retreating" then
            handleRetreatingState(entity, dt)
        end
    end
end

return AISystem