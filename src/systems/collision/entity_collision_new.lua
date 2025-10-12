-- Entity Collision System - Modular Orchestrator
-- Coordinates collision detection and resolution using specialized handlers

local CollisionDetection = require("src.systems.collision.detection.collision_detection")
local CollisionShapes = require("src.systems.collision.shapes.collision_shapes")
local EntityGroups = require("src.systems.collision.groups.entity_groups")
local ShipCollision = require("src.systems.collision.handlers.ship_collision")
local AsteroidCollision = require("src.systems.collision.handlers.asteroid_collision")
local ProjectileCollision = require("src.systems.collision.handlers.projectile_collision")
local StationCollision = require("src.systems.collision.handlers.station_collision")

local EntityCollision = {}

-- Debug flag to help identify collision effect issues
local DEBUG_COLLISION_EFFECTS = true

local function debugLog(message)
    if DEBUG_COLLISION_EFFECTS then
        print("[EntityCollision] " .. tostring(message))
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
    local minDistance = (CollisionShapes.getEntityCollisionRadius(entity1) + CollisionShapes.getEntityCollisionRadius(entity2)) * 0.8
    
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
        -- Handle station shield collisions first
        if StationCollision.handleStationShieldCollision(entity1, entity2) then
            return -- Skip normal collision resolution
        end

        -- Handle asteroid-to-asteroid collisions
        if AsteroidCollision.isAsteroid(entity1) and AsteroidCollision.isAsteroid(entity2) then
            AsteroidCollision.handleAsteroidToAsteroid(entity1, entity2, collision, dt)
            return -- Skip normal collision resolution
        end

        -- Handle projectile collisions
        if ProjectileCollision.isProjectile(entity1) then
            ProjectileCollision.handleProjectileCollision(entity1, entity2, dt, collision)
            return -- Skip normal collision resolution
        elseif ProjectileCollision.isProjectile(entity2) then
            ProjectileCollision.handleProjectileCollision(entity2, entity1, dt, collision)
            return -- Skip normal collision resolution
        end

        -- Handle station collisions
        if StationCollision.isStation(entity1) then
            if StationCollision.handleStationCollision(entity1, entity2, collision, dt) then
                return -- Skip normal collision resolution
            end
        elseif StationCollision.isStation(entity2) then
            if StationCollision.handleStationCollision(entity2, entity1, collision, dt) then
                return -- Skip normal collision resolution
            end
        end

        -- Handle asteroid collisions with other entities
        if AsteroidCollision.isAsteroid(entity1) then
            AsteroidCollision.handleAsteroidCollision(entity1, entity2, collision, dt)
            return
        elseif AsteroidCollision.isAsteroid(entity2) then
            AsteroidCollision.handleAsteroidCollision(entity2, entity1, collision, dt)
            return
        end

        -- Default ship-to-ship collision handling
        ShipCollision.handleShipToShip(entity1, entity2, collision, dt)

        -- Handle ship pushing debris
        local player, debris = nil, nil
        if entity1.isPlayer and ShipCollision.canMove(entity2) then
            player, debris = entity1, entity2
        elseif entity2.isPlayer and ShipCollision.canMove(entity1) then
            player, debris = entity2, entity1
        end

        if player and debris then
            ShipCollision.handleShipDebrisPush(player, debris, collision, nx, ny, overlap)
        end

        -- Throttle collision FX to avoid spamming when resting against geometry
        local now = (love and love.timer and love.timer.getTime and love.timer.getTime()) or 0
        
        -- Check if entities belong to the same logical group (e.g., same station)
        local inSameGroup = EntityGroups.areInSameGroup(entity1, entity2)
        
        -- Only create effects if this entity has a lower ID to prevent duplicate effects
        local shouldCreateEffects = not entity2.id or (entity1.id and entity1.id < entity2.id)
        
        -- For entities in the same group, only create effects once per group collision
        if inSameGroup then
            local groupId = EntityGroups.getGroupId(entity1)
            local lastGroupEffectTime = entity1._lastGroupEffectTime or 0
            if now - lastGroupEffectTime < 0.1 then -- 100ms cooldown for group effects
                shouldCreateEffects = false
            else
                entity1._lastGroupEffectTime = now
            end
        end

        -- Create collision effects if appropriate
        if shouldCreateEffects and not inSameGroup then
            local CollisionEffects = require("src.systems.collision.effects")
            CollisionEffects.createCollisionEffects(entity1, entity2, collision, nx, ny, overlap)
        end
    end
end

-- Check collision between two entities
function EntityCollision.checkEntityCollision(entity1, entity2)
    return CollisionDetection.checkEntityCollision(entity1, entity2)
end

-- Check if two entities are in the same group
function EntityCollision.areInSameGroup(entity1, entity2)
    return EntityGroups.areInSameGroup(entity1, entity2)
end

-- Get the group ID for an entity
function EntityCollision.getGroupId(entity)
    return EntityGroups.getGroupId(entity)
end

-- Function to establish entity group relationships
function EntityCollision.establishGroupRelationship(entity, parentEntity, relationshipType)
    return EntityGroups.establishRelationship(entity, parentEntity, relationshipType)
end

-- Check projectile collision using line-segment detection
function EntityCollision.checkProjectileCollision(projectile, target, dt)
    return ProjectileCollision.checkProjectileCollision(projectile, target, dt)
end

-- Handle projectile-specific collision behavior
function EntityCollision.handleProjectileCollision(projectile, target, dt, collision, hitX, hitY)
    return ProjectileCollision.handleProjectileCollision(projectile, target, dt, collision, hitX, hitY)
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

    local ex = entity.components.position.x
    local ey = entity.components.position.y

    -- Use effective radius for quadtree query (accounts for shields)
    local radius_cache = collisionSystem and collisionSystem.radius_cache
    local entityRadius = radius_cache and radius_cache:getEffectiveRadius(entity)
        or CollisionShapes.getEntityCollisionRadius(entity)

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
            if other._collisionGrace and other._collisionGrace > 0 then
                goto continue
            end

            -- Skip friendly vs station shield collisions (allow friendlies inside station bubble)
            local StationShields = require("src.systems.collision.station_shields")
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
                if ProjectileCollision.shouldIgnoreTarget(entity, other, entity.components.bullet.source) then
                    goto continue
                end
                
                local hit, hitX, hitY = ProjectileCollision.checkProjectileCollision(entity, other, dt)
                if hit then
                    -- Create collision effects using precise hit position
                    local now = (love and love.timer and love.timer.getTime and love.timer.getTime()) or 0
                    local CollisionEffects = require("src.systems.collision.effects")
                    if CollisionEffects.canEmitCollisionFX(entity, other, now) then
                        local targetRadius = CollisionShapes.getEntityCollisionRadius(other)
                        local bulletRadius = CollisionShapes.getEntityCollisionRadius(entity)
                        
                        -- Use the precise hit position for collision effects
                        CollisionEffects.createCollisionEffects(entity, other, hitX, hitY, hitX, hitY, 0, 0, bulletRadius, targetRadius, nil, nil)
                    end
                    
                    ProjectileCollision.handleProjectileCollision(entity, other, dt, nil, hitX, hitY)
                end
            elseif other.components.bullet then
                -- Handle projectile vs non-projectile collision (other entity is projectile)
                if ProjectileCollision.shouldIgnoreTarget(other, entity, other.components.bullet.source) then
                    goto continue
                end
                
                local hit, hitX, hitY = ProjectileCollision.checkProjectileCollision(other, entity, dt)
                if hit then
                    -- Create collision effects using precise hit position
                    local now = (love and love.timer and love.timer.getTime and love.timer.getTime()) or 0
                    local CollisionEffects = require("src.systems.collision.effects")
                    if CollisionEffects.canEmitCollisionFX(other, entity, now) then
                        local targetRadius = CollisionShapes.getEntityCollisionRadius(entity)
                        local bulletRadius = CollisionShapes.getEntityCollisionRadius(other)
                        
                        -- Use the precise hit position for collision effects
                        CollisionEffects.createCollisionEffects(other, entity, hitX, hitY, hitX, hitY, 0, 0, bulletRadius, targetRadius, nil, nil)
                    end
                    
                    ProjectileCollision.handleProjectileCollision(other, entity, dt, nil, hitX, hitY)
                end
            else
                -- Use standard collision detection for other entities
                local collided, collision = CollisionDetection.checkEntityCollision(entity, other)
                if collided then
                    EntityCollision.resolveEntityCollision(entity, other, dt, collision)
                end
            end

            ::continue::
        end
    end
end

-- Function to enable/disable debug logging
function EntityCollision.setDebugEnabled(enabled)
    DEBUG_COLLISION_EFFECTS = enabled
end

return EntityCollision
