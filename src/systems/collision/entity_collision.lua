local Constants = require("src.core.constants")
local Config = require("src.content.config")
local Effects = require("src.systems.effects")
local Radius = require("src.systems.collision.radius")
local Geometry = require("src.systems.collision.geometry")
local StationShields = require("src.systems.collision.station_shields")
local CollisionEffects = require("src.systems.collision.effects")

--- EntityCollision resolves entity-to-entity overlap, applying physical
--- pushes, shield handling, and impact effects.
local EntityCollision = {}

local combatOverrides = Config.COMBAT or {}
local combatConstants = Constants.COMBAT

local function getCombatValue(key)
    local value = combatOverrides[key]
    if value ~= nil then return value end
    return combatConstants[key]
end

local function worldPolygon(entity)
    local collidable = entity.components and entity.components.collidable
    if not collidable or collidable.shape ~= "polygon" or not collidable.vertices then
        return nil
    end

    local pos = entity.components.position
    local angle = (pos and pos.angle) or 0
    return Geometry.transformPolygon(pos.x, pos.y, angle, collidable.vertices)
end

-- Get the collision radius for an entity, properly handling polygon shapes
local function getEntityCollisionRadius(entity)
    local collidable = entity.components and entity.components.collidable
    if not collidable then
        return 0
    end
    
    -- For polygon shapes, calculate radius from vertices only (not visual elements)
    if collidable.shape == "polygon" and collidable.vertices then
        local maxRadius = 0
        for i = 1, #collidable.vertices, 2 do
            local vx = collidable.vertices[i] or 0
            local vy = collidable.vertices[i + 1] or 0
            local distance = math.sqrt(vx * vx + vy * vy)
            if distance > maxRadius then
                maxRadius = distance
            end
        end
        return maxRadius
    end
    
    -- For circular shapes, use the radius directly
    if collidable.radius and collidable.radius > 0 then
        return collidable.radius
    end
    
    -- Fallback to hull radius for other entities
    return Radius.getHullRadius(entity)
end

local function getCollisionShape(entity)
    local pos = entity.components.position

    -- Shields are always circular by design
    if StationShields.hasActiveShield(entity) then
        return {
            type = "circle",
            x = pos.x,
            y = pos.y,
            radius = Radius.getShieldRadius(entity)
        }
    end

    -- Check for polygon collision shape first (primary method)
    local collidable = entity.components and entity.components.collidable
    if collidable and collidable.shape == "polygon" and collidable.vertices then
        local pos = entity.components.position
        local angle = (pos and pos.angle) or 0
        local verts = Geometry.transformPolygon(pos.x, pos.y, angle, collidable.vertices)
        if verts and #verts >= 6 then  -- Ensure we have at least 3 vertices (6 coordinates)
            return { type = "polygon", vertices = verts }
        end
    end

    -- Only use circular collision for truly circular objects
    -- This includes: projectiles, small circular items, and objects explicitly marked as circular
    if collidable and collidable.shape == "circle" and collidable.radius then
        return {
            type = "circle",
            x = pos.x,
            y = pos.y,
            radius = collidable.radius
        }
    end

    -- For stations, only use polygon shapes - no circular fallback
    if entity.tag == "station" or (entity.components and entity.components.station) then
        -- Stations must have polygon collision shapes - no circular fallback
        -- If no polygon shape is available, return nil (no collision)
        return nil
    end

    -- For ships and other entities, require polygon collision shapes
    -- No more circular fallback - entities must define proper polygon shapes
    if entity.tag == "ship" or entity.tag == "enemy" or entity.tag == "asteroid" or 
       (entity.components and (entity.components.ship or entity.components.enemy or entity.components.mineable or entity.components.wreckage)) then
        -- These entities must have polygon collision shapes defined
        return nil
    end

    -- Only allow circular collision for projectiles and items that are explicitly circular
    if entity.components and entity.components.bullet then
        -- Projectiles can use circular collision
        return {
            type = "circle",
            x = pos.x,
            y = pos.y,
            radius = Radius.getHullRadius(entity)
        }
    end

    -- For all other entities without proper collision shapes, return nil (no collision)
    return nil
end

local function checkEntityCollision(entity1, entity2)
    local shape1 = getCollisionShape(entity1)
    local shape2 = getCollisionShape(entity2)

    if not shape1 or not shape2 then
        return false
    end

    -- Enhanced collision detection for more precision
    if shape1.type == "polygon" and shape2.type == "polygon" then
        local collided, overlap, nx, ny = Geometry.polygonPolygonMTV(shape1.vertices, shape2.vertices)
        if not collided then
            return false
        end
        return true, { overlap = overlap, normalX = nx, normalY = ny, shape1 = shape1, shape2 = shape2 }
    elseif shape1.type == "polygon" and shape2.type == "circle" then
        local collided, overlap, nx, ny = Geometry.polygonCircleMTV(shape1.vertices, shape2.x, shape2.y, shape2.radius)
        if not collided then
            return false
        end
        return true, { overlap = overlap, normalX = nx, normalY = ny, shape1 = shape1, shape2 = shape2 }
    elseif shape1.type == "circle" and shape2.type == "polygon" then
        local collided, overlap, nx, ny = Geometry.polygonCircleMTV(shape2.vertices, shape1.x, shape1.y, shape1.radius)
        if not collided then
            return false
        end
        return true, { overlap = overlap, normalX = -nx, normalY = -ny, shape1 = shape1, shape2 = shape2 }
    else
        local dx = shape2.x - shape1.x
        local dy = shape2.y - shape1.y
        local distanceSq = dx * dx + dy * dy
        local minDistance = shape1.radius + shape2.radius
        
        -- Use more precise collision detection for circular shapes
        if distanceSq < (minDistance * minDistance) then
            local distance = math.sqrt(distanceSq)
            local nx, ny
            if distance > 0.001 then  -- More precise threshold to avoid division by very small numbers
                nx = dx / distance  -- Normal points from shape1 to shape2 (entity1 to entity2)
                ny = dy / distance
            else
                nx, ny = 1, 0  -- Default normal when entities are at same position
                distance = 0  -- Don't override distance, keep it 0 for proper overlap calculation
            end
            return true, { overlap = (minDistance - distance), normalX = nx, normalY = ny, shape1 = shape1, shape2 = shape2 }
        end
        return false
    end
end

-- Helper function to get entity mass for momentum calculations
local function getEntityMass(entity)
    local physics = entity.components.physics
    if physics and physics.body then
        return physics.body.mass or 1000
    end
    -- Fallback mass based on entity type
    if entity.components.mineable then
        return 2000 -- Asteroids are heavy
    elseif entity.tag == "station" then
        return 10000 -- Stations are very heavy
    else
        return 1000 -- Default ship mass
    end
end

-- Helper function to get surface friction for an entity
local function getSurfaceFriction(entity)
    local collidable = entity.components and entity.components.collidable
    if collidable and collidable.friction then
        return collidable.friction
    end
    
    -- Default friction based on entity type
    if entity.tag == "station" then
        return 0.3 -- Smooth metal surfaces
    elseif entity.components.mineable then
        return 0.6 -- Rough asteroid surfaces
    elseif entity.components.shield then
        return 0.0 -- Energy shields have no friction
    else
        return 0.4 -- Default ship hull friction
    end
end

-- Helper function to apply surface friction
local function applySurfaceFriction(entity, normalX, normalY, dt)
    local friction = getSurfaceFriction(entity)
    if friction <= 0 then return end -- No friction to apply
    
    local physics = entity.components.physics
    if physics and physics.body then
        local body = physics.body
        local vx = body.vx or 0
        local vy = body.vy or 0
        local speed = math.sqrt(vx * vx + vy * vy)
        
        if speed > 0.1 then
            -- Calculate friction force opposite to velocity
            local frictionForce = speed * friction * 0.1 -- Scale down for gameplay
            local frictionX = -(vx / speed) * frictionForce
            local frictionY = -(vy / speed) * frictionForce
            
            -- Apply friction
            body.vx = body.vx + frictionX * dt
            body.vy = body.vy + frictionY * dt
        end
    else
        local vel = entity.components.velocity
        if vel then
            local vx = vel.x or 0
            local vy = vel.y or 0
            local speed = math.sqrt(vx * vx + vy * vy)
            
            if speed > 0.1 then
                -- Calculate friction force opposite to velocity
                local frictionForce = speed * friction * 0.1 -- Scale down for gameplay
                local frictionX = -(vx / speed) * frictionForce
                local frictionY = -(vy / speed) * frictionForce
                
                -- Apply friction
                vel.x = vel.x + frictionX * dt
                vel.y = vel.y + frictionY * dt
            end
        end
    end
end

-- Helper function to push an entity with momentum preservation
local function pushEntity(entity, pushX, pushY, normalX, normalY, dt, restitution)
    restitution = restitution or 0.25 -- default hull bounce if unspecified
    local physics = entity.components.physics
    if physics and physics.body then
        local body = physics.body
        body.x = (body.x or entity.components.position.x) + pushX
        body.y = (body.y or entity.components.position.y) + pushY

        local vx = body.vx or 0
        local vy = body.vy or 0
        local vn = vx * normalX + vy * normalY
        if vn < 0 then
            local delta = -(1 + restitution) * vn
            body.vx = vx + delta * normalX
            body.vy = vy + delta * normalY
            
            -- Apply minimal damping to prevent infinite bouncing
            body.vx = body.vx * 0.998
            body.vy = body.vy * 0.998
            
            -- Only apply minimum velocity boost for high restitution objects (shields)
            if restitution > 0.8 then
                local newVn = body.vx * normalX + body.vy * normalY
                local minOut = 40 -- Reduced from 60 for more realistic physics
                if newVn < minOut then
                    local add = (minOut - newVn)
                    body.vx = body.vx + add * normalX
                    body.vy = body.vy + add * normalY
                end
            end
        end
    else
        entity.components.position.x = entity.components.position.x + pushX
        entity.components.position.y = entity.components.position.y + pushY

        local vel = entity.components.velocity
        if vel then
            local vx = vel.x or 0
            local vy = vel.y or 0
            local vn = vx * normalX + vy * normalY
            if vn < 0 then
                local delta = -(1 + restitution) * vn
                vel.x = vx + delta * normalX
                vel.y = vy + delta * normalY
                
                -- Apply minimal damping to prevent infinite bouncing
                vel.x = vel.x * 0.998
                vel.y = vel.y * 0.998
                
                -- Only apply minimum velocity boost for high restitution objects (shields)
                if restitution > 0.8 then
                    local newVn = vel.x * normalX + vel.y * normalY
                    local minOut = 40 -- Reduced from 60 for more realistic physics
                    if newVn < minOut then
                        local add = (minOut - newVn)
                        vel.x = vel.x + add * normalX
                        vel.y = vel.y + add * normalY
                    end
                end
            end
        end
    end
end

-- Resolve collision between two entities
function EntityCollision.resolveEntityCollision(entity1, entity2, dt, collision)
    local e1x = entity1.components.position.x
    local e1y = entity1.components.position.y
    local e2x = entity2.components.position.x
    local e2y = entity2.components.position.y

    if not collision then
        return
    end

    local overlap = collision.overlap or 0
    if overlap <= 0 then
        return
    end

    local nx = collision.normalX or 0
    local ny = collision.normalY or 0
    if nx == 0 and ny == 0 then
        local dx = e1x - e2x
        local dy = e1y - e2y
        local d = math.sqrt(dx * dx + dy * dy)
        if d < 0.1 then
            nx, ny = 1, 0
        else
            nx, ny = dx / d, dy / d
        end
    end

    if overlap > 0 then
        -- Check for station shield special handling
        if StationShields.handleStationShieldCollision(entity1, entity2) then
            -- Create explosion effects immediately
            local ex = (entity1.isEnemy and entity1 or entity2).components.position.x
            local ey = (entity1.isEnemy and entity1 or entity2).components.position.y
            if Effects and Effects.spawnSonicBoom then
                local enemy = entity1.isEnemy and entity1 or entity2
                local col = enemy.components.collidable
                local shipRadius = (col and col.radius) or 15
                local sizeScale = math.max(0.3, math.min(2.0, shipRadius / 15))
                Effects.spawnSonicBoom(ex, ey, { color = {1.0, 0.75, 0.25, 0.5}, sizeScale = sizeScale })
            end
            return -- Skip normal collision resolution
        end

        -- Handle asteroid-to-asteroid collisions with bouncing
        local e1IsAsteroid = entity1.components.mineable and entity1.components.collidable
        local e2IsAsteroid = entity2.components.mineable and entity2.components.collidable
        if e1IsAsteroid and e2IsAsteroid then
            -- Both are asteroids - use physics body collision for bouncing
            local e1Physics = entity1.components.physics and entity1.components.physics.body
            local e2Physics = entity2.components.physics and entity2.components.physics.body
            
            if e1Physics and e2Physics then
                -- Calculate relative velocity for realistic sound scaling
                local v1x, v1y = e1Physics.vx or 0, e1Physics.vy or 0
                local v2x, v2y = e2Physics.vx or 0, e2Physics.vy or 0
                local relativeVelX = v1x - v2x
                local relativeVelY = v1y - v2y
                local relativeSpeed = math.sqrt(relativeVelX * relativeVelX + relativeVelY * relativeVelY)
                
                -- Only play sound for significant impacts (speed > 50 units/sec)
                -- and implement cooldown to prevent spam
                local currentTime = love.timer.getTime()
                local lastCollisionTime = (entity1._lastAsteroidCollision or 0) + (entity2._lastAsteroidCollision or 0)
                local timeSinceLastCollision = currentTime - (lastCollisionTime / 2)
                
                if relativeSpeed > 50 and timeSinceLastCollision > 0.5 then
                    local Sound = require("src.core.sound")
                    local impactX = (e1x + e2x) / 2
                    local impactY = (e1y + e2y) / 2
                    
                    -- Scale volume based on impact speed (0.1 to 0.8 range)
                    local volumeScale = math.min(0.8, math.max(0.1, relativeSpeed / 200))
                    Sound.triggerEventAt('impact_rock', impactX, impactY, volumeScale)
                    
                    -- Update collision timestamps
                    entity1._lastAsteroidCollision = currentTime
                    entity2._lastAsteroidCollision = currentTime
                end
                
                -- Use the physics body collision method for realistic bouncing
                e1Physics:collideWith(e2Physics, 0.6) -- 60% restitution for asteroid bouncing
                return -- Skip normal collision resolution
            end
        end

        -- Determine which entities can move (have physics bodies or are movable)
        local e1Physics = entity1.components.physics and entity1.components.physics.body
        local e2Physics = entity2.components.physics and entity2.components.physics.body
        local e1Wreckage = entity1.components.wreckage ~= nil
        local e2Wreckage = entity2.components.wreckage ~= nil

        local e1CanMove = e1Physics or (entity1.isPlayer or entity1.components.player or entity1.components.ai) or e1Wreckage
        local e2CanMove = e2Physics or (entity2.isPlayer or entity2.components.player or entity2.components.ai) or e2Wreckage

        -- Increase push distance for station collisions to prevent getting stuck inside
        local isStationCollision = (entity1.tag == "station" or entity2.tag == "station") or 
                                   (entity1.components and entity1.components.station) or 
                                   (entity2.components and entity2.components.station)
        
        -- More precise collision resolution for polygon shapes
        local e1HasPolygon = entity1.components and entity1.components.collidable and 
                            entity1.components.collidable.shape == "polygon"
        local e2HasPolygon = entity2.components and entity2.components.collidable and 
                            entity2.components.collidable.shape == "polygon"
        
        local pushDistance
        if e1HasPolygon or e2HasPolygon then
            -- For polygon collisions, use more precise push distance
            pushDistance = overlap * (isStationCollision and 0.9 or 0.7) -- More precise for polygon shapes
        else
            pushDistance = overlap * (isStationCollision and 0.8 or 0.55) -- Standard push for circular shapes
        end
        
        -- Ensure minimum push distance for station collisions
        if isStationCollision then
            pushDistance = math.max(pushDistance, 5) -- Minimum 5 pixel push for stations
        end

        -- Choose restitution based on shields (make shields bouncier)
        local HULL_REST = getCombatValue("HULL_RESTITUTION") or 0.28
        local SHIELD_REST = getCombatValue("SHIELD_RESTITUTION") or 0.88
        local e1Rest = StationShields.hasActiveShield(entity1) and SHIELD_REST or HULL_REST
        local e2Rest = StationShields.hasActiveShield(entity2) and SHIELD_REST or HULL_REST

        -- Enhanced momentum-based collision resolution
        if e1CanMove and e2CanMove then
            -- Both entities can move - use proper momentum transfer
            local mass1 = getEntityMass(entity1)
            local mass2 = getEntityMass(entity2)
            local totalMass = mass1 + mass2
            
            -- Calculate momentum-based push distances
            local push1 = pushDistance * (mass2 / totalMass)
            local push2 = pushDistance * (mass1 / totalMass)
            
            -- Apply separation with momentum preservation
            pushEntity(entity1, -nx * push1, -ny * push1, -nx, -ny, dt, e1Rest)
            pushEntity(entity2, nx * push2, ny * push2, nx, ny, dt, e2Rest)
            
            -- Apply momentum transfer between moving entities
            local e1Physics = entity1.components.physics and entity1.components.physics.body
            local e2Physics = entity2.components.physics and entity2.components.physics.body
            
            if e1Physics and e2Physics then
                -- Calculate relative velocity
                local relVx = e2Physics.vx - e1Physics.vx
                local relVy = e2Physics.vy - e1Physics.vy
                local relVelAlongNormal = relVx * nx + relVy * ny
                
                -- Don't resolve if velocities are separating
                if relVelAlongNormal < 0 then
                    -- Calculate impulse magnitude
                    local impulse = -(1 + math.min(e1Rest, e2Rest)) * relVelAlongNormal
                    impulse = impulse / (1/mass1 + 1/mass2)
                    
                    -- Apply impulse
                    local impulseX = impulse * nx
                    local impulseY = impulse * ny
                    
                    e1Physics.vx = e1Physics.vx - impulseX / mass1
                    e1Physics.vy = e1Physics.vy - impulseY / mass1
                    e2Physics.vx = e2Physics.vx + impulseX / mass2
                    e2Physics.vy = e2Physics.vy + impulseY / mass2
                end
            end
            
            -- Apply surface friction after collision
            applySurfaceFriction(entity1, -nx, -ny, dt)
            applySurfaceFriction(entity2, nx, ny, dt)
        elseif e1CanMove then
            -- Only entity1 can move - push it away from static entity2
            pushEntity(entity1, -nx * overlap, -ny * overlap, -nx, -ny, dt, e1Rest)
            -- Apply friction from static surface
            applySurfaceFriction(entity1, -nx, -ny, dt)
        elseif e2CanMove then
            -- Only entity2 can move - push it away from static entity1
            pushEntity(entity2, nx * overlap, ny * overlap, nx, ny, dt, e2Rest)
            -- Apply friction from static surface
            applySurfaceFriction(entity2, nx, ny, dt)
        end

        -- Enhanced momentum transfer: allow ships to push wreckage pieces around
        local player, debris = nil, nil
        if entity1.isPlayer and e2Physics then
            player, debris = entity1, entity2
        elseif entity2.isPlayer and e1Physics then
            player, debris = entity2, entity1
        end

        if player and debris and debris.components.physics and debris.components.physics.body then
            local playerBody = player.components.physics and player.components.physics.body
            local debrisBody = debris.components.physics.body
            if playerBody and playerBody.vx and playerBody.vy then
                -- Get player velocity
                local playerVx, playerVy = playerBody.vx, playerBody.vy
                local playerSpeed = math.sqrt(playerVx * playerVx + playerVy * playerVy)
                
                -- Apply momentum even at low speeds for better responsiveness
                if playerSpeed > 0.5 then
                    -- Calculate collision normal for directional pushing
                    local normalX = nx or 0
                    local normalY = ny or 0
                    
                    -- Calculate velocity component along collision normal
                    local velocityAlongNormal = playerVx * normalX + playerVy * normalY
                    
                    -- Apply momentum transfer in the direction of player movement
                    -- Use a more aggressive approach for better pushing
                    local baseTransfer = 1.2 -- Increased for more responsive pushing
                    
                    -- Scale by collision overlap for more realistic physics
                    local overlapFactor = math.min(1.0, (overlap or 0) / 2.0)
                    
                    -- Scale by player speed for more dynamic pushing
                    local speedFactor = math.min(2.5, playerSpeed / 30.0)
                    
                    -- Mass ratio consideration (heavier debris is harder to push)
                    local playerMass = playerBody.mass or 500
                    local debrisMass = debrisBody.mass or 60
                    local massRatio = playerMass / debrisMass
                    local massFactor = math.min(2.0, massRatio / 1.5)
                    
                    -- Calculate final transfer rate
                    local finalTransfer = baseTransfer * overlapFactor * speedFactor * massFactor
                    
                    -- Apply momentum transfer in the direction of player movement
                    debrisBody.vx = (debrisBody.vx or 0) + playerVx * finalTransfer
                    debrisBody.vy = (debrisBody.vy or 0) + playerVy * finalTransfer
                    
                    -- Apply slight resistance to player movement (realistic physics)
                    local playerResistance = finalTransfer * 0.05 -- Reduced resistance for smoother pushing
                    playerBody.vx = playerBody.vx * (1 - playerResistance)
                    playerBody.vy = playerBody.vy * (1 - playerResistance)
                    
                    -- Add some angular momentum to make debris spin when pushed
                    local angularTransfer = finalTransfer * 0.3
                    debrisBody.angularVel = (debrisBody.angularVel or 0) + (playerVx - playerVy) * angularTransfer * 0.01
                end
            end
        end

        -- Throttle collision FX to avoid spamming when resting against geometry
        local now = (love and love.timer and love.timer.getTime and love.timer.getTime()) or 0
        if CollisionEffects.canEmitCollisionFX(entity1, entity2, now) then
            -- Create visual effects for both entities
            local e1Radius = getEntityCollisionRadius(entity1)
            local e2Radius = getEntityCollisionRadius(entity2)
            CollisionEffects.createCollisionEffects(entity1, entity2, e1x, e1y, e2x, e2y, nx, ny, e1Radius, e2Radius)
        end
    end
end

-- Handle universal entity-to-entity collisions
function EntityCollision.handleEntityCollisions(collisionSystem, entity, world, dt)
    if not entity or not entity.components.position or not entity.components.collidable or entity.dead then
        return
    end

    if entity._collisionGrace then
        entity._collisionGrace = math.max(0, entity._collisionGrace - (dt or 0))
        if entity._collisionGrace > 0 then
            return
        else
            entity._collisionGrace = nil
        end
    end

    -- Projectiles now use unified collision system

    local ex = entity.components.position.x
    local ey = entity.components.position.y

    -- Use effective radius for quadtree query (accounts for shields)
    local radius_cache = collisionSystem and collisionSystem.radius_cache
    local entityRadius = radius_cache and radius_cache:getEffectiveRadius(entity)
        or Radius.calculateEffectiveRadius(entity)

    -- Get potential collision targets from quadtree
    local candidates = collisionSystem.quadtree:query({
        x = ex - entityRadius,
        y = ey - entityRadius,
        width = entityRadius * 2,
        height = entityRadius * 2
    })

    for _, candidate in ipairs(candidates) do
        local other = candidate.entity
        if other ~= entity and not other.dead and other.components.collidable and other.components.position then
            -- Projectiles now use unified collision system

            if other._collisionGrace and other._collisionGrace > 0 then
                goto continue
            end

            -- Skip friendly vs station shield collisions (allow friendlies inside station bubble)
            if StationShields.shouldIgnoreEntityCollision(entity, other) then
                goto continue
            end

            -- Ignore collisions between the player and warp gates (stations now have physical hulls)
            do
                local eIsPlayer = entity.isPlayer or (entity.components and entity.components.player)
                local oIsPlayer = other.isPlayer or (other.components and other.components.player)
                local eIsWarpGate = entity.tag == "warp_gate"
                local oIsWarpGate = other.tag == "warp_gate"
                if (eIsPlayer and oIsWarpGate) or (oIsPlayer and eIsWarpGate) then
                    goto continue
                end
            end

            -- Check for collision
            if entity.components.bullet then
                -- Use projectile-specific collision detection for bullets
                if EntityCollision.shouldIgnoreProjectileCollision(entity, other) then
                    goto continue
                end
                
                local hit, hitX, hitY = EntityCollision.checkProjectileCollision(entity, other, dt)
                if hit then
                    EntityCollision.handleProjectileCollision(entity, other, dt, nil, hitX, hitY)
                end
            else
                -- Use standard collision detection for other entities
                local collided, collision = checkEntityCollision(entity, other)
                if collided then
                    EntityCollision.resolveEntityCollision(entity, other, dt, collision)
                end
            end

            ::continue::
        end
    end
end

-- Check if projectile collision should be ignored
function EntityCollision.shouldIgnoreProjectileCollision(projectile, target)
    if not projectile or not target or not projectile.components.bullet then
        return true
    end

    local source = projectile.components.bullet and projectile.components.bullet.source
    if target == projectile or target == source then
        return true
    end

    local projectileComponent = projectile.components.bullet ~= nil
    local targetIsProjectile = target.components.bullet ~= nil
    if projectileComponent and targetIsProjectile then
        local targetSource = target.components.bullet and target.components.bullet.source
        if targetSource == source then
            return true
        end
        return false
    end

    local isFriendlyBullet = (projectile.components.collidable and projectile.components.collidable.friendly) or false
    if isFriendlyBullet then
        local isFriendlyEntity = target.isFreighter or target.isFriendly
        local isPlayerEntity = target.isPlayer or target.isRemotePlayer or (target.components and target.components.player)
        if isFriendlyEntity and not isPlayerEntity then
            return true
        end
    end

    return false
end

-- Check projectile collision using line-segment detection
function EntityCollision.checkProjectileCollision(projectile, target, dt)
    if not projectile or not target or not projectile.components.bullet then
        return false
    end

    -- Use the same collision detection as laser beams for consistency
    local CollisionHelpers = require("src.systems.turret.collision_helpers")
    
    -- Calculate projectile trajectory
    local pos = projectile.components.position
    local vel = projectile.components.velocity or {x = 0, y = 0}
    
    -- Previous position (where projectile was last frame)
    local x1 = pos.x - ((vel.x or 0) * dt)
    local y1 = pos.y - ((vel.y or 0) * dt)
    
    -- Current position
    local x2 = pos.x
    local y2 = pos.y
    
    -- For polygon shapes, don't pass targetRadius to use precise polygon collision
    -- For circular shapes, calculate the exact radius from collision shape
    local targetRadius = nil
    local collidable = target.components and target.components.collidable
    if collidable and collidable.shape == "circle" and collidable.radius then
        targetRadius = collidable.radius
    end
    
    -- Use the same collision detection as laser beams (line-segment detection)
    return CollisionHelpers.performCollisionCheck(x1, y1, x2, y2, target, targetRadius)
end

-- Handle projectile-specific collision behavior
function EntityCollision.handleProjectileCollision(projectile, target, dt, collision, hitX, hitY)
    if not projectile or not target or not projectile.components.bullet then
        return
    end

    -- Import projectile collision handler
    local ProjectileHandler = require("src.systems.collision.handlers.projectile")
    
    -- Get target radius for effects
    local Radius = require("src.systems.collision.radius")
    local targetRadius = Radius.calculateEffectiveRadius(target)

    -- Process the hit using the existing projectile handler logic
    local world = projectile._world
    
    if world then
        ProjectileHandler.process_hit(nil, projectile, target, world, dt, hitX, hitY, targetRadius)
    else
        -- Fallback: just mark projectile as dead
        projectile.dead = true
    end
end

return EntityCollision
