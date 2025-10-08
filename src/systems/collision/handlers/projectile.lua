local Config = require("src.content.config")
local Effects = require("src.systems.effects")
local Radius = require("src.systems.collision.radius")
local StationShields = require("src.systems.collision.station_shields")
local CollisionEffects = require("src.systems.collision.effects")
local EntityCollision = require("src.systems.collision.entity_collision")
local ProjectileEvents = require("src.systems.projectile.event_dispatcher").EVENTS
local UpgradeSystem = require("src.systems.turret.upgrade_system")

local ProjectileUtils = require("src.systems.collision.helpers.projectile_utils")

--- ProjectileHandler encapsulates per-frame projectile collision checks and
--- effect dispatch independent from CollisionSystem orchestration.
local ProjectileHandler = {}

local HIT_BUFFER = (Config.BULLET and Config.BULLET.HIT_BUFFER) or 1.5

local function get_effective_radius(collision_system, entity)
    local cache = collision_system and collision_system.radius_cache
    if cache then
        return cache:getEffectiveRadius(entity)
    end
    return Radius.calculateEffectiveRadius(entity)
end
 
local function handle_chain_lightning(turret, initial_target, world)
    local chance = turret.chainChance or 0
    if math.random() > chance then return end

    local range = turret.chainRange or 300
    local max_chains = turret.maxChains or 3
    local damage_falloff = turret.chainDamageFalloff or 0.75

    local chained_targets = { [initial_target] = true }
    local current_target = initial_target
    local current_damage = (turret.damage_range.min + turret.damage_range.max) / 2

    for _ = 1, max_chains do
        local cx = current_target.components.position.x
        local cy = current_target.components.position.y
        local nearby_enemies = world:get_entities_in_radius(cx, cy, range, { "enemy" })

        local next_target = nil
        for _, enemy in ipairs(nearby_enemies) do
            if not chained_targets[enemy] then
                next_target = enemy
                break
            end
        end

        if not next_target then
            break
        end

        local projectile = {
            components = {
                bullet = {
                    source = turret.owner,
                    kind = "lightning_bolt",
                    damage = current_damage * damage_falloff,
                    slot = turret.slot
                },
                position = { x = cx, y = cy },
                velocity = { x = 0, y = 0 },
                renderable = { props = { color = {0.5, 0.8, 1.0, 1.0} } },
                timed_life = { life = 0.1 }
            },
            dead = false
        }
        world:addEntity(projectile)

        CollisionEffects.applyDamage(next_target, projectile.components.bullet.damage, turret.owner)
        Effects.spawnImpact('hull', next_target.components.position.x, next_target.components.position.y,
            get_effective_radius(nil, next_target),
            next_target.components.position.x, next_target.components.position.y, 0, nil, "lightning_bolt", next_target)

        chained_targets[next_target] = true
        current_target = next_target
        current_damage = current_damage * damage_falloff
    end
end

local function apply_force_wave(bullet, target, world, dt, impactDirX, impactDirY)
    local forceWave = bullet.components.force_wave
    if not forceWave then return end

    local knockbackForce = forceWave.knockback_force or 500
    local waveRadius = forceWave.radius or 12
    local arcAngle = math.pi * 0.6
    local pos = bullet.components.position
    local dx = target.components.position.x - pos.x
    local dy = target.components.position.y - pos.y
    local distance = math.sqrt(dx * dx + dy * dy)
    local projAngle = bullet.components.position.angle or math.atan2(impactDirY, impactDirX)

    if distance > 0 then
        local targetAngle = math.atan2(dy, dx)
        local angleDiff = targetAngle - projAngle
        while angleDiff > math.pi do angleDiff = angleDiff - 2 * math.pi end
        while angleDiff < -math.pi do angleDiff = angleDiff + 2 * math.pi end

        local isInArc = math.abs(angleDiff) <= arcAngle / 2
        if isInArc and distance <= waveRadius then
            local normalX = dx / distance
            local normalY = dy / distance
            local pushX = normalX * knockbackForce * 0.01
            local pushY = normalY * knockbackForce * 0.01
            EntityCollision.pushEntity(target, pushX, pushY, normalX, normalY, dt, 0.5)
        end
    end

    local nearbyEntities = world:get_entities_in_radius(pos.x, pos.y, waveRadius, {"enemy", "player"})
    for _, entity in ipairs(nearbyEntities) do
        if entity ~= target and entity.components.position and entity.components.physics then
            local ex2 = entity.components.position.x
            local ey2 = entity.components.position.y
            local dx2 = ex2 - pos.x
            local dy2 = ey2 - pos.y
            local distance2 = math.sqrt(dx2 * dx2 + dy2 * dy2)

            if distance2 > 0 and distance2 <= waveRadius then
                local entityAngle = math.atan2(dy2, dx2)
                local angleDiff2 = entityAngle - projAngle
                while angleDiff2 > math.pi do angleDiff2 = angleDiff2 - 2 * math.pi end
                while angleDiff2 < -math.pi do angleDiff2 = angleDiff2 + 2 * math.pi end

                local isInArc2 = math.abs(angleDiff2) <= arcAngle / 2
                if isInArc2 then
                    local normalX2 = dx2 / distance2
                    local normalY2 = dy2 / distance2
                    local forceMultiplier = 1.0 - (distance2 / waveRadius)
                    local pushX2 = normalX2 * knockbackForce * 0.01 * forceMultiplier
                    local pushY2 = normalY2 * knockbackForce * 0.01 * forceMultiplier

                    EntityCollision.pushEntity(entity, pushX2, pushY2, normalX2, normalY2, dt, 0.3)
                end
            end
        end
    end
end

local function apply_ballistic_impulse(bullet, target, dt, impactDirX, impactDirY)
    local ballistics = bullet.components.ballistics
    if not ballistics then return end

    local projectileMass = ballistics.projectile_mass or ballistics.mass or 1
    local muzzleVelocity = ballistics.muzzle_velocity or ballistics.velocity or 0
    local vel = bullet.components.velocity or {x = 0, y = 0}
    local speedMag = math.sqrt((vel.x or 0) * (vel.x or 0) + (vel.y or 0) * (vel.y or 0))
    local impactVelocity = ballistics.impact_velocity or ((speedMag > 0) and speedMag or muzzleVelocity)
    if muzzleVelocity > 0 and impactVelocity < muzzleVelocity * 0.25 then
        impactVelocity = muzzleVelocity * 0.25
    end

    local impulse = projectileMass * impactVelocity
    local impulseTransfer = ballistics.impulse_transfer or 1.0
    local impulseX = impactDirX * impulse * impulseTransfer
    local impulseY = impactDirY * impulse * impulseTransfer

    local physicsComp = target.components.physics
    local body = physicsComp and physicsComp.body
    if body and body.applyImpulse then
        body:applyImpulse(impulseX, impulseY)
        return
    end

    local displacementScale = ballistics.displacement_scale or 0.0003
    EntityCollision.pushEntity(target, impactDirX * impulse * displacementScale, impactDirY * impulse * displacementScale,
        impactDirX, impactDirY, dt, ballistics.restitution or 0.2)

    local targetVel = target.components.velocity
    if targetVel then
        targetVel.x = (targetVel.x or 0) + impulseX * 0.01
        targetVel.y = (targetVel.y or 0) + impulseY * 0.01
    end
end

local function compute_impact_direction(bullet, target)
    local pos = bullet.components.position
    local vel = bullet.components.velocity or {x = 0, y = 0}
    local dx = target.components.position.x - pos.x
    local dy = target.components.position.y - pos.y
    local distance = math.sqrt(dx * dx + dy * dy)
    local dirX, dirY = 1, 0

    if pos.angle then
        dirX = math.cos(pos.angle)
        dirY = math.sin(pos.angle)
    else
        local speedMag = math.sqrt((vel.x or 0) * (vel.x or 0) + (vel.y or 0) * (vel.y or 0))
        if speedMag > 0 then
            dirX = (vel.x or 0) / speedMag
            dirY = (vel.y or 0) / speedMag
        elseif distance > 0 then
            dirX = dx / distance
            dirY = dy / distance
        end
    end

    return dirX, dirY, pos.angle or math.atan2(dirY, dirX)
end

local function process_hit(collision_system, bullet, target, world, dt, hx, hy, target_radius)
    local pos = bullet.components.position
    local renderable = bullet.components.renderable
    local damage = bullet.components.damage
    local ex, ey = target.components.position.x, target.components.position.y
    local impact_angle = math.atan2(hy - ey, hx - ex)

    if ProjectileUtils.is_station_shield_hit(bullet, target) then
        Effects.spawnImpact('shield', ex, ey, target_radius, hx, hy, impact_angle,
            bullet.components.bullet and bullet.components.bullet.impact,
            renderable.props.kind, target)

        local eventPayload = {
            projectile = bullet,
            target = target,
            hitPosition = { x = hx, y = hy },
            impactAngle = impact_angle,
            hitKind = 'shield',
            world = world,
            separation = target_radius,
        }
        ProjectileUtils.emit_event(bullet, ProjectileEvents.HIT, eventPayload)

        if eventPayload.keepAlive then
            if eventPayload.skipTarget then
                bullet._behaviorIgnoreTargets[eventPayload.skipTarget] = true
            end
            return true
        end

        bullet.dead = true
        return true
    end

    if StationShields.checkStationSafeZone(bullet, target) then
        Effects.spawnImpact('shield', ex, ey, target_radius, hx, hy, impact_angle,
            bullet.components.bullet and bullet.components.bullet.impact,
            renderable.props.kind, target)

        local eventPayload = {
            projectile = bullet,
            target = target,
            hitPosition = { x = hx, y = hy },
            impactAngle = impact_angle,
            hitKind = 'shield',
            world = world,
            separation = target_radius,
        }
        ProjectileUtils.emit_event(bullet, ProjectileEvents.HIT, eventPayload)

        bullet.dead = true
        return true
    end

    local had_shield = CollisionEffects.hasShield(target)
    local dmg_val = (damage and (damage.value or damage)) or 1
    local shield_hit = false
    if target.components.health then
        local source = bullet.components.bullet and bullet.components.bullet.source
        shield_hit = CollisionEffects.applyDamage(target, dmg_val, source)
    end

    local impactDirX, impactDirY = compute_impact_direction(bullet, target)

    if renderable.props.kind == 'wave' and bullet.components.force_wave then
        apply_force_wave(bullet, target, world, dt, impactDirX, impactDirY)
    end

    if bullet.components.ballistics then
        apply_ballistic_impulse(bullet, target, dt, impactDirX, impactDirY)
    end

    local impact_type = (shield_hit or had_shield) and 'shield' or 'hull'
    if bullet.components.bullet then
        bullet.components.bullet.hitKind = impact_type
    end
    UpgradeSystem.onProjectileHit(bullet, dmg_val)

    local impact_radius = target_radius
    if target.components.mineable then
        impact_radius = target.components.collidable.radius
    elseif impact_type == 'shield' then
        impact_radius = target_radius - HIT_BUFFER
    else
        impact_radius = target.components.collidable.radius or 10
    end

    Effects.spawnImpact(impact_type, ex, ey, impact_radius, hx, hy, impact_angle,
        bullet.components.bullet and bullet.components.bullet.impact, renderable.props.kind, target)

    local eventPayload = {
        projectile = bullet,
        target = target,
        hitPosition = { x = hx, y = hy },
        impactAngle = impact_angle,
        hitKind = impact_type,
        world = world,
        separation = target_radius,
    }

    ProjectileUtils.emit_event(bullet, ProjectileEvents.HIT, eventPayload)

    if eventPayload.keepAlive then
        if eventPayload.skipTarget then
            bullet._behaviorIgnoreTargets[eventPayload.skipTarget] = true
        end
        return false
    end

    local source = bullet.components.bullet and bullet.components.bullet.source
    if source and source.components and source.components.equipment then
        local turret = source:getTurretInSlot(bullet.components.bullet.slot)
        if turret and turret.chainChance then
            handle_chain_lightning(turret, target, world)
        end
    end

    bullet.dead = true
    return true
end

function ProjectileHandler.process(collision_system, bullet, world, dt)
    if not bullet or not bullet.components then
        return
    end

    local pos = bullet.components.position
    local vel = bullet.components.velocity or {x = 0, y = 0}
    local renderable = bullet.components.renderable

    if not pos or not pos.x or not pos.y or not renderable or not renderable.props then return end

    local x1, y1 = pos.x - ((vel.x or 0) * dt), pos.y - ((vel.y or 0) * dt)
    local x2, y2 = pos.x, pos.y

    local bullet_bbox = {
        x = math.min(x1, x2) - 10,
        y = math.min(y1, y2) - 10,
        width = math.abs(x1 - x2) + 20,
        height = math.abs(y1 - y2) + 20
    }

    local potential_colliders = collision_system.quadtree:query(bullet_bbox)
    bullet._behaviorIgnoreTargets = bullet._behaviorIgnoreTargets or {}

    for _, obj in ipairs(potential_colliders) do
        local target = obj.entity
        if not target or not target.components or not target.components.collidable then goto continue end
        if ProjectileUtils.should_ignore_collision(bullet, target) then goto continue end
        if bullet._behaviorIgnoreTargets[target] then goto continue end

        local target_radius = get_effective_radius(collision_system, target)
        local hit, hx, hy = ProjectileUtils.perform_collision_check(x1, y1, x2, y2, target, target_radius)

        if hit then
            local consumed = process_hit(collision_system, bullet, target, world, dt, hx, hy, target_radius)
            if consumed then
                return
            end
        end
        ::continue::
    end
end

return ProjectileHandler
