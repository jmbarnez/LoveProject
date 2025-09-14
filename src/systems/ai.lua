local Util = require("src.core.util")
local AIComponent = require("src.components.ai")
local Sound = require("src.core.sound")

local AISystem = {}

function AISystem.update(dt, world, spawnProjectile)
        for _, entity in ipairs(world:getEntitiesWithComponents("ai", "position", "velocity", "equipment")) do
        local ex, ey = entity.components.position.x, entity.components.position.y

        -- Find the closest enemy (for now, the player)
        local players = world:getEntitiesWithComponents("player")
        if #players == 0 then return end
        local player = players[1]

        local px, py = player.components.position.x, player.components.position.y
        local dist = Util.distance(ex, ey, px, py)


        -- Simple aggro system based on weapon range
        local ai = entity.components.ai
        
        -- Fast energy regeneration for aggressive combat
        if entity.components.health and entity.components.health.maxEnergy > 0 then
            local regenRate = entity.energyRegen or 35  -- Default faster regen for enemies
            entity.components.health.energy = math.min(
                entity.components.health.maxEnergy, 
                entity.components.health.energy + regenRate * dt
            )
        end
        
        -- Calculate detection range based on weapon max range
        local turrets = entity.components.equipment.turrets
        local primaryTurret = (turrets and #turrets > 0) and turrets[1].turret or nil
        local optimal = (primaryTurret and primaryTurret.optimal) or 380
        local falloff = (primaryTurret and primaryTurret.falloff) or 260
        local maxWeaponRange = optimal + falloff
        local detectionRange = maxWeaponRange -- Detection range = max attack range
        
        -- Enhanced detection and targeting logic
        local shouldHunt = false
        -- Check if in range and aggressive
        if dist < detectionRange and AIComponent.isAggressive(ai) then
            shouldHunt = true
            -- Additional check for line of sight or other conditions could go here
        end
        
        -- State transition with proper sound and targeting
        if shouldHunt then
            if not ai.targeting then
                if Sound and Sound.triggerEvent then
                    if Sound and Sound.triggerEvent then
                        if entity and entity.components and entity.components.position then
                            Sound.triggerEvent("enemy_lock_on", entity.components.position.x, entity.components.position.y)
                        else
                            Sound.triggerEvent("enemy_lock_on")
                        end
                    end
                end
                -- Notify entity of targeting if it has the method
                if entity.onTargeted then
                    entity:onTargeted()
                end
            end
            ai.targeting = true
            ai.state = "hunting"
            ai.target = player
            -- Ensure turrets are enabled when hunting
            if entity.components.equipment and entity.components.equipment.turrets then
                for _, turretData in ipairs(entity.components.equipment.turrets) do
                    turretData.enabled = true
                end
            end
        else
            if ai.targeting then
                -- Was targeting but lost target
                if entity.components.equipment and entity.components.equipment.turrets then
                    for _, turretData in ipairs(entity.components.equipment.turrets) do
                        turretData.enabled = false
                    end
                end
            end
            ai.targeting = false
            ai.state = "idle"
            ai.target = nil
        end

        if ai.state == "hunting" then
            -- Get all other hunting AI for pack coordination
            local allHunters = {}
            for _, other in ipairs(world:getEntitiesWithComponents("ai", "position")) do
                if other ~= entity and other.components.ai.state == "hunting" then
                    table.insert(allHunters, other)
                end
            end
            
            -- Simple combat range from primary turret
            local turrets = entity.components.equipment.turrets
            local primaryTurret = (turrets and #turrets > 0) and turrets[1].turret or nil
            local optimal = (primaryTurret and primaryTurret.optimal) or 380
            local falloff = (primaryTurret and primaryTurret.falloff) or 260
            local desired = optimal * 0.9  -- Stay at optimal range
            local margin = math.max(25, falloff * 0.3)

            -- Simple orbital mechanics
            local hunterId = entity.id or 0
            local toPlayerAngle = Util.angleTo(ex, ey, px, py)
            local dirx, diry = math.cos(toPlayerAngle), math.sin(toPlayerAngle)
            
            entity._aiTime = (entity._aiTime or 0) + dt
            local orbitAngle = toPlayerAngle + math.pi * 0.5
            
            -- Better pack spacing: distribute hunters evenly and add radial offsets
            local pack = {entity}
            for _, other in ipairs(allHunters) do table.insert(pack, other) end
            -- sort deterministically by id to give stable spacing
            table.sort(pack, function(a, b) return (a.id or 0) < (b.id or 0) end)
            local myIndex = 1
            for i, p in ipairs(pack) do if p == entity then myIndex = i break end end
            local packCount = #pack
            local packSpacing = (2 * math.pi) * (myIndex - 1) / math.max(1, packCount)
            orbitAngle = orbitAngle + packSpacing

            -- Apply a small radial offset per-ship so they don't all sit on the exact same radius
            -- Ships near the middle stay close to `desired`, edges step outward slightly
            local mid = (packCount + 1) / 2
            local radialStep = math.max(8, margin * 0.25)
            desired = desired + (myIndex - mid) * radialStep

            local perpx, perpy = math.cos(orbitAngle), math.sin(orbitAngle)
            
            -- Simple movement parameters
            local baseSpeed = 200
            local maxSpeed = 240
            
            -- Simple range correction
            local error = desired - dist
            local correctionRate = 1.2
            local maxRadialSpeed = 180
            local radialSpeed = math.max(-maxRadialSpeed, math.min(maxRadialSpeed, -error * correctionRate))
            local rvx, rvy = dirx * radialSpeed, diry * radialSpeed
            
            local tSpeed = baseSpeed
            
            local tvx, tvy = perpx * tSpeed, perpy * tSpeed
            
            -- Combine movement vectors
            local moveVx = rvx + tvx
            local moveVy = rvy + tvy
            local mag = math.sqrt(moveVx*moveVx + moveVy*moveVy)
            if mag > maxSpeed then
                local s = maxSpeed / mag
                moveVx, moveVy = moveVx * s, moveVy * s
            end

            -- Drive physics body velocity if present; avoid double-writes
            local body = entity.components.physics and entity.components.physics.body
            if body then
                body.vx = moveVx
                body.vy = moveVy
            else
                -- Fallback to ECS velocity when no physics body exists
                entity.components.velocity.x = moveVx
                entity.components.velocity.y = moveVy
            end

            -- Rotate drone to face the player (target)
            local desiredAngle = toPlayerAngle
            local currentAngle = (entity.components.position and entity.components.position.angle) or 0
            local diff = (desiredAngle - currentAngle + math.pi) % (2*math.pi) - math.pi
            local turnRate = 6.0 -- rad/s to match player responsiveness
            local step = math.max(-turnRate * dt, math.min(turnRate * dt, diff))
            local newAngle = currentAngle + step
            -- Write rotation to physics body when present (position sync happens in physics system)
            local body2 = entity.components.physics and entity.components.physics.body
            if body2 then
                body2.angle = newAngle
            else
                if entity.components and entity.components.position then
                    entity.components.position.angle = newAngle
                end
            end

            -- Simple combat AI - fire when in range
            local maxRange = optimal + falloff
            local shouldFire = dist <= maxRange

            -- Simple weapon control - fire at player directly
            for _, turretData in ipairs(entity.components.equipment.turrets) do
                if turretData.turret and turretData.enabled then
                    -- locked parameter should be false when we want to fire
                    local locked = not shouldFire
                    turretData.turret:update(dt, player, locked, world)
                end
            end
        else
            -- Idle: wander behavior
            local ai = entity.components.ai
            ai.wanderTimer = (ai.wanderTimer or 0) - dt
            if (ai.wanderTimer or 0) <= 0 then
                ai.wanderTimer = 1 + math.random() * 2.5
                -- Small random turn with occasional bigger change
                local jitter = (math.random() * 0.6 - 0.3)
                if math.random() < 0.25 then jitter = jitter + (math.random() * math.pi - math.pi/2) * 0.2 end
                ai.wanderDir = ((ai.wanderDir or 0) + jitter) % (2*math.pi)
            end
            local speed = ai.wanderSpeed or 80
            local moveVx = math.cos(ai.wanderDir or 0) * speed
            local moveVy = math.sin(ai.wanderDir or 0) * speed
            local body = entity.components.physics and entity.components.physics.body
            if body then
                body.vx = moveVx
                body.vy = moveVy
            else
                entity.components.velocity.x = moveVx
                entity.components.velocity.y = moveVy
            end
        end
    end
end

return AISystem
