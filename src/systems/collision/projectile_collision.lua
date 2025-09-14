local Physics = require("src.core.physics")
local Effects = require("src.systems.effects")
local Config = require("src.content.config")
local Geometry = require("src.systems.collision.geometry")
local Radius = require("src.systems.collision.radius")
local StationShields = require("src.systems.collision.station_shields")
local CollisionEffects = require("src.systems.collision.effects")

local ProjectileCollision = {}

local function shouldIgnoreCollision(bullet, target)
    -- Ignore self and source
    local source = (bullet.components and bullet.components.bullet and bullet.components.bullet.source) or nil
    if target == bullet or target == source then return true end

    -- Ignore projectile vs projectile when from the same owner
    local bulletIsProjectile = bullet.components and bullet.components.bullet ~= nil
    local targetIsProjectile = target.components and target.components.bullet ~= nil
    if bulletIsProjectile and targetIsProjectile then
        local tSource = target.components.bullet and target.components.bullet.source or nil
        if tSource == source then
            return true
        end
        -- Different owners: allow collision (interception)
        return false
    end

    -- Check friendly fire rules
    local isFriendlyBullet = (bullet.components and bullet.components.collidable and bullet.components.collidable.friendly) or false
    if isFriendlyBullet then
        local isFriendlyEntity = (target.isPlayer or (target.components and target.components.player)) or target.isFreighter or target.isFriendly
        return isFriendlyEntity
    end

    return false
end

local function performCollisionCheck(x1, y1, x2, y2, target, targetRadius)
    local ex, ey = target.components.position.x, target.components.position.y
    local collidable = target.components.collidable

    -- Shields always take priority - they're larger than the hull
    if target.components.health and (target.components.health.shield or 0) > 0 then
        return Geometry.calculateShieldHitPoint(x1, y1, x2, y2, ex, ey, targetRadius)
    end

    -- Check for polygon collision shape (hull collision)
    if collidable and collidable.shape == "polygon" and collidable.vertices then
        local angle = (target.components.position and target.components.position.angle) or 0
        local wverts = Geometry.transformPolygon(ex, ey, angle, collidable.vertices)
        return Geometry.segPolygonHit(x1, y1, x2, y2, wverts)
    -- Legacy support for mineable objects with vertices
    elseif target.components.mineable and collidable and collidable.vertices then
        local angle = (target.components.position and target.components.position.angle) or 0
        local wverts = Geometry.transformPolygon(ex, ey, angle, collidable.vertices)
        return Geometry.segPolygonHit(x1, y1, x2, y2, wverts)
    else
        -- Fallback to circular hull collision
        local hit, hx, hy = Physics.segCircleHit(x1, y1, x2, y2, ex, ey, targetRadius)
        if not hit then
            local dx, dy = (x2 - ex), (y2 - ey)
            hit = (dx*dx + dy*dy) <= targetRadius*targetRadius
            hx, hy = x2, y2
        end
        return hit, hx, hy
    end
end

function ProjectileCollision.handleProjectileCollision(collisionSystem, bullet, world, dt)
    local pos = bullet.components.position
    local vel = bullet.components.velocity or {x = 0, y = 0}
    local renderable = bullet.components.renderable
    local damage = bullet.components.damage

    if not pos or not pos.x or not pos.y then return end
    if not renderable or not renderable.props then return end

    local x1, y1 = pos.x - ((vel.x or 0) * dt), pos.y - ((vel.y or 0) * dt)
    local x2, y2 = pos.x, pos.y

    local bullet_bbox = {
        x = math.min(x1, x2) - 10,
        y = math.min(y1, y2) - 10,
        width = math.abs(x1 - x2) + 20,
        height = math.abs(y1 - y2) + 20
    }

    local potentialColliders = collisionSystem.quadtree:query(bullet_bbox)

    for _, obj in ipairs(potentialColliders) do
        local target = obj.entity
        if not target.components or not target.components.collidable then goto skip_target end
        if shouldIgnoreCollision(bullet, target) then goto skip_target end

        local targetRadius = Radius.calculateEffectiveRadius(target)
        local ex, ey = target.components.position.x, target.components.position.y
        local hit, hx, hy = performCollisionCheck(x1, y1, x2, y2, target, targetRadius)

        if hit then
            local impactAngle = math.atan2(hy - ey, hx - ex)

            if StationShields.isStation(target) and not bullet.friendly and StationShields.hasActiveShield(target) then
                Effects.spawnImpact('shield', ex, ey, targetRadius, hx, hy, impactAngle, (bullet.components and bullet.components.bullet and bullet.components.bullet.impact), renderable.props.kind, target)
                bullet.dead = true
                return
            end

            -- Handle station safe zone
            if StationShields.checkStationSafeZone(bullet, target) then
                Effects.spawnImpact('shield', ex, ey, targetRadius, hx, hy, impactAngle, (bullet.components and bullet.components.bullet and bullet.components.bullet.impact), renderable.props.kind, target)
                bullet.dead = true
                return
            end

            -- Determine impact type *before* applying damage for correct FX
            local hasShields = StationShields.hasActiveShield(target) or CollisionEffects.isPlayerShieldActive(target)
            local impactType = hasShields and 'shield' or 'hull'

            -- Apply damage and create impact effect
            if target.components.health then
                local source = bullet.components and bullet.components.bullet and bullet.components.bullet.source
                local dmgVal = (damage and (damage.value or damage)) or 1
                CollisionEffects.applyDamage(target, dmgVal, source)
            end

            -- Calculate impact radius for visual effect
            local impactRadius = targetRadius
            if target.components.mineable then
                impactRadius = target.components.collidable.radius
            elseif hasShields then
                -- Use proper shield radius for impact effects
                impactRadius = targetRadius - ((Config.BULLET and Config.BULLET.HIT_BUFFER) or 1.5)
            else
                impactRadius = target.components.collidable.radius or 10
            end

            Effects.spawnImpact(impactType, ex, ey, impactRadius, hx, hy, impactAngle, (bullet.components and bullet.components.bullet and bullet.components.bullet.impact), renderable.props.kind, target)

            bullet.dead = true
            return
        end
        ::skip_target::
    end
end

function ProjectileCollision.handleBeamCollision(collisionSystem, beam, world, dt)
    local pos = beam.components.position
    local renderable = beam.components.renderable
    local damage = beam.components.damage

    if not pos or not renderable or not renderable.props then return end

    local angle = renderable.props.angle or 0
    local maxLen = (renderable.props.maxLength and renderable.props.maxLength > 0) and renderable.props.maxLength or (renderable.props.length or 800)
    local x1, y1 = pos.x, pos.y
    local x2, y2 = pos.x + math.cos(angle) * maxLen, pos.y + math.sin(angle) * maxLen

    local bb = {
        x = math.min(x1, x2) - 50,
        y = math.min(y1, y2) - 50,
        width = math.abs(x1 - x2) + 100,
        height = math.abs(y1 - y2) + 100
    }

    local potentials = collisionSystem.quadtree:query(bb)
    local best, bestLen = nil, math.huge

    for _, obj in ipairs(potentials) do
        local target = obj.entity
        if not target.components or not target.components.collidable then goto skip_beam_target end
        if shouldIgnoreCollision(beam, target) then goto skip_beam_target end

        local targetRadius = Radius.calculateEffectiveRadius(target)
        local ex, ey = target.components.position.x, target.components.position.y
        local hit, hx, hy = performCollisionCheck(x1, y1, x2, y2, target, targetRadius)

        if hit then
            local dx, dy = hx - x1, hy - y1
            local hitLen = math.sqrt(dx*dx + dy*dy)
            if hitLen > 0 and hitLen < maxLen and hitLen < bestLen then
                bestLen = hitLen
                best = {target=target, ex=ex, ey=ey, er=targetRadius, hx=hx, hy=hy}
            end
        end
        ::skip_beam_target::
    end

    if best then
        -- Set beam length to hit point
        renderable.props.length = bestLen
        renderable.props.maxLength = bestLen

        if not beam.hasHit then
            beam.hasHit = true
            local target, ex, ey, er, hx, hy = best.target, best.ex, best.ey, best.er, best.hx, best.hy
            local impactAngle = math.atan2(hy - ey, hx - ex)

            -- Handle station safe zone
            if StationShields.checkStationSafeZone(beam, target) then
                Effects.spawnImpact('shield', ex, ey, er, hx, hy, impactAngle, nil, renderable.props.kind, target)
                return
            end

            -- Determine impact type *before* applying damage for correct FX
            local hasShields = StationShields.hasActiveShield(target) or CollisionEffects.isPlayerShieldActive(target)
            local impactType = hasShields and 'shield' or 'hull'

            -- Apply damage
            if target.components.health then
                local source = beam.components and beam.components.bullet and beam.components.bullet.source
                local dmgVal = (damage and (damage.value or damage)) or 1
                CollisionEffects.applyDamage(target, dmgVal, source)
            end

            -- Calculate proper impact radius based on shield status
            local impactRadius = er
            if target.components.mineable then
                impactRadius = target.components.collidable.radius
            elseif hasShields then
                -- Use shield radius for shield impacts
                impactRadius = er
            else
                -- Use hull radius for hull impacts
                impactRadius = target.components.collidable.radius or 10
            end
            
            -- Pass impact configuration from the beam
            local impactConfig = nil
            if beam.components and beam.components.bullet then
                impactConfig = beam.components.bullet.impact
            end
            
            Effects.spawnImpact(impactType, ex, ey, impactRadius, hx, hy, impactAngle, impactConfig, renderable.props.kind, target)
        end
    else
        -- No hit: reset beam length if not previously hit
        if not beam.hasHit then
            renderable.props.length = maxLen
        end
    end
end

return ProjectileCollision