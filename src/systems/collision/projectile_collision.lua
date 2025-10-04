local Physics = require("src.core.physics")
local Effects = require("src.systems.effects")
local Config = require("src.content.config")
local Geometry = require("src.systems.collision.geometry")
local Radius = require("src.systems.collision.radius")
local StationShields = require("src.systems.collision.station_shields")
local CollisionEffects = require("src.systems.collision.effects")
local Log = require("src.core.log")
local ProjectileEvents = require("src.templates.projectile_system.event_dispatcher").EVENTS

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

    local components = target.components or {}
    local position = components.position or {}
    local ex, ey = position.x, position.y
    local collidable = components.collidable

    if not ex or not ey then
        return false
    end

    target_radius = validate_target_radius(target_radius)

    local health = components.health
    if health and (health.shield or 0) > 0 then
        local shield_radius = Radius.getShieldRadius(target)
        return Geometry.calculateShieldHitPoint(x1, y1, x2, y2, ex, ey, shield_radius)
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

    for _, obj in ipairs(potential_colliders) do
        local target = obj.entity
        if not target.components or not target.components.collidable then goto skip_target end
        if shouldIgnoreCollision(bullet, target) then goto skip_target end

        local target_radius = Radius.calculateEffectiveRadius(target)
        local ex, ey = target.components.position.x, target.components.position.y
        local hit, hx, hy = perform_collision_check(x1, y1, x2, y2, target, target_radius)

        if hit then
            local impact_angle = math.atan2(hy - ey, hx - ex)

            if StationShields.isStation(target) and not bullet.friendly and StationShields.hasActiveShield(target) then
                Effects.spawnImpact('shield', ex, ey, target_radius, hx, hy, impact_angle, (bullet.components and bullet.components.bullet and bullet.components.bullet.impact), renderable.props.kind, target)
                emit_projectile_event(bullet, ProjectileEvents.HIT, {
                    projectile = bullet,
                    target = target,
                    hitPosition = { x = hx, y = hy },
                    impactAngle = impact_angle,
                    hitKind = 'shield',
                })
                bullet.dead = true
                return
            end

            -- Handle station safe zone
            if StationShields.checkStationSafeZone(bullet, target) then
                Effects.spawnImpact('shield', ex, ey, target_radius, hx, hy, impact_angle, (bullet.components and bullet.components.bullet and bullet.components.bullet.impact), renderable.props.kind, target)
                emit_projectile_event(bullet, ProjectileEvents.HIT, {
                    projectile = bullet,
                    target = target,
                    hitPosition = { x = hx, y = hy },
                    impactAngle = impact_angle,
                    hitKind = 'shield',
                })
                bullet.dead = true
                return
            end

            -- Determine impact type *before* applying damage for correct FX
            local has_shields = StationShields.hasActiveShield(target) or CollisionEffects.isPlayerShieldActive(target)
            local impact_type = has_shields and 'shield' or 'hull'

            -- Apply damage and create impact effect
            if target.components.health then
                local source = bullet.components and bullet.components.bullet and bullet.components.bullet.source
                local dmg_val = (damage and (damage.value or damage)) or 1
                CollisionEffects.applyDamage(target, dmg_val, source)
            end

            -- Calculate impact radius for visual effect
            local impact_radius = target_radius
            if target.components.mineable then
                impact_radius = target.components.collidable.radius
            elseif has_shields then
                -- Use proper shield radius for impact effects
                impact_radius = target_radius - ((Config.BULLET and Config.BULLET.HIT_BUFFER) or 1.5)
            else
                impact_radius = target.components.collidable.radius or 10
            end

            Effects.spawnImpact(impact_type, ex, ey, impact_radius, hx, hy, impact_angle, (bullet.components and bullet.components.bullet and bullet.components.bullet.impact), renderable.props.kind, target)

            emit_projectile_event(bullet, ProjectileEvents.HIT, {
                projectile = bullet,
                target = target,
                hitPosition = { x = hx, y = hy },
                impactAngle = impact_angle,
                hitKind = impact_type,
            })

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
        if not target.components or not target.components.collidable then goto skip_beam_target end
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

            -- Determine impact type *before* applying damage for correct FX
            local has_shields = StationShields.hasActiveShield(target) or CollisionEffects.isPlayerShieldActive(target)
            local impact_type = has_shields and 'shield' or 'hull'

            -- Apply damage
            if target.components.health then
                local source = beam.components and beam.components.bullet and beam.components.bullet.source
                local dmg_val = (damage and (damage.value or damage)) or 1
                CollisionEffects.applyDamage(target, dmg_val, source)
            end

            -- Calculate proper impact radius based on shield status
            local impact_radius = er
            if target.components.mineable then
                impact_radius = target.components.collidable.radius
            elseif has_shields then
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
