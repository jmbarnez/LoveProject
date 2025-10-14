-- Entity Collision System - Modular Orchestrator
-- Coordinates collision detection and resolution using unified physics plus event hooks

local CollisionDetection = require("src.systems.collision.detection.collision_detection")
local CollisionShapes = require("src.systems.collision.shapes.collision_shapes")
local EntityGroups = require("src.systems.collision.groups.entity_groups")
local CollisionEvents = require("src.systems.collision.collision_events")
local ProjectileCollision = require("src.systems.collision.handlers.projectile_collision")
local UnifiedPhysics = require("src.systems.physics.unified_physics")
local Config = require("src.content.config")

-- Register built-in listeners that add bespoke behaviour (sounds, shield effects, etc.).
require("src.systems.collision.listeners.asteroid")
require("src.systems.collision.listeners.station")

local EntityCollision = {}

local function ensureNormal(entity1, entity2, collision)
    local nx = collision.normalX or 0
    local ny = collision.normalY or 0

    if nx == 0 and ny == 0 then
        local e1x = entity1.components.position.x
        local e1y = entity1.components.position.y
        local e2x = entity2.components.position.x
        local e2y = entity2.components.position.y

        local dx = e2x - e1x
        local dy = e2y - e1y
        local distance = math.sqrt(dx * dx + dy * dy)

        local Constants = require("src.systems.collision.constants")
        if distance < Constants.MIN_NORMAL_MAGNITUDE then
            nx = Constants.DEFAULT_NORMAL_X
            ny = Constants.DEFAULT_NORMAL_Y
        elseif distance > 0 then
            nx = dx / distance
            ny = dy / distance
        else
            nx, ny = 1, 0
        end

        collision.normalX = nx
        collision.normalY = ny
    end

    return collision.normalX, collision.normalY
end

local function getBody(entity)
    if not entity or not entity.components then
        return nil
    end
    local physics = entity.components.physics
    return physics and physics.body or nil
end

local function captureKinematics(entity)
    local body = getBody(entity)
    if body then
        local vx = body.vx or 0
        local vy = body.vy or 0
        return {
            vx = vx,
            vy = vy,
            speed = math.sqrt(vx * vx + vy * vy),
            mass = body.mass,
        }
    end

    local velocity = entity.components and entity.components.velocity
    local vx = velocity and velocity.x or 0
    local vy = velocity and velocity.y or 0

    return {
        vx = vx,
        vy = vy,
        speed = math.sqrt(vx * vx + vy * vy),
        mass = nil,
    }
end

-- Resolve collision between two entities
function EntityCollision.resolveEntityCollision(entity1, entity2, dt, collision)
    if not collision then
        return
    end

    local overlap = collision.overlap or 0
    if overlap <= 0 then
        return
    end

    -- Projectiles are handled through their dedicated module.
    if ProjectileCollision.isProjectile(entity1) then
        ProjectileCollision.handleProjectileCollision(entity1, entity2, dt, collision)
        return
    elseif ProjectileCollision.isProjectile(entity2) then
        ProjectileCollision.handleProjectileCollision(entity2, entity1, dt, collision)
        return
    end

    local nx, ny = ensureNormal(entity1, entity2, collision)

    local context = {
        entityA = entity1,
        entityB = entity2,
        bodyA = getBody(entity1),
        bodyB = getBody(entity2),
        collision = collision,
        dt = dt,
        overlap = overlap,
        normalX = nx,
        normalY = ny,
        world = entity1._world or entity2._world,
        pre = {
            a = captureKinematics(entity1),
            b = captureKinematics(entity2),
        },
        cancel = false,
    }

    CollisionEvents.emit("pre_resolve", context)

    if not context.cancel then
        UnifiedPhysics.handleCollision(entity1, entity2, collision, dt)
        context.post = {
            a = captureKinematics(entity1),
            b = captureKinematics(entity2),
        }
        context.resolved = true
        CollisionEvents.emit("post_resolve", context)
    else
        context.resolved = false
    end

    if context.resolved then
        EntityCollision._emitCollisionEffects(context)
    end
end

function EntityCollision._emitCollisionEffects(context)
    local entity1 = context.entityA
    local entity2 = context.entityB
    if not entity1 or not entity2 then
        return
    end

    local now = (love and love.timer and love.timer.getTime and love.timer.getTime()) or 0

    local inSameGroup = EntityGroups.areInSameGroup(entity1, entity2)
    local shouldCreateEffects = not entity2.id or (entity1.id and entity1.id < entity2.id)

    if inSameGroup then
        local lastGroupEffectTime = entity1._lastGroupEffectTime or 0
        local Constants = require("src.systems.collision.constants")
        if now - lastGroupEffectTime < Constants.COLLISION_EFFECT_COOLDOWN then
            shouldCreateEffects = false
        else
            entity1._lastGroupEffectTime = now
        end
    end

    if shouldCreateEffects and not inSameGroup then
        local CollisionEffects = require("src.systems.collision.effects")
        local e1x = entity1.components.position.x
        local e1y = entity1.components.position.y
        local e2x = entity2.components.position.x
        local e2y = entity2.components.position.y

        local radius1 = CollisionShapes.getEntityCollisionRadius(entity1)
        local radius2 = CollisionShapes.getEntityCollisionRadius(entity2)

        CollisionEffects.createCollisionEffects(
            entity1,
            entity2,
            e1x,
            e1y,
            e2x,
            e2y,
            context.normalX,
            context.normalY,
            radius1,
            radius2,
            context.collision.shape1,
            context.collision.shape2
        )
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
        -- Add extra radius based on speed to catch fast-moving projectiles, with cap to prevent over-querying
        local Constants = require("src.systems.collision.constants")
        local speedExpansion = math.min(Constants.PROJECTILE_MAX_QUERY_EXPANSION, speed * dt * Constants.PROJECTILE_QUERY_MULTIPLIER)
        queryRadius = entityRadius + speedExpansion
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
                -- Use unified physics for all other entities
                local collided, collisionData = CollisionDetection.checkEntityCollision(entity, other)
                if collided then
                    EntityCollision.resolveEntityCollision(entity, other, dt, collisionData)
                end
            end

            ::continue::
        end
    end
end

-- Function to enable/disable debug logging
function EntityCollision.setDebugEnabled(enabled)
    -- Debug logging is now controlled via Config.DEBUG.COLLISION_EFFECTS
    -- This function is kept for compatibility but no longer does anything
end

return EntityCollision
