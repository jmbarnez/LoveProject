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

-- Debug flag to help identify collision effect issues
local DEBUG_COLLISION_EFFECTS = true

local function debugLog(message)
    if DEBUG_COLLISION_EFFECTS then
        print("[EntityCollision] " .. tostring(message))
    end
end

-- Check if two entities belong to the same logical group (e.g., same station)
local function areEntitiesInSameGroup(entity1, entity2)
    -- If both entities have a station_id, they belong to the same group if IDs match
    if entity1.station_id and entity2.station_id then
        return entity1.station_id == entity2.station_id
    end
    
    -- If both entities have a parent_station, they belong to the same group if parents match
    if entity1.parent_station and entity2.parent_station then
        return entity1.parent_station == entity2.parent_station
    end
    
    -- If one entity is a station and the other has that station as parent
    if entity1.tag == "station" and entity2.parent_station == entity1 then
        return true
    end
    if entity2.tag == "station" and entity1.parent_station == entity2 then
        return true
    end
    
    -- If both entities are station parts (have station component)
    if entity1.components and entity1.components.station and 
       entity2.components and entity2.components.station then
        -- Check if they have the same station reference
        return entity1.station == entity2.station
    end
    
    -- If both entities are parts of the same ship
    if entity1.ship_id and entity2.ship_id then
        return entity1.ship_id == entity2.ship_id
    end
    
    -- If both entities are parts of the same asteroid
    if entity1.asteroid_id and entity2.asteroid_id then
        return entity1.asteroid_id == entity2.asteroid_id
    end
    
    -- If both entities are parts of the same wreckage
    if entity1.wreckage_id and entity2.wreckage_id then
        return entity1.wreckage_id == entity2.wreckage_id
    end
    
    -- If both entities are parts of the same enemy
    if entity1.enemy_id and entity2.enemy_id then
        return entity1.enemy_id == entity2.enemy_id
    end
    
    -- If both entities are parts of the same hub
    if entity1.hub_id and entity2.hub_id then
        return entity1.hub_id == entity2.hub_id
    end
    
    -- If both entities are parts of the same warp gate
    if entity1.warp_gate_id and entity2.warp_gate_id then
        return entity1.warp_gate_id == entity2.warp_gate_id
    end
    
    -- If both entities are parts of the same beacon
    if entity1.beacon_id and entity2.beacon_id then
        return entity1.beacon_id == entity2.beacon_id
    end
    
    -- If both entities are parts of the same ore furnace
    if entity1.ore_furnace_id and entity2.ore_furnace_id then
        return entity1.ore_furnace_id == entity2.ore_furnace_id
    end
    
    -- If both entities are parts of the same holographic turret
    if entity1.holographic_turret_id and entity2.holographic_turret_id then
        return entity1.holographic_turret_id == entity2.holographic_turret_id
    end
    
    -- If both entities are parts of the same reward crate
    if entity1.reward_crate_id and entity2.reward_crate_id then
        return entity1.reward_crate_id == entity2.reward_crate_id
    end
    
    -- If both entities are parts of the same planet
    if entity1.planet_id and entity2.planet_id then
        return entity1.planet_id == entity2.planet_id
    end
    
    return false
end

-- Get the group identifier for an entity
local function getEntityGroupId(entity)
    -- Priority order for group identification
    if entity.station_id then
        return "station_" .. tostring(entity.station_id)
    end
    if entity.parent_station then
        return "station_" .. tostring(entity.parent_station.id or entity.parent_station)
    end
    if entity.tag == "station" then
        return "station_" .. tostring(entity.id)
    end
    if entity.ship_id then
        return "ship_" .. tostring(entity.ship_id)
    end
    if entity.asteroid_id then
        return "asteroid_" .. tostring(entity.asteroid_id)
    end
    if entity.wreckage_id then
        return "wreckage_" .. tostring(entity.wreckage_id)
    end
    if entity.enemy_id then
        return "enemy_" .. tostring(entity.enemy_id)
    end
    if entity.hub_id then
        return "hub_" .. tostring(entity.hub_id)
    end
    if entity.warp_gate_id then
        return "warp_gate_" .. tostring(entity.warp_gate_id)
    end
    if entity.beacon_id then
        return "beacon_" .. tostring(entity.beacon_id)
    end
    if entity.ore_furnace_id then
        return "ore_furnace_" .. tostring(entity.ore_furnace_id)
    end
    if entity.holographic_turret_id then
        return "holographic_turret_" .. tostring(entity.holographic_turret_id)
    end
    if entity.reward_crate_id then
        return "reward_crate_" .. tostring(entity.reward_crate_id)
    end
    if entity.planet_id then
        return "planet_" .. tostring(entity.planet_id)
    end
    
    -- Fallback to individual entity ID
    return "entity_" .. tostring(entity.id)
end

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

    -- For ships and other entities that require polygon shapes, check if they have them
    if entity.tag == "ship" or entity.tag == "enemy" or entity.tag == "asteroid" or 
       (entity.components and (entity.components.ship or entity.components.enemy or entity.components.mineable or entity.components.wreckage)) then
        -- These entities must have polygon collision shapes defined
        -- If no polygon shape is available, return nil (no collision)
        return nil
    end

    -- For stations, only use polygon shapes - no circular fallback
    if entity.tag == "station" or (entity.components and entity.components.station) then
        -- Stations must have polygon collision shapes - no circular fallback
        -- If no polygon shape is available, return nil (no collision)
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

-- Apply collision damage based on impact force
local function applyCollisionDamage(entity1, entity2, collision, nx, ny)
    if not entity1.components.health then return end
    
    -- Get collision velocity and mass for damage calculation
    local physics1 = entity1.components.physics and entity1.components.physics.body
    if not physics1 then return end
    
    local mass1 = getEntityMass(entity1)
    local mass2 = getEntityMass(entity2)
    
    -- Calculate relative velocity along collision normal
    local vx1, vy1 = physics1.vx, physics1.vy
    local vx2, vy2 = 0, 0
    if entity2.components.physics and entity2.components.physics.body then
        vx2, vy2 = entity2.components.physics.body.vx, entity2.components.physics.body.vy
    end
    
    local relVx = vx2 - vx1
    local relVy = vy2 - vy1
    local relVelAlongNormal = relVx * nx + relVy * ny
    
    -- Only apply damage if entities are approaching (not separating)
    if relVelAlongNormal <= 0 then return end
    
    -- Calculate impact force based on relative velocity and masses
    local impactForce = math.abs(relVelAlongNormal) * math.sqrt(mass1 * mass2) * 0.01
    
    -- Determine if hitting a hard surface (station, asteroid, planet, etc.)
    local isHardSurface = false
    if entity2.components.station or 
       entity2.components.mineable or 
       (entity2.type == "world_object" and entity2.subtype == "planet_massive") or
       entity2.components.wreckage then
        isHardSurface = true
    end
    
    -- Calculate damage based on impact force
    local damage = 0
    if isHardSurface then
        -- Hard surface impacts: more damage
        damage = math.min(impactForce * 0.8, 25) -- Cap at 25 damage
    else
        -- Hull-to-hull impacts: less damage
        damage = math.min(impactForce * 0.3, 15) -- Cap at 15 damage
    end
    
    -- Apply minimum damage threshold to avoid tiny impacts
    if damage < 2 then return end
    
    -- Apply the damage
    local CollisionEffects = require("src.systems.collision.effects")
    CollisionEffects.applyDamage(entity1, damage, entity2)
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
            -- Apply restitution more gradually for smoother physics
            local delta = -(1 + restitution) * vn * 0.3 -- Reduced by 70% for smoother bouncing
            body.vx = vx + delta * normalX
            body.vy = vy + delta * normalY
            
            -- Apply stronger damping to prevent jittering
            body.vx = body.vx * 0.98
            body.vy = body.vy * 0.98
            
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
                -- Apply restitution more gradually for smoother physics
                local delta = -(1 + restitution) * vn * 0.3 -- Reduced by 70% for smoother bouncing
                vel.x = vx + delta * normalX
                vel.y = vy + delta * normalY
                
                -- Apply stronger damping to prevent jittering
                vel.x = vel.x * 0.98
                vel.y = vel.y * 0.98
                
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

    -- Additional validation: ensure entities are actually overlapping
    local dx = e1x - e2x
    local dy = e1y - e2y
    local distance = math.sqrt(dx * dx + dy * dy)
    local minDistance = (getEntityCollisionRadius(entity1) + getEntityCollisionRadius(entity2)) * 0.8
    
    if distance > minDistance then
        -- Entities are too far apart for a real collision
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
            pushDistance = overlap * (isStationCollision and 0.3 or 0.2) -- Much smaller push for smoother physics
        else
            pushDistance = overlap * (isStationCollision and 0.25 or 0.15) -- Smaller push for circular shapes
        end
        
        -- Ensure minimum push distance for station collisions (reduced)
        if isStationCollision then
            pushDistance = math.max(pushDistance, 1) -- Much smaller minimum push
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
            
            -- Apply collision damage for hull-to-hull impacts
            applyCollisionDamage(entity1, entity2, collision, nx, ny)
            
            -- Apply momentum transfer between moving entities (smoother)
            local e1Physics = entity1.components.physics and entity1.components.physics.body
            local e2Physics = entity2.components.physics and entity2.components.physics.body
            
            if e1Physics and e2Physics then
                -- Calculate relative velocity
                local relVx = e2Physics.vx - e1Physics.vx
                local relVy = e2Physics.vy - e1Physics.vy
                local relVelAlongNormal = relVx * nx + relVy * ny
                
                -- Don't resolve if velocities are separating
                if relVelAlongNormal < 0 then
                    -- Calculate impulse magnitude with reduced strength for smoother physics
                    local impulse = -(1 + math.min(e1Rest, e2Rest)) * relVelAlongNormal * 0.5 -- Reduced by 50%
                    impulse = impulse / (1/mass1 + 1/mass2)
                    
                    -- Apply impulse
                    local impulseX = impulse * nx
                    local impulseY = impulse * ny
                    
                    e1Physics.vx = e1Physics.vx - impulseX / mass1
                    e1Physics.vy = e1Physics.vy - impulseY / mass1
                    e2Physics.vx = e2Physics.vx + impulseX / mass2
                    e2Physics.vy = e2Physics.vy + impulseY / mass2
                    
                    -- Apply additional damping to prevent jittering
                    e1Physics.vx = e1Physics.vx * 0.95
                    e1Physics.vy = e1Physics.vy * 0.95
                    e2Physics.vx = e2Physics.vx * 0.95
                    e2Physics.vy = e2Physics.vy * 0.95
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
            -- Apply collision damage for hull-to-static impacts
            applyCollisionDamage(entity1, entity2, collision, nx, ny)
        elseif e2CanMove then
            -- Only entity2 can move - push it away from static entity1
            pushEntity(entity2, nx * overlap, ny * overlap, nx, ny, dt, e2Rest)
            -- Apply friction from static surface
            applySurfaceFriction(entity2, nx, ny, dt)
            -- Apply collision damage for hull-to-static impacts
            applyCollisionDamage(entity2, entity1, collision, -nx, -ny)
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
        
        -- Check if entities belong to the same logical group (e.g., same station)
        local inSameGroup = areEntitiesInSameGroup(entity1, entity2)
        
        -- Only create effects if this entity has a lower ID to prevent duplicate effects
        -- This ensures collision effects are only created once per collision pair
        local shouldCreateEffects = not entity2.id or (entity1.id and entity1.id < entity2.id)
        
        -- For entities in the same group, only create effects once per group collision
        if inSameGroup then
            -- Use a group-based tracking system
            local groupKey = math.min(entity1.id or 0, entity2.id or 0) .. "_" .. math.max(entity1.id or 0, entity2.id or 0)
            entity1._groupCollisionFX = entity1._groupCollisionFX or {}
            local lastGroupCollision = entity1._groupCollisionFX[groupKey] or 0
            
            if (now - lastGroupCollision) < 0.1 then -- 100ms cooldown for group collisions
                shouldCreateEffects = false
            else
                entity1._groupCollisionFX[groupKey] = now
            end
        end
        
        -- Special handling for bullet collisions - use more aggressive cooldown
        local isBulletCollision = (entity1.components and entity1.components.bullet) or (entity2.components and entity2.components.bullet)
        if isBulletCollision and shouldCreateEffects then
            -- Use a more aggressive cooldown for bullet collisions
            local bulletEntity = entity1.components.bullet and entity1 or entity2
            local targetEntity = entity1.components.bullet and entity2 or entity1
            local bulletTargetKey = bulletEntity.id .. "_" .. targetEntity.id
            
            bulletEntity._bulletCollisionFX = bulletEntity._bulletCollisionFX or {}
            local lastBulletCollision = bulletEntity._bulletCollisionFX[bulletTargetKey] or 0
            
            if (now - lastBulletCollision) < 0.5 then -- 500ms cooldown for bullet collisions
                shouldCreateEffects = false
            else
                bulletEntity._bulletCollisionFX[bulletTargetKey] = now
            end
        end
        
        if CollisionEffects.canEmitCollisionFX(entity1, entity2, now) and overlap > 0 and shouldCreateEffects then
            if DEBUG_COLLISION_EFFECTS then
                local e1Type = entity1.tag or (entity1.components and entity1.components.station and "station") or "unknown"
                local e2Type = entity2.tag or (entity2.components and entity2.components.station and "station") or "unknown"
                local e1GroupId = getEntityGroupId(entity1)
                local e2GroupId = getEntityGroupId(entity2)
                debugLog(string.format("Collision effects check: e1(id=%s,type=%s,group=%s) vs e2(id=%s,type=%s,group=%s), sameGroup=%s, shouldCreate=%s", 
                    tostring(entity1.id), e1Type, e1GroupId, tostring(entity2.id), e2Type, e2GroupId, tostring(inSameGroup), tostring(shouldCreateEffects)))
            end
            
            -- Calculate precise collision point for physics simulation
            -- Find the actual contact point between the two entities
            local e1Radius = getEntityCollisionRadius(entity1)
            local e2Radius = getEntityCollisionRadius(entity2)
            
            -- Use the collision normal to find the precise contact point
            -- The contact point is where the surfaces actually touch
            local collisionX, collisionY
            
            -- Calculate the contact point based on the collision normal and entity radii
            -- Move from entity1's center along the normal by entity1's radius
            collisionX = e1x + nx * e1Radius
            collisionY = e1y + ny * e1Radius
            
            -- For more accuracy, we can also calculate from entity2's perspective and average
            local collisionX2 = e2x - nx * e2Radius
            local collisionY2 = e2y - ny * e2Radius
            
            -- Use the average of both calculations for the most accurate contact point
            collisionX = (collisionX + collisionX2) * 0.5
            collisionY = (collisionY + collisionY2) * 0.5
            
            -- Create visual effects using precise collision point
            CollisionEffects.createCollisionEffects(entity1, entity2, collisionX, collisionY, collisionX, collisionY, nx, ny, e1Radius, e2Radius, collision.shape1, collision.shape2)
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

    -- For projectiles, expand the query area to account for their speed
    local queryRadius = entityRadius
    if entity.components.bullet then
        local vel = entity.components.velocity or {x = 0, y = 0}
        local speed = math.sqrt((vel.x or 0)^2 + (vel.y or 0)^2)
        -- Add extra radius based on speed to catch fast-moving projectiles
        queryRadius = entityRadius + (speed * dt * 1.5)
    end

    -- Get potential collision targets from quadtree
    local candidates = collisionSystem.quadtree:query({
        x = ex - queryRadius,
        y = ey - queryRadius,
        width = queryRadius * 2,
        height = queryRadius * 2
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
                    -- Create collision effects using precise hit position
                    local now = (love and love.timer and love.timer.getTime and love.timer.getTime()) or 0
                    if CollisionEffects.canEmitCollisionFX(entity, other, now) then
                        local targetRadius = getEntityCollisionRadius(other)
                        local bulletRadius = getEntityCollisionRadius(entity)
                        
                        -- Use the precise hit position for collision effects
                        CollisionEffects.createCollisionEffects(entity, other, hitX, hitY, hitX, hitY, 0, 0, bulletRadius, targetRadius, nil, nil)
                    end
                    
                    EntityCollision.handleProjectileCollision(entity, other, dt, nil, hitX, hitY)
                end
            elseif other.components.bullet then
                -- Handle projectile vs non-projectile collision (other entity is projectile)
                if EntityCollision.shouldIgnoreProjectileCollision(other, entity) then
                    goto continue
                end
                
                local hit, hitX, hitY = EntityCollision.checkProjectileCollision(other, entity, dt)
                if hit then
                    -- Create collision effects using precise hit position
                    local now = (love and love.timer and love.timer.getTime and love.timer.getTime()) or 0
                    if CollisionEffects.canEmitCollisionFX(other, entity, now) then
                        local targetRadius = getEntityCollisionRadius(entity)
                        local bulletRadius = getEntityCollisionRadius(other)
                        
                        -- Use the precise hit position for collision effects
                        CollisionEffects.createCollisionEffects(other, entity, hitX, hitY, hitX, hitY, 0, 0, bulletRadius, targetRadius, nil, nil)
                    end
                    
                    EntityCollision.handleProjectileCollision(other, entity, dt, nil, hitX, hitY)
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
    
    -- Use effective radius for all targets to include HIT_BUFFER
    local Radius = require("src.systems.collision.radius")
    local targetRadius = Radius.calculateEffectiveRadius(target)
    
    -- Use the same collision detection as laser beams (line-segment detection)
    -- Use ProjectileUtils for consistency with the projectile handler
    local ProjectileUtils = require("src.systems.collision.helpers.projectile_utils")
    
    -- Get projectile radius from collidable component
    local projectileRadius = 2.0 -- Default radius
    local projectileCollidable = projectile.components.collidable
    if projectileCollidable and projectileCollidable.radius then
        projectileRadius = projectileCollidable.radius
    end
    
    return ProjectileUtils.perform_collision_check(x1, y1, x2, y2, target, targetRadius, projectileRadius)
end

-- Handle projectile-specific collision behavior
function EntityCollision.handleProjectileCollision(projectile, target, dt, collision, hitX, hitY)
    if not projectile or not target or not projectile.components.bullet then
        return
    end

    -- Get target radius for effects
    local Radius = require("src.systems.collision.radius")
    local targetRadius = Radius.calculateEffectiveRadius(target)

    -- Mark projectile as coming from unified collision system to prevent duplicate effects
    projectile._fromUnifiedCollision = true

    -- Process the hit using the unified collision system
    local world = projectile._world
    
    if world then
        local CollisionEffects = require("src.systems.collision.effects")
        local damage = projectile.components.damage and (projectile.components.damage.value or projectile.components.damage) or 1
        local source = projectile.components.bullet and projectile.components.bullet.source
        
        -- Check if target is also a projectile
        if target.components.bullet then
            -- Projectile vs projectile collision - both take damage
            local targetDamage = target.components.damage and (target.components.damage.value or target.components.damage) or 1
            
            -- Apply damage to both projectiles
            CollisionEffects.applyDamage(projectile, targetDamage, target.components.bullet.source)
            CollisionEffects.applyDamage(target, damage, source)
            
            -- Mark both projectiles as dead
            projectile.dead = true
            target.dead = true
        else
            -- Projectile vs non-projectile collision - only target takes damage
            CollisionEffects.applyDamage(target, damage, source)
            
            -- Mark projectile as dead
            projectile.dead = true
        end
    else
        -- Fallback: just mark projectile as dead
        projectile.dead = true
    end
end

-- Function to establish entity group relationships
function EntityCollision.establishGroupRelationship(entity, parentEntity, relationshipType)
    if not entity or not parentEntity then
        return false
    end
    
    local parentId = parentEntity.id or parentEntity
    if type(parentId) == "table" then
        parentId = parentId.id
    end
    
    if not parentId then
        return false
    end
    
    -- Set the appropriate group ID based on relationship type
    if relationshipType == "station" then
        entity.station_id = parentId
        entity.parent_station = parentEntity
    elseif relationshipType == "ship" then
        entity.ship_id = parentId
    elseif relationshipType == "asteroid" then
        entity.asteroid_id = parentId
    elseif relationshipType == "wreckage" then
        entity.wreckage_id = parentId
    elseif relationshipType == "enemy" then
        entity.enemy_id = parentId
    elseif relationshipType == "hub" then
        entity.hub_id = parentId
    elseif relationshipType == "warp_gate" then
        entity.warp_gate_id = parentId
    elseif relationshipType == "beacon" then
        entity.beacon_id = parentId
    elseif relationshipType == "ore_furnace" then
        entity.ore_furnace_id = parentId
    elseif relationshipType == "holographic_turret" then
        entity.holographic_turret_id = parentId
    elseif relationshipType == "reward_crate" then
        entity.reward_crate_id = parentId
    elseif relationshipType == "planet" then
        entity.planet_id = parentId
    else
        return false
    end
    
    return true
end

-- Function to check if two entities are in the same group
function EntityCollision.areInSameGroup(entity1, entity2)
    return areEntitiesInSameGroup(entity1, entity2)
end

-- Function to get the group ID for an entity
function EntityCollision.getGroupId(entity)
    return getEntityGroupId(entity)
end

-- Function to enable/disable debug logging
function EntityCollision.setDebugEnabled(enabled)
    DEBUG_COLLISION_EFFECTS = enabled
end

return EntityCollision
