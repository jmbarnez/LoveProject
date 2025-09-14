local Config = require("src.content.config")
local Effects = require("src.systems.effects")
local Radius = require("src.systems.collision.radius")
local StationShields = require("src.systems.collision.station_shields")
local CollisionEffects = require("src.systems.collision.effects")

local EntityCollision = {}

-- Check if two entities collide (using effective radius that includes shields)
local function checkEntityCollision(entity1, entity2)
    local e1x = entity1.components.position.x
    local e1y = entity1.components.position.y

    local e2x = entity2.components.position.x
    local e2y = entity2.components.position.y

    -- Use effective radius which accounts for shields
    local e1Radius = Radius.calculateEffectiveRadius(entity1)
    local e2Radius = Radius.calculateEffectiveRadius(entity2)

    -- Simple circular collision detection
    local dx = e1x - e2x
    local dy = e1y - e2y
    local distance = math.sqrt(dx * dx + dy * dy)
    local minDistance = e1Radius + e2Radius

    return distance < minDistance
end

-- Helper function to push an entity
local function pushEntity(entity, pushX, pushY, normalX, normalY, dt, restitution)
    restitution = restitution or 0.25 -- default hull bounce if unspecified
    if entity.components.physics and entity.components.physics.body then
        -- Update physics body position
        local body = entity.components.physics.body
        body.x = (body.x or entity.components.position.x) + pushX
        body.y = (body.y or entity.components.position.y) + pushY

        -- Apply bounce by reflecting velocity along the collision normal
        local vx = body.vx or 0
        local vy = body.vy or 0
        local vn = vx * normalX + vy * normalY
        if vn < 0 then -- moving into the surface
            -- Reflect normal component with restitution, preserve tangential
            local delta = -(1 + restitution) * vn
            body.vx = vx + delta * normalX
            body.vy = vy + delta * normalY
            -- Mild tangential smoothing to reduce jitter while keeping bounce feel
            body.vx = body.vx * 0.995
            body.vy = body.vy * 0.995
            -- Ensure a minimum outward normal speed for bouncy shields so it feels punchy
            if restitution > 0.8 then
                local newVn = body.vx * normalX + body.vy * normalY
                local minOut = 60 -- units/s
                if newVn < minOut then
                    local add = (minOut - newVn)
                    body.vx = body.vx + add * normalX
                    body.vy = body.vy + add * normalY
                end
            end
        end
    else
        -- Update position component directly
        entity.components.position.x = entity.components.position.x + pushX
        entity.components.position.y = entity.components.position.y + pushY

        -- If a simple velocity component exists, apply bounce there too
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
function EntityCollision.resolveEntityCollision(entity1, entity2, dt)
    local e1x = entity1.components.position.x
    local e1y = entity1.components.position.y
    local e2x = entity2.components.position.x
    local e2y = entity2.components.position.y

    -- Calculate collision normal (direction from entity2 to entity1)
    local dx = e1x - e2x
    local dy = e1y - e2y
    local distance = math.sqrt(dx * dx + dy * dy)

    if distance < 0.1 then
        -- Avoid division by zero, use arbitrary direction
        dx, dy = 1, 0
        distance = 1
    end

    -- Normalize collision normal
    local nx = dx / distance
    local ny = dy / distance

    -- Calculate overlap amount using effective radius (includes shields)
    local e1Radius = Radius.calculateEffectiveRadius(entity1)
    local e2Radius = Radius.calculateEffectiveRadius(entity2)

    local overlap = (e1Radius + e2Radius) - distance

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
        local e1CanMove = (entity1.components.physics and entity1.components.physics.body) or
                          (entity1.isPlayer or entity1.components.player or entity1.components.ai)
        local e2CanMove = (entity2.components.physics and entity2.components.physics.body) or
                          (entity2.isPlayer or entity2.components.player or entity2.components.ai)

        local pushDistance = overlap * 0.55 -- Split the separation

        -- Choose restitution based on shields (make shields bouncier)
        local HULL_REST = (Config and Config.COMBAT and Config.COMBAT.HULL_RESTITUTION) or 0.28
        local SHIELD_REST = (Config and Config.COMBAT and Config.COMBAT.SHIELD_RESTITUTION) or 0.88
        local e1Rest = StationShields.hasActiveShield(entity1) and SHIELD_REST or HULL_REST
        local e2Rest = StationShields.hasActiveShield(entity2) and SHIELD_REST or HULL_REST

        -- Push entities apart based on their mobility
        if e1CanMove and e2CanMove then
            -- Both can move - push each half the distance
            pushEntity(entity1, nx * pushDistance, ny * pushDistance, nx, ny, dt, e1Rest)
            pushEntity(entity2, -nx * pushDistance, -ny * pushDistance, -nx, -ny, dt, e2Rest)
        elseif e1CanMove then
            -- Only entity1 can move - push it the full distance
            pushEntity(entity1, nx * overlap * 1.1, ny * overlap * 1.1, nx, ny, dt, e1Rest)
        elseif e2CanMove then
            -- Only entity2 can move - push it the full distance
            pushEntity(entity2, -nx * overlap * 1.1, -ny * overlap * 1.1, -nx, -ny, dt, e2Rest)
        end

        -- Throttle collision FX to avoid spamming when resting against geometry
        local now = (love and love.timer and love.timer.getTime and love.timer.getTime()) or 0
        if CollisionEffects.canEmitCollisionFX(entity1, entity2, now) then
            -- Create visual effects for both entities
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

            -- Check for collision
            local collided = checkEntityCollision(entity, other)
            if collided then
                EntityCollision.resolveEntityCollision(entity, other, dt)
            end

            ::continue::
        end
    end
end

return EntityCollision