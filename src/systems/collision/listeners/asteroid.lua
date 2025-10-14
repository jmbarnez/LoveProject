-- Asteroid collision listener
-- Plays impact audio when asteroids collide with sufficient relative speed.

local CollisionEvents = require("src.systems.collision.collision_events")
local Sound = require("src.core.sound")
local Constants = require("src.systems.collision.constants")

local function isAsteroid(entity)
    return entity
        and entity.components
        and entity.components.mineable
        and entity.components.collidable ~= nil
end

local function computeRelativeSpeed(preA, preB)
    if not preA or not preB then
        return 0
    end
    local vx = (preA.vx or 0) - (preB.vx or 0)
    local vy = (preA.vy or 0) - (preB.vy or 0)
    return math.sqrt(vx * vx + vy * vy)
end

CollisionEvents.on("post_resolve", function(context)
    if not context or not context.resolved then
        return
    end

    local entityA = context.entityA
    local entityB = context.entityB

    if not (isAsteroid(entityA) and isAsteroid(entityB)) then
        return
    end

    local relativeSpeed = computeRelativeSpeed(context.pre and context.pre.a, context.pre and context.pre.b)
    if relativeSpeed <= Constants.ASTEROID_SOUND_THRESHOLD then
        return
    end

    local currentTime = (love and love.timer and love.timer.getTime and love.timer.getTime()) or 0
    local lastCollisionTime = (entityA._lastAsteroidCollision or 0) + (entityB._lastAsteroidCollision or 0)
    local timeSinceLast = currentTime - (lastCollisionTime * 0.5)

    if timeSinceLast <= Constants.ASTEROID_SOUND_COOLDOWN then
        return
    end

    local posA = entityA.components.position
    local posB = entityB.components.position
    if not (posA and posB) then
        return
    end

    local impactX = (posA.x + posB.x) * 0.5
    local impactY = (posA.y + posB.y) * 0.5

    local volumeScale = math.min(
        Constants.ASTEROID_SOUND_VOLUME_MAX,
        math.max(Constants.ASTEROID_SOUND_VOLUME_MIN, relativeSpeed / Constants.ASTEROID_SOUND_SCALE)
    )

    Sound.triggerEventAt("impact_rock", impactX, impactY, volumeScale)

    entityA._lastAsteroidCollision = currentTime
    entityB._lastAsteroidCollision = currentTime
end)
