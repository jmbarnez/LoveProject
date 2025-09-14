local Sound = require("src.core.sound")
local Effects = require("src.systems.effects")
local Radius = require("src.systems.collision.radius")
local StationShields = require("src.systems.collision.station_shields")

local TurretEffects = {}

-- Play firing sound effects based on turret type
function TurretEffects.playFiringSound(turret)
    if not turret or not turret.kind then return end

    local x, y = 0, 0
    if turret.owner and turret.owner.components and turret.owner.components.position then
        x = turret.owner.components.position.x
        y = turret.owner.components.position.y
    end

    if turret.kind == "missile" then
        Sound.triggerEvent('weapon_missile_fire', x, y)
    elseif turret.kind == "laser" then
        Sound.triggerEvent('weapon_laser_fire', x, y)
    elseif turret.kind == "gun" or turret.kind == "projectile" then
        Sound.triggerEvent('weapon_gun_fire', x, y)
    elseif turret.kind == "mining_laser" then
        Sound.triggerEvent('weapon_mining_laser', x, y)
    elseif turret.kind == "salvaging_laser" then
        Sound.triggerEvent('weapon_salvaging_laser', x, y)
    end
end

-- Create muzzle flash effects
function TurretEffects.createMuzzleFlash(turret, x, y, angle)
    if not turret.muzzleFlash then return end

    -- TODO: Implement muzzle flash particle effects
    -- This would create temporary visual effects at the firing point
end

-- Create tracer effects for projectiles
function TurretEffects.createTracerEffect(turret, startX, startY, endX, endY)
    if not turret.tracer then return end

    -- TODO: Implement tracer rendering
    -- This would draw the projectile trail/beam
end

-- Create impact effects
function TurretEffects.createImpactEffect(turret, x, y, target, impactType)
    -- If turret has no impact config and there's no global Effects.spawnImpact, nothing to do
    local impactConfig = (turret and turret.impact) or nil
    if not Effects or not Effects.spawnImpact then return end

    if not target or not target.components or not target.components.position then
        return
    end

    local ex = target.components.position.x
    local ey = target.components.position.y

    -- Determine effective radius for impact visuals
    local targetRadius = Radius.calculateEffectiveRadius and Radius.calculateEffectiveRadius(target) or (target.components.collidable and target.components.collidable.radius) or 10

    -- Determine whether the hit affected shields
    local hasShields = false
    if target.components and target.components.health and (target.components.health.shield or 0) > 0 then
        hasShields = true
    elseif StationShields and StationShields.hasActiveShield and StationShields.isStation(target) and StationShields.hasActiveShield(target) then
        hasShields = true
    end

    local impactKind = hasShields and 'shield' or 'hull'
    local impactAngle = 0
    if ex and ey and x and y then
        impactAngle = math.atan2(y - ey, x - ex)
    end

    -- Pass through bullet kind for styling (laser/mining/missile)
    local bulletKind = (turret and turret.kind) or nil

    Effects.spawnImpact(impactKind, ex, ey, targetRadius, x, y, impactAngle, impactConfig, bulletKind, target)
end

-- Handle heat effect visuals
function TurretEffects.updateHeatEffects(turret, dt)
    if not turret.currentHeat or turret.currentHeat <= 0 then return end

    -- TODO: Add heat distortion, glow effects, etc.
    -- Visual feedback for turret heat state
end

-- Handle beam rendering for continuous weapons
function TurretEffects.renderBeam(turret, startX, startY, endX, endY, hitTarget)
    if turret.kind ~= "laser" and turret.kind ~= "mining_laser" and turret.kind ~= "salvaging_laser" then
        return
    end

    if not turret.tracer then return end

    local color = turret.tracer.color or {1, 1, 1, 0.8}
    local width = turret.tracer.width or 2
    local coreRadius = turret.tracer.coreRadius or 1

    -- Draw beam core
    love.graphics.setColor(color[1], color[2], color[3], color[4])
    love.graphics.setLineWidth(width)
    love.graphics.line(startX, startY, endX, endY)

    -- Draw beam core (brighter center)
    if coreRadius > 0 then
        love.graphics.setColor(color[1] * 1.2, color[2] * 1.2, color[3] * 1.2, color[4] * 0.8)
        love.graphics.setLineWidth(coreRadius)
        love.graphics.line(startX, startY, endX, endY)
    end

    -- Reset graphics state
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

-- Handle special effects for different weapon types
function TurretEffects.handleSpecialEffects(turret, target, hitX, hitY)
    if turret.kind == "mining_laser" and target and target.components and target.components.mineable then
        TurretEffects.createMiningParticles(hitX, hitY)
    elseif turret.kind == "salvaging_laser" and target and target.components and target.components.wreckage then
        TurretEffects.createSalvageParticles(hitX, hitY)
    end
end

-- Create mining particle effects
function TurretEffects.createMiningParticles(x, y)
    -- TODO: Create sparks, debris, and mining-specific effects
end

-- Create salvage particle effects
function TurretEffects.createSalvageParticles(x, y)
    -- TODO: Create salvage beam effects and collected material visuals
end

return TurretEffects