local Physics = require("src.core.physics")
local Effects = require("src.systems.effects")
local Config = require("src.content.config")
local Geometry = require("src.systems.collision.geometry")
local Radius = require("src.systems.collision.radius")
local StationShields = require("src.systems.collision.station_shields")
local CollisionEffects = require("src.systems.collision.effects")
local EntityCollision = require("src.systems.collision.entity_collision")
local Log = require("src.core.log")
local ProjectileEvents = require("src.systems.projectile.event_dispatcher").EVENTS
local UpgradeSystem = require("src.systems.turret.upgrade_system")

local ProjectileCollision = {}

local function emit_projectile_event(projectile, event, payload)
    if not projectile or not projectile.components then return end
    local eventsComp = projectile.components.projectile_events
    local dispatcher = eventsComp and eventsComp.dispatcher
    if dispatcher then
        dispatcher:emit(event, payload)
    end
end

local function shouldIgnoreCollision(bullet, target)
    -- Safety check for null entities
    if not bullet or not target or not bullet.components or not target.components then
        return true
    end

    -- Ignore self and source
    local source = (bullet.components and bullet.components.bullet and bullet.components.bullet.source) or nil
    if target == bullet or target == source then 
        if target == source then
            Log.debug("Ignoring collision: target is source of projectile")
        end
        return true 
    end

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
        local isFriendlyEntity = target.isFreighter or target.isFriendly
        local isPlayerEntity = target.isPlayer or target.isRemotePlayer or (target.components and target.components.player)
        
        -- Allow PvP combat: friendly projectiles can hit other players
        -- Only prevent hitting non-player friendly entities (like freighters)
        if isFriendlyEntity and not isPlayerEntity then
            return true
        end
        
        -- For player entities, allow collision (PvP enabled)
        -- The source check above already prevents self-damage
    end

    return false
end

local function validate_target_radius(target_radius)
    if not target_radius or target_radius < 0 then
        Log.warn("Invalid target radius: " .. tostring(target_radius) .. ", defaulting to 10")
        return 10
    end
    return target_radius
end

local function perform_collision_check(x1, y1, x2, y2, target, target_radius)
    -- Skip zero-length segments (stationary bullets)
    if math.abs(x1 - x2) + math.abs(y1 - y2) < 0.01 then
        return false
    end

    -- Safety check for null target
    if not target or not target.components then
        return false
    end

    local components = target.components or {}
    local position = components.position or {}
    local ex, ey = position.x, position.y
    local collidable = components.collidable

    if not ex or not ey then
        return false
    end

    target_radius = validate_target_radius(target_radius)

    local health = components.health
    -- For players, check shield collision first if they have active shields
    -- This ensures remote projectiles properly detect shield hits even with stale shield data
    if health and (health.shield or 0) > 0 then
        local shield_radius = Radius.getShieldRadius(target)
        local shield_hit, hx, hy = Geometry.calculateShieldHitPoint(x1, y1, x2, y2, ex, ey, shield_radius)
        if shield_hit then
            return shield_hit, hx, hy
        end
        -- If shield miss, continue to check hull collision
    end

    local hasPolygon = collidable and collidable.vertices
    if hasPolygon and (collidable.shape == "polygon" or components.mineable) then
        local angle = position.angle or 0
        local wverts = Geometry.transformPolygon(ex, ey, angle, collidable.vertices)
        return Geometry.segPolygonHit(x1, y1, x2, y2, wverts)
    end

    return Physics.segCircleHit(x1, y1, x2, y2, ex, ey, target_radius)
end

function ProjectileCollision.handle_projectile_collision(collision_system, bullet, world, dt)
    -- Safety check for null bullet entity
    if not bullet or not bullet.components then
        return
    end

    local pos = bullet.components.position
    local vel = bullet.components.velocity or {x = 0, y = 0}
    local renderable = bullet.components.renderable
    local damage = bullet.components.damage

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
        if not target or not target.components or not target.components.collidable then goto skip_target end
        if shouldIgnoreCollision(bullet, target) then goto skip_target end
        if bullet._behaviorIgnoreTargets[target] then goto skip_target end

        local target_radius = Radius.calculateEffectiveRadius(target)
        local ex, ey = target.components.position.x, target.components.position.y
        local hit, hx, hy = perform_collision_check(x1, y1, x2, y2, target, target_radius)

        if hit then
            local impact_angle = math.atan2(hy - ey, hx - ex)

            if StationShields.isStation(target) and not bullet.friendly and StationShields.hasActiveShield(target) then
                Effects.spawnImpact('shield', ex, ey, target_radius, hx, hy, impact_angle, (bullet.components and bullet.components.bullet and bullet.components.bullet.impact), renderable.props.kind, target)
                local eventPayload = {
                    projectile = bullet,
                    target = target,
                    hitPosition = { x = hx, y = hy },
                    impactAngle = impact_angle,
                    hitKind = 'shield',
                    world = world,
                    separation = target_radius,
                }
                emit_projectile_event(bullet, ProjectileEvents.HIT, eventPayload)
                if eventPayload.keepAlive then
                    if eventPayload.skipTarget then
                        bullet._behaviorIgnoreTargets[eventPayload.skipTarget] = true
                    end
                    goto skip_target
                end
                bullet.dead = true
                return
            end

            -- Handle station safe zone
            if StationShields.checkStationSafeZone(bullet, target) then
                Effects.spawnImpact('shield', ex, ey, target_radius, hx, hy, impact_angle, (bullet.components and bullet.components.bullet and bullet.components.bullet.impact), renderable.props.kind, target)
                local eventPayload = {
                    projectile = bullet,
                    target = target,
                    hitPosition = { x = hx, y = hy },
                    impactAngle = impact_angle,
                    hitKind = 'shield',
                    world = world,
                    separation = target_radius,
                }
                emit_projectile_event(bullet, ProjectileEvents.HIT, eventPayload)
                if eventPayload.keepAlive then
                    if eventPayload.skipTarget then
                        bullet._behaviorIgnoreTargets[eventPayload.skipTarget] = true
                    end
                    goto skip_target
                end
                bullet.dead = true
                return
            end

            -- Track shield state before applying damage so multiplayer replicas stay consistent
            local had_shield = CollisionEffects.hasShield(target)

            -- Apply damage and create impact effect
            local shield_hit = false
            local dmg_val = (damage and (damage.value or damage)) or 1
            if target.components.health then
                local source = bullet.components and bullet.components.bullet and bullet.components.bullet.source
                shield_hit = CollisionEffects.applyDamage(target, dmg_val, source)
            end

            -- Handle impact direction vectors for special interactions
            local renderableProps = renderable.props or {}
            local dx = ex - pos.x
            local dy = ey - pos.y
            local distance = math.sqrt(dx * dx + dy * dy)
            local impactDirX, impactDirY = 1, 0
            if pos.angle then
                impactDirX = math.cos(pos.angle)
                impactDirY = math.sin(pos.angle)
            else
                local speedMag = math.sqrt((vel.x or 0) * (vel.x or 0) + (vel.y or 0) * (vel.y or 0))
                if speedMag > 0 then
                    impactDirX = (vel.x or 0) / speedMag
                    impactDirY = (vel.y or 0) / speedMag
                elseif distance > 0 then
                    impactDirX = dx / distance
                    impactDirY = dy / distance
                end
            end
            local projAngle = pos.angle or math.atan2(impactDirY, impactDirX)

            -- Handle force wave effect for kinetic wave projectiles
            if renderableProps.kind == 'wave' and bullet.components.force_wave then
                local forceWave = bullet.components.force_wave
                local knockbackForce = forceWave.knockback_force or 500
                local waveRadius = forceWave.radius or 12
                local arcAngle = math.pi * 0.6 -- 108 degrees wide arc (same as visual)

                -- Calculate knockback direction from projectile to target
                if distance > 0 then
                    local targetAngle = math.atan2(dy, dx)

                    -- Check if target is within the arc
                    local angleDiff = targetAngle - projAngle
                    -- Normalize angle difference to [-pi, pi]
                    while angleDiff > math.pi do angleDiff = angleDiff - 2 * math.pi end
                    while angleDiff < -math.pi do angleDiff = angleDiff + 2 * math.pi end

                    local isInArc = math.abs(angleDiff) <= arcAngle / 2

                    if isInArc and distance <= waveRadius then
                        local normalX = dx / distance
                        local normalY = dy / distance

                        -- Apply knockback force to target
                        local pushX = normalX * knockbackForce * 0.01 -- Scale down for reasonable force
                        local pushY = normalY * knockbackForce * 0.01

                        EntityCollision.pushEntity(target, pushX, pushY, normalX, normalY, dt, 0.5)
                    end
                end

                -- Apply area effect to nearby entities within the arc
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

                            -- Check if entity is within the arc
                            local angleDiff2 = entityAngle - projAngle
                            -- Normalize angle difference to [-pi, pi]
                            while angleDiff2 > math.pi do angleDiff2 = angleDiff2 - 2 * math.pi end
                            while angleDiff2 < -math.pi do angleDiff2 = angleDiff2 + 2 * math.pi end

                            local isInArc2 = math.abs(angleDiff2) <= arcAngle / 2

                            if isInArc2 then
                                local normalX2 = dx2 / distance2
                                local normalY2 = dy2 / distance2
                                local forceMultiplier = 1.0 - (distance2 / waveRadius) -- Falloff with distance
                                local pushX2 = normalX2 * knockbackForce * 0.01 * forceMultiplier
                                local pushY2 = normalY2 * knockbackForce * 0.01 * forceMultiplier

                                EntityCollision.pushEntity(entity, pushX2, pushY2, normalX2, normalY2, dt, 0.3)
                            end
                        end
                    end
                end
            end

            -- Apply ballistic impulse for kinetic projectiles
            if bullet.components.ballistics then
                local ballistics = bullet.components.ballistics
                local projectileMass = ballistics.projectile_mass or ballistics.mass or 1
                local muzzleVelocity = ballistics.muzzle_velocity or ballistics.velocity or 0
                local speedMag = math.sqrt((vel.x or 0) * (vel.x or 0) + (vel.y or 0) * (vel.y or 0))
                local impactVelocity = ballistics.impact_velocity or ((speedMag > 0) and speedMag or muzzleVelocity)
                if muzzleVelocity > 0 and impactVelocity < muzzleVelocity * 0.25 then
                    impactVelocity = muzzleVelocity * 0.25
                end

                local impulse = projectileMass * impactVelocity
                local impulseTransfer = ballistics.impulse_transfer or 1.0
                local impulseX = impactDirX * impulse * impulseTransfer
                local impulseY = impactDirY * impulse * impulseTransfer

                local appliedImpulse = false
                local physicsComp = target.components.physics
                local body = physicsComp and physicsComp.body
                if body and body.applyImpulse then
                    body:applyImpulse(impulseX, impulseY)
                    appliedImpulse = true
                end

                if not appliedImpulse then
                    local displacementScale = ballistics.displacement_scale or 0.0003
                    EntityCollision.pushEntity(target, impactDirX * impulse * displacementScale, impactDirY * impulse * displacementScale, impactDirX, impactDirY, dt, ballistics.restitution or 0.2)

                    local targetVel = target.components.velocity
                    if targetVel then
                        targetVel.x = (targetVel.x or 0) + impulseX * 0.01
                        targetVel.y = (targetVel.y or 0) + impulseY * 0.01
                    end
                end
            end

            -- Determine impact type using actual damage results
            local impact_type = (shield_hit or had_shield) and 'shield' or 'hull'
            if bullet.components and bullet.components.bullet then
                bullet.components.bullet.hitKind = impact_type
            end
            UpgradeSystem.onProjectileHit(bullet, dmg_val)

            -- Calculate impact radius for visual effect
            local impact_radius = target_radius
            if target.components.mineable then
                impact_radius = target.components.collidable.radius
            elseif impact_type == 'shield' then
                -- Use proper shield radius for impact effects
                impact_radius = target_radius - ((Config.BULLET and Config.BULLET.HIT_BUFFER) or 1.5)
            else
                impact_radius = target.components.collidable.radius or 10
            end

            Effects.spawnImpact(impact_type, ex, ey, impact_radius, hx, hy, impact_angle, (bullet.components and bullet.components.bullet and bullet.components.bullet.impact), renderable.props.kind, target)

            local eventPayload = {
                projectile = bullet,
                target = target,
                hitPosition = { x = hx, y = hy },
                impactAngle = impact_angle,
                hitKind = impact_type,
                world = world,
                separation = target_radius,
            }

            emit_projectile_event(bullet, ProjectileEvents.HIT, eventPayload)

            if eventPayload.keepAlive then
                if eventPayload.skipTarget then
                    bullet._behaviorIgnoreTargets[eventPayload.skipTarget] = true
                end
                goto skip_target
            end

            -- Handle chain lightning
            local source = bullet.components and bullet.components.bullet and bullet.components.bullet.source
            if source and source.components and source.components.equipment then
                local turret = source:getTurretInSlot(bullet.components.bullet.slot)
                if turret and turret.chainChance then
                    handle_chain_lightning(turret, target, world)
                end
            end

            bullet.dead = true
            return
        end
        ::skip_target::
    end
end

function handle_chain_lightning(turret, initial_target, world)
    local chance = turret.chainChance or 0
    if math.random() > chance then return end

    local range = turret.chainRange or 300
    local max_chains = turret.maxChains or 3
    local damage_falloff = turret.chainDamageFalloff or 0.75

    local chained_targets = { [initial_target] = true }
    local current_target = initial_target
    local current_damage = (turret.damage_range.min + turret.damage_range.max) / 2

    for i = 1, max_chains do
        local nearby_enemies = world:get_entities_in_radius(current_target.components.position.x, current_target.components.position.y, range, { "enemy" })
        
        local next_target = nil
        for _, enemy in ipairs(nearby_enemies) do
            if not chained_targets[enemy] then
                next_target = enemy
                break
            end
        end

        if next_target then
            local projectile = {
                components = {
                    bullet = {
                        source = turret.owner,
                        kind = "lightning_bolt",
                        damage = current_damage * damage_falloff,
                        slot = turret.slot
                    },
                    position = { x = current_target.components.position.x, y = current_target.components.position.y },
                    velocity = { x = 0, y = 0 }, -- Bolts are instantaneous
                    renderable = { props = { color = {0.5, 0.8, 1.0, 1.0} } },
                    timed_life = { life = 0.1 }
                },
                dead = false
            }
            world:addEntity(projectile)
            
            -- Simulate instant hit
            CollisionEffects.applyDamage(next_target, projectile.components.bullet.damage, turret.owner)
            Effects.spawnImpact('hull', next_target.components.position.x, next_target.components.position.y, Radius.calculateEffectiveRadius(next_target), next_target.components.position.x, next_target.components.position.y, 0, nil, "lightning_bolt", next_target)

            chained_targets[next_target] = true
            current_target = next_target
            current_damage = current_damage * damage_falloff
        else
            break -- No more targets in range
        end
    end
end

function ProjectileCollision.handle_beam_collision(collision_system, beam, world, dt)
    -- Safety check for null beam entity
    if not beam or not beam.components then
        return
    end

    local pos = beam.components.position
    local renderable = beam.components.renderable
    local damage = beam.components.damage

    if not pos or not renderable or not renderable.props then return end

    local angle = renderable.props.angle or 0
    local max_len = (renderable.props.maxLength and renderable.props.maxLength > 0) and renderable.props.maxLength or (renderable.props.length or 800)
    local x1, y1 = pos.x, pos.y
    local x2, y2 = pos.x + math.cos(angle) * max_len, pos.y + math.sin(angle) * max_len

    -- Reset beam length to maximum range every frame to ensure full range rendering when no target hit
    renderable.props.length = max_len

    local bb = {
        x = math.min(x1, x2) - 50,
        y = math.min(y1, y2) - 50,
        width = math.abs(x1 - x2) + 100,
        height = math.abs(y1 - y2) + 100
    }

    local potentials = collision_system.quadtree:query(bb)
    local best, best_len = nil, math.huge

    for _, obj in ipairs(potentials) do
        local target = obj.entity
        if not target or not target.components or not target.components.collidable then goto skip_beam_target end
        if shouldIgnoreCollision(beam, target) then goto skip_beam_target end

        local target_radius = Radius.calculateEffectiveRadius(target)
        local ex, ey = target.components.position.x, target.components.position.y
        local hit, hx, hy = perform_collision_check(x1, y1, x2, y2, target, target_radius)

        if hit then
            local dx, dy = hx - x1, hy - y1
            local hit_len = math.sqrt(dx*dx + dy*dy)
            if hit_len > 0 and hit_len < max_len and hit_len < best_len then
                best_len = hit_len
                best = {target=target, ex=ex, ey=ey, er=target_radius, hx=hx, hy=hy}
            end
        end
        ::skip_beam_target::
    end

    if best then
        -- Set beam length to hit point
        renderable.props.length = best_len
        renderable.props.maxLength = best_len

        if not beam.has_hit then
            beam.has_hit = true
            local target, ex, ey, er, hx, hy = best.target, best.ex, best.ey, best.er, best.hx, best.hy
            local impact_angle = math.atan2(hy - ey, hx - ex)

            -- Handle station safe zone
            if StationShields.checkStationSafeZone(beam, target) then
                Effects.spawnImpact('shield', ex, ey, er, hx, hy, impact_angle, nil, renderable.props.kind, target)
                return
            end

            -- Track shield state before applying damage so multiplayer replicas stay consistent
            local had_shield = CollisionEffects.hasShield(target)

            -- Apply damage
            local shield_hit = false
            if target.components.health then
                local source = beam.components and beam.components.bullet and beam.components.bullet.source
                local dmg_val = (damage and (damage.value or damage)) or 1
                shield_hit = CollisionEffects.applyDamage(target, dmg_val, source)
            end

            -- Determine impact type from damage results
            local impact_type = (shield_hit or had_shield) and 'shield' or 'hull'

            -- Calculate proper impact radius based on shield status
            local impact_radius = er
            if target.components.mineable then
                impact_radius = target.components.collidable.radius
            elseif impact_type == 'shield' then
                -- Use shield radius for shield impacts
                impact_radius = er
            else
                -- Use hull radius for hull impacts
                impact_radius = target.components.collidable.radius or 10
            end
            
            -- Pass impact configuration from the beam
            local impact_config = nil
            if beam.components and beam.components.bullet then
                impact_config = beam.components.bullet.impact
            end
            
            Effects.spawnImpact(impact_type, ex, ey, impact_radius, hx, hy, impact_angle, impact_config, renderable.props.kind, target)
        end
    else
        -- No hit: reset beam length if not previously hit
        if not beam.has_hit then
            renderable.props.length = max_len
        end
    end
end

return ProjectileCollision
