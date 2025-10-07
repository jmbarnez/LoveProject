local EffectRegistry = require("src.systems.projectile.effect_registry")
local Events = require("src.systems.projectile.event_dispatcher").EVENTS

local function factory(context, config)
    local projectile = context.projectile
    local explosionConfig = config.value or {}
    
    local explosionRadius = explosionConfig.explosion_radius or 80
    local shrapnelCount = explosionConfig.shrapnel_count or 12
    local shrapnelSpread = explosionConfig.shrapnel_spread or math.pi * 0.6
    local shrapnelSpeed = explosionConfig.shrapnel_speed or 600
    local shrapnelDamage = explosionConfig.shrapnel_damage or 8
    local explosionDamage = explosionConfig.explosion_damage or 25
    local explosionDelay = explosionConfig.explosion_delay or 0.1
    
    local hasExploded = false
    local explosionTimer = 0
    
    -- Store the original target position when the bomb was fired
    local targetX, targetY = nil, nil
    local targetAngle = nil
    local world = nil
    
    local events = {}
    
    -- Capture target position when bomb is created
    events[Events.SPAWN] = function(payload)
        print("Bomb explosion effect created!")
        
        -- Store world reference from payload
        world = payload.world
        print("World available:", world ~= nil)
        
        -- Try to get target position from the projectile's bullet component
        local bullet = projectile.components.bullet
        if bullet and bullet.targetX and bullet.targetY then
            targetX = bullet.targetX
            targetY = bullet.targetY
            targetAngle = bullet.targetAngle
            print("Target position from bullet component:", targetX, targetY, "angle:", targetAngle)
        else
            -- Fallback: calculate target position from projectile's initial velocity
            local pos = projectile.components.position
            local vel = projectile.components.velocity
            if pos and vel then
                -- Estimate target position based on initial trajectory
                local speed = math.sqrt(vel.x * vel.x + vel.y * vel.y)
                local lifetime = projectile.components.timed_life and projectile.components.timed_life.life or 3.0
                local travelDistance = speed * lifetime
                
                targetX = pos.x + math.cos(pos.angle) * travelDistance
                targetY = pos.y + math.sin(pos.angle) * travelDistance
                targetAngle = pos.angle
                print("Target position calculated from trajectory:", targetX, targetY)
            end
        end
    end
    
    events[Events.UPDATE] = function(payload)
        local dt = (payload and payload.dt) or 0
        if dt < 0 then dt = 0 end
        
        if not hasExploded and targetX and targetY then
            -- Check if bomb has reached target position
            local pos = projectile.components.position
            if pos then
                local dx = pos.x - targetX
                local dy = pos.y - targetY
                local distance = math.sqrt(dx * dx + dy * dy)
                
                -- Explode when close to target (within 20 units)
                if distance <= 20 then
                    print("Bomb reached target position! Exploding at distance:", distance)
                    explode()
                    hasExploded = true
                else
                    -- Debug: show progress every 30 frames (roughly every 0.5 seconds at 60fps)
                    if math.floor(explosionTimer * 60) % 30 == 0 then
                        print("Bomb traveling to target. Distance:", math.floor(distance), "Current:", math.floor(pos.x), math.floor(pos.y), "Target:", math.floor(targetX), math.floor(targetY))
                    end
                end
            end
        end
        
        -- Fallback: explode after delay if target position not available
        if not hasExploded and not (targetX and targetY) then
            explosionTimer = explosionTimer + dt
            if explosionTimer >= explosionDelay then
                print("Bomb exploding after delay (no target position)!")
                explode()
                hasExploded = true
            end
        end
    end
    
    events[Events.HIT] = function(payload)
        if not hasExploded then
            print("Bomb exploding on hit!")
            explode()
            hasExploded = true
        end
    end
    
    events[Events.EXPIRE] = function(payload)
        if not hasExploded then
            print("Bomb exploding on expire!")
            explode()
            hasExploded = true
        end
    end
    
    function explode()
        -- Use stored target position if available, otherwise use current position
        local x, y, angle
        if targetX and targetY then
            x, y = targetX, targetY
            angle = targetAngle or 0
            print("Exploding at TARGET position:", x, y, "angle:", angle)
        else
            local pos = projectile.components.position
            if not pos then return end
            x, y = pos.x, pos.y
            angle = pos.angle or 0
            print("Exploding at CURRENT position:", x, y, "angle:", angle)
        end
        
        -- Create explosion effect
        local Effects = require("src.systems.effects")
        if Effects and Effects.spawnExplosion then
            Effects.spawnExplosion(x, y, explosionRadius, explosionDamage)
        end
        
        -- Spawn shrapnel cone
        local baseAngle = angle - shrapnelSpread / 2
        local angleStep = shrapnelSpread / (shrapnelCount - 1)
        
        -- Use stored world reference
        if not world or not world.spawn_projectile then
            print("No world available for shrapnel spawning!")
            return -- Can't spawn shrapnel without world
        end
        
        for i = 1, shrapnelCount do
            local shrapnelAngle = baseAngle + (i - 1) * angleStep
            local vx = math.cos(shrapnelAngle) * shrapnelSpeed
            local vy = math.sin(shrapnelAngle) * shrapnelSpeed
            
            -- Create shrapnel projectile using world.spawn_projectile
            local shrapnelDefinition = {
                id = "shrapnel_fragment",
                name = "Shrapnel Fragment",
                class = "Projectile",
                physics = {
                    speed = shrapnelSpeed,
                    drag = 0.1,
                },
                renderable = {
                    type = "bullet",
                    props = {
                        kind = "fragmentation",
                        radius = 2,
                        color = {0.9, 0.7, 0.4, 1.0},
                        streak = {
                            length = 8,
                            width = 1,
                            color = {1.0, 0.8, 0.5, 0.6}
                        }
                    }
                },
                collidable = {
                    radius = 2,
                },
                damage = {
                    value = shrapnelDamage,
                },
                timed_life = {
                    duration = 1.0,
                }
            }
            
            local friendly = projectile.components.bullet and projectile.components.bullet.source and projectile.components.bullet.source.isPlayer
            world.spawn_projectile(x, y, shrapnelAngle, friendly, {
                projectile = "shrapnel_fragment",
                vx = vx,
                vy = vy,
                source = projectile.components.bullet and projectile.components.bullet.source,
                damage = { min = shrapnelDamage, max = shrapnelDamage },
                definition = shrapnelDefinition,
            })
        end
        
        -- Destroy the bomb projectile
        projectile.dead = true
    end
    
    return {
        events = events,
    }
end

EffectRegistry.register("bomb_explosion", factory)

return true
