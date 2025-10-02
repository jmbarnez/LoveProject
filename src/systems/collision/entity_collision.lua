local Constants = require("src.core.constants")
local Config = require("src.content.config")
local Effects = require("src.systems.effects")
local Radius = require("src.systems.collision.radius")
local Geometry = require("src.systems.collision.geometry")
local StationShields = require("src.systems.collision.station_shields")
local CollisionEffects = require("src.systems.collision.effects")

local EntityCollision = {}

local combatOverrides = Config.COMBAT or {}
local combatConstants = Constants.COMBAT

local function getCombatValue(key)
    local value = combatOverrides[key]
    if value ~= nil then return value end
    return combatConstants[key]
end

local function hasActiveShield(entity)
    local health = entity.components and entity.components.health
    return (health and (health.shield or 0) > 0) or StationShields.hasActiveShield(entity)
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

    if hasActiveShield(entity) then
        return {
            type = "circle",
            x = pos.x,
            y = pos.y,
            radius = Radius.getShieldRadius(entity)
        }
    end

    -- Check for polygon collision shape directly (same as projectile collision system)
    local collidable = entity.components and entity.components.collidable
    if collidable and collidable.shape == "polygon" and collidable.vertices then
        local pos = entity.components.position
        local angle = (pos and pos.angle) or 0
        local verts = Geometry.transformPolygon(pos.x, pos.y, angle, collidable.vertices)
        if verts then
            return { type = "polygon", vertices = verts }
        end
    end

    -- For stations, only use polygon shapes - no circular fallback
    if entity.tag == "station" or (entity.components and entity.components.station) then
        -- Stations must have polygon collision shapes - no circular fallback
        -- If no polygon shape is available, return nil (no collision)
        return nil
    end

    return {
        type = "circle",
        x = pos.x,
        y = pos.y,
        radius = Radius.getHullRadius(entity)
    }
end

local function checkEntityCollision(entity1, entity2)
    local shape1 = getCollisionShape(entity1)
    local shape2 = getCollisionShape(entity2)

    if not shape1 or not shape2 then
        return false
    end

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
        if distanceSq < (minDistance * minDistance) then
            local distance = math.sqrt(distanceSq)
            local nx, ny
            if distance > 0 then
                nx = dx / distance
                ny = dy / distance
            else
                nx, ny = 1, 0
                distance = minDistance
            end
            return true, { overlap = (minDistance - distance), normalX = nx, normalY = ny, shape1 = shape1, shape2 = shape2 }
        end
        return false
    end
end

-- Helper function to push an entity
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
            body.vx = body.vx * 0.995
            body.vy = body.vy * 0.995
            if restitution > 0.8 then
                local newVn = body.vx * normalX + body.vy * normalY
                local minOut = 60
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
                vel.x = vel.x * 0.995
                vel.y = vel.y * 0.995
                if restitution > 0.8 then
                    local newVn = vel.x * normalX + vel.y * normalY
                    local minOut = 60
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

        -- Determine which entities can move (have physics bodies or are movable)
        local e1Physics = entity1.components.physics and entity1.components.physics.body
        local e2Physics = entity2.components.physics and entity2.components.physics.body
        local e1Wreckage = entity1.components.wreckage ~= nil
        local e2Wreckage = entity2.components.wreckage ~= nil

        local e1CanMove = e1Physics or (entity1.isPlayer or entity1.components.player or entity1.components.ai) or e1Wreckage
        local e2CanMove = e2Physics or (entity2.isPlayer or entity2.components.player or entity2.components.ai) or e2Wreckage

        local pushDistance = overlap * 0.55 -- Split the separation

        -- Choose restitution based on shields (make shields bouncier)
        local HULL_REST = getCombatValue("HULL_RESTITUTION") or 0.28
        local SHIELD_REST = getCombatValue("SHIELD_RESTITUTION") or 0.88
        local e1Rest = hasActiveShield(entity1) and SHIELD_REST or HULL_REST
        local e2Rest = hasActiveShield(entity2) and SHIELD_REST or HULL_REST

        -- Push entities apart based on their mobility
        if e1CanMove and e2CanMove then
            pushEntity(entity1, nx * pushDistance, ny * pushDistance, nx, ny, dt, e1Rest)
            pushEntity(entity2, -nx * pushDistance, -ny * pushDistance, -nx, -ny, dt, e2Rest)
        elseif e1CanMove then
            pushEntity(entity1, nx * overlap, ny * overlap, nx, ny, dt, e1Rest)
        elseif e2CanMove then
            pushEntity(entity2, -nx * overlap, -ny * overlap, -nx, -ny, dt, e2Rest)
        end

        -- Momentum transfer: allow the player to impart motion to wreckage pieces
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
                local transfer = 0.55
                debrisBody.vx = (debrisBody.vx or 0) + playerBody.vx * transfer
                debrisBody.vy = (debrisBody.vy or 0) + playerBody.vy * transfer
                playerBody.vx = playerBody.vx * (1 - transfer * 0.3)
                playerBody.vy = playerBody.vy * (1 - transfer * 0.3)
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

    -- Skip bullets - they have their own collision handling
    if entity.components.bullet then
        return
    end

    local ex = entity.components.position.x
    local ey = entity.components.position.y

    -- Use effective radius for quadtree query (accounts for shields)
    local entityRadius = Radius.calculateEffectiveRadius(entity)

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
            -- Skip bullets - they have their own collision handling
            if other.components.bullet then
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
            local collided, collision = checkEntityCollision(entity, other)
            if collided then
                EntityCollision.resolveEntityCollision(entity, other, dt, collision)
            end

            ::continue::
        end
    end
end

return EntityCollision
