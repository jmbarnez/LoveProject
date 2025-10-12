-- Modular AI system for drones based on weapon modules
-- Drones change behavior based on their equipped weapons

local AISystem = require("src.systems.ai")
local TurretSystem = require("src.systems.turret.system")

local ModularDroneAI = {}

-- Find nearby allies that need healing
local function findInjuredAlly(world, healer)
    local healerPos = healer.components.position
    if not healerPos then return nil end
    
    local bestTarget = nil
    local bestDistance = math.huge
    local healingRange = 1000 -- Range to search for allies (healing laser max range)
    
    -- Get all entities with hull components (potential allies)
    local entities = world:get_entities_with_components("hull", "position")
    
    for _, entity in ipairs(entities) do
        if entity ~= healer and not entity.dead and entity.components.hull then
            local hull = entity.components.hull
            local pos = entity.components.position
            
            -- Check if entity needs healing (hull below max)
            if hull.hp and hull.maxHP and hull.hp < hull.maxHP then
                local dx = pos.x - healerPos.x
                local dy = pos.y - healerPos.y
                local distance = math.sqrt(dx * dx + dy * dy)
                
                if distance <= healingRange and distance < bestDistance then
                    bestTarget = entity
                    bestDistance = distance
                end
            end
        end
    end
    
    return bestTarget, bestDistance
end

-- Find nearby enemies to attack
local function findEnemyTarget(world, attacker)
    local attackerPos = attacker.components.position
    if not attackerPos then return nil end
    
    local bestTarget = nil
    local bestDistance = math.huge
    local attackRange = 600 -- Range to search for enemies
    
    -- Get all entities with AI components (potential enemies)
    local entities = world:get_entities_with_components("ai", "position")
    
    for _, entity in ipairs(entities) do
        if entity ~= attacker and not entity.dead and entity.components.ai then
            local pos = entity.components.position
            local dx = pos.x - attackerPos.x
            local dy = pos.y - attackerPos.y
            local distance = math.sqrt(dx * dx + dy * dy)
            
            if distance <= attackRange and distance < bestDistance then
                bestTarget = entity
                bestDistance = distance
            end
        end
    end
    
    return bestTarget, bestDistance
end

-- Calculate orbit position around a target
local function calculateOrbitPosition(target, drone, orbitRadius, orbitSpeed)
    local targetPos = target.components.position
    local dronePos = drone.components.position
    
    if not targetPos or not dronePos then return nil, nil end
    
    -- Initialize orbit angle if not set
    if not drone.orbitAngle then
        drone.orbitAngle = math.random() * math.pi * 2
    end
    
    -- Update orbit angle
    drone.orbitAngle = drone.orbitAngle + orbitSpeed * 0.016 -- Assuming 60 FPS
    
    -- Calculate orbit position
    local orbitX = targetPos.x + math.cos(drone.orbitAngle) * orbitRadius
    local orbitY = targetPos.y + math.sin(drone.orbitAngle) * orbitRadius
    
    return orbitX, orbitY
end

-- Move towards a target position using physics system
local function moveTowards(entity, targetX, targetY, dt)
    local pos = entity.components.position
    if not pos then return end
    
    local dx = targetX - pos.x
    local dy = targetY - pos.y
    local distance = math.sqrt(dx * dx + dy * dy)
    
    if distance > 5 then -- Only move if not already close
        local ux = dx / distance
        local uy = dy / distance
        
        local physics = entity.components.physics
        if physics and physics.body then
            -- Use the ship's actual thruster power for movement
            local thrustPower = physics.body.thrusterPower and physics.body.thrusterPower.main or 600000
            local mass = physics.body.mass or 500
            
            -- Calculate acceleration using physics system (same as player movement)
            local accel = (thrustPower / mass) * dt * 1.0
            
            -- Apply acceleration to velocity
            local newVx = physics.body.vx + ux * accel
            local newVy = physics.body.vy + uy * accel
            
            -- Apply speed cap using ship's maxSpeed
            local maxSpeed = physics.body.maxSpeed or 300
            local newSpeed = math.sqrt(newVx * newVx + newVy * newVy)
            if newSpeed > maxSpeed then
                local scale = maxSpeed / newSpeed
                newVx, newVy = newVx * scale, newVy * scale
            end
            
            physics.body.vx = newVx
            physics.body.vy = newVy
        end
    end
end

-- Get the primary weapon module from the drone
local function getPrimaryWeapon(drone)
    local equipment = drone.components.equipment
    if not equipment or not equipment.grid then return nil end
    
    for _, slot in ipairs(equipment.grid) do
        if slot and slot.module and slot.type == "turret" and slot.enabled ~= false then
            return slot.module
        end
    end
    
    return nil
end

-- Healing behavior (for healing laser equipped drones)
local function updateHealingBehavior(drone, dt, world)
    local target, distance = findInjuredAlly(world, drone)
    
    if target then
        -- We have a target to heal
        drone.healingTarget = target
        
        -- Calculate orbit position around the target at healing laser optimal range
        local orbitRadius = 800 -- Orbit at healing laser optimal range for maximum effectiveness
        local orbitSpeed = 1.5 -- Orbit speed
        local orbitX, orbitY = calculateOrbitPosition(target, drone, orbitRadius, orbitSpeed)
        
        if orbitX and orbitY then
            -- Check current distance to target
            local dronePos = drone.components.position
            local currentDistance = math.sqrt(
                (dronePos.x - target.components.position.x)^2 + 
                (dronePos.y - target.components.position.y)^2
            )
            
            -- Move towards orbit position using physics system
            moveTowards(drone, orbitX, orbitY, dt)
            
            -- Update turret to aim at the target (only if within optimal range)
            local equipment = drone.components.equipment
            if equipment and equipment.grid and currentDistance <= orbitRadius then
                for _, slot in ipairs(equipment.grid) do
                    if slot and slot.module and slot.type == "turret" and slot.enabled ~= false then
                        local turret = slot.module
                        if turret.kind == "healing_laser" then
                            -- Set turret to fire at the target
                            turret.fireMode = "automatic"
                            turret.autoFire = true
                            
                            -- Update turret to aim at target
                            local TurretSystem = require("src.systems.turret.system")
                            TurretSystem.update(turret, dt, target, false, world)
                        end
                    end
                end
            else
                -- Stop firing if too far away
                if equipment and equipment.grid then
                    for _, slot in ipairs(equipment.grid) do
                        if slot and slot.module and slot.type == "turret" and slot.enabled ~= false then
                            local turret = slot.module
                            if turret.kind == "healing_laser" then
                                turret.autoFire = false
                            end
                        end
                    end
                end
            end
        end
    else
        -- No injured allies found, patrol around
        drone.healingTarget = nil
        
        -- Simple patrol behavior
        if not drone.patrolTarget then
            local pos = drone.components.position
            local angle = math.random() * math.pi * 2
            local radius = 100
            drone.patrolTarget = {
                x = pos.x + math.cos(angle) * radius,
                y = pos.y + math.sin(angle) * radius,
            }
            drone.patrolTimer = 0
        end
        
        drone.patrolTimer = (drone.patrolTimer or 0) + dt
        if drone.patrolTimer > 3 then
            drone.patrolTarget = nil
        end
        
        if drone.patrolTarget then
            moveTowards(drone, drone.patrolTarget.x, drone.patrolTarget.y, dt)
        end
        
        -- Stop healing turrets when no target
        local equipment = drone.components.equipment
        if equipment and equipment.grid then
            for _, slot in ipairs(equipment.grid) do
                if slot and slot.module and slot.type == "turret" and slot.enabled ~= false then
                    local turret = slot.module
                    if turret.kind == "healing_laser" then
                        turret.autoFire = false
                    end
                end
            end
        end
    end
end

-- Combat behavior (for weapon equipped drones)
local function updateCombatBehavior(drone, dt, world)
    local target, distance = findEnemyTarget(world, drone)
    
    if target then
        -- We have a target to attack
        drone.combatTarget = target
        
        -- Move towards target
        local targetPos = target.components.position
        moveTowards(drone, targetPos.x, targetPos.y, dt)
        
        -- Update turrets to aim at target
        local equipment = drone.components.equipment
        if equipment and equipment.grid then
            for _, slot in ipairs(equipment.grid) do
                if slot and slot.module and slot.type == "turret" and slot.enabled ~= false then
                    local turret = slot.module
                    if turret.kind ~= "healing_laser" then -- Don't use healing lasers for combat
                        -- Set turret to fire at the target
                        turret.fireMode = "automatic"
                        turret.autoFire = true
                        
                        -- Update turret to aim at target
                        local TurretSystem = require("src.systems.turret.system")
                        TurretSystem.update(turret, dt, target, false, world)
                    end
                end
            end
        end
    else
        -- No enemies found, patrol around
        drone.combatTarget = nil
        
        -- Simple patrol behavior
        if not drone.patrolTarget then
            local pos = drone.components.position
            local angle = math.random() * math.pi * 2
            local radius = 150
            drone.patrolTarget = {
                x = pos.x + math.cos(angle) * radius,
                y = pos.y + math.sin(angle) * radius,
            }
            drone.patrolTimer = 0
        end
        
        drone.patrolTimer = (drone.patrolTimer or 0) + dt
        if drone.patrolTimer > 5 then
            drone.patrolTarget = nil
        end
        
        if drone.patrolTarget then
            moveTowards(drone, drone.patrolTarget.x, drone.patrolTarget.y, dt)
        end
        
        -- Stop combat turrets when no target
        local equipment = drone.components.equipment
        if equipment and equipment.grid then
            for _, slot in ipairs(equipment.grid) do
                if slot and slot.module and slot.type == "turret" and slot.enabled ~= false then
                    local turret = slot.module
                    if turret.kind ~= "healing_laser" then
                        turret.autoFire = false
                    end
                end
            end
        end
    end
end

-- Main update function - determines behavior based on weapon modules
function ModularDroneAI.update(drone, dt, world)
    if not drone.components.position or drone.dead then
        return
    end
    
    local ai = drone.components.ai
    if not ai then return end
    
    -- Get the primary weapon module
    local primaryWeapon = getPrimaryWeapon(drone)
    
    if primaryWeapon then
        if primaryWeapon.kind == "healing_laser" then
            -- Healing behavior
            updateHealingBehavior(drone, dt, world)
        else
            -- Combat behavior for all other weapons
            updateCombatBehavior(drone, dt, world)
        end
    else
        -- No weapon equipped, use default combat behavior
        updateCombatBehavior(drone, dt, world)
    end
end

return ModularDroneAI
