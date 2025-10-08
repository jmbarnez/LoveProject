local Effects = require("src.systems.effects")
local Radius = require("src.systems.collision.radius")
local StationShields = require("src.systems.collision.station_shields")
local CollisionEffects = require("src.systems.collision.effects")

local ProjectileUtils = require("src.systems.collision.helpers.projectile_utils")

--- BeamHandler resolves instantaneous beam collisions, shortening beams and
--- routing shield/hull effects.
local BeamHandler = {}

local function get_effective_radius(collision_system, entity)
    local cache = collision_system and collision_system.radius_cache
    if cache then
        return cache:getEffectiveRadius(entity)
    end
    return Radius.calculateEffectiveRadius(entity)
end

function BeamHandler.process(collision_system, beam, world, dt)
    if not beam or not beam.components then
        return
    end

    local pos = beam.components.position
    local renderable = beam.components.renderable
    local damage = beam.components.damage

    if not pos or not renderable or not renderable.props then return end

    local angle = renderable.props.angle or 0
    local max_len = (renderable.props.maxLength and renderable.props.maxLength > 0) and renderable.props.maxLength
        or (renderable.props.length or 800)
    local x1, y1 = pos.x, pos.y
    local x2, y2 = pos.x + math.cos(angle) * max_len, pos.y + math.sin(angle) * max_len

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
        if not target or not target.components or not target.components.collidable then goto continue end
        if ProjectileUtils.should_ignore_collision(beam, target) then goto continue end

        local target_radius = get_effective_radius(collision_system, target)
        local hit, hx, hy = ProjectileUtils.perform_collision_check(x1, y1, x2, y2, target, target_radius)

        if hit then
            local dx, dy = hx - x1, hy - y1
            local hit_len = math.sqrt(dx * dx + dy * dy)
            if hit_len > 0 and hit_len < max_len and hit_len < best_len then
                best_len = hit_len
                best = {target=target, hx=hx, hy=hy, radius=target_radius}
            end
        end
        ::continue::
    end

    if not best then
        if not beam.has_hit then
            renderable.props.length = max_len
        end
        return
    end

    renderable.props.length = best_len
    renderable.props.maxLength = best_len

    if beam.has_hit then
        return
    end

    beam.has_hit = true
    local target = best.target
    local ex = target.components.position.x
    local ey = target.components.position.y
    local impact_angle = math.atan2(best.hy - ey, best.hx - ex)

    if StationShields.checkStationSafeZone(beam, target) then
        Effects.spawnImpact('shield', ex, ey, best.radius, best.hx, best.hy, impact_angle, nil, renderable.props.kind, target)
        return
    end

    local had_shield = CollisionEffects.hasShield(target)
    local shield_hit = false
    if target.components.health then
        local source = beam.components.bullet and beam.components.bullet.source
        local dmg_val = (damage and (damage.value or damage)) or 1
        shield_hit = CollisionEffects.applyDamage(target, dmg_val, source)
    end

    local impact_type = (shield_hit or had_shield) and 'shield' or 'hull'
    local impact_radius = best.radius
    if target.components.mineable then
        impact_radius = target.components.collidable.radius
    elseif impact_type == 'shield' then
        impact_radius = best.radius
    else
        impact_radius = target.components.collidable.radius or 10
    end

    local impact_config = nil
    if beam.components and beam.components.bullet then
        impact_config = beam.components.bullet.impact
    end

    Effects.spawnImpact(impact_type, ex, ey, impact_radius, best.hx, best.hy, impact_angle, impact_config, renderable.props.kind, target)
end

return BeamHandler
