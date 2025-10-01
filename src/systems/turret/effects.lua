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



-- Create impact effects
function TurretEffects.createImpactEffect(turret, x, y, target, impactType)
    -- If turret has no impact config and there's no global Effects.spawnImpact, nothing to do
    local impactConfig = turret and turret.impact
    if not Effects or not Effects.spawnImpact then return end

    if not target or not target.components or not target.components.position then
        return
    end

    local ex = target.components.position.x
    local ey = target.components.position.y

    -- Determine effective radius for impact visuals
    local targetRadius = Radius.calculateEffectiveRadius and Radius.calculateEffectiveRadius(target)

    -- Determine whether the hit affected shields
    local hasShields = false
    if target.components and target.components.health and target.components.health.shield > 0 then
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
    local bulletKind = turret and turret.kind

    Effects.spawnImpact(impactKind, ex, ey, targetRadius, x, y, impactAngle, impactConfig, bulletKind, target)
end


-- Handle beam rendering for continuous weapons
function TurretEffects.renderBeam(turret, startX, startY, endX, endY, hitTarget)
    if turret.kind ~= "laser" and turret.kind ~= "mining_laser" and turret.kind ~= "salvaging_laser" then
        return
    end

    if not turret.tracer then return end

    local color = turret.tracer.color
    local width = turret.tracer.width
    local coreRadius = turret.tracer.coreRadius

    -- Draw beam core
    love.graphics.setColor(color[1], color[2], color[3], color[4])
    love.graphics.setLineWidth(width)
    love.graphics.line(startX, startY, endX, endY)

    -- Draw beam core (brighter center)
    if coreRadius > 0 then
        love.graphics.setColor(math.min(1, color[1] + 0.2), math.min(1, color[2] + 0.2), math.min(1, color[3] + 0.2), color[4] * 0.9)
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



function TurretEffects.createMiningParticles(x, y)
    for i=1, 6 do
        local a = math.random() * math.pi * 2
        local s = 80 + math.random()*60
        Effects.add({ type='spark', x=x, y=y, vx=math.cos(a)*s, vy=math.sin(a)*s, t=0,
            life=0.3 + math.random()*0.2, color={0.8,0.6,0.3,0.9}, size=2 })
    end
    Effects.add({ type='ring', x=x, y=y, r0=3, r1=20, w0=4, w1=1, t=0, life=0.3, color={0.7,0.5,0.2,0.5} })
end

function TurretEffects.createSalvageParticles(x, y)
    for i=1, 8 do
        local a = math.random() * math.pi * 2
        local s = 50 + math.random()*100
        Effects.add({ type='spark', x=x, y=y, vx=math.cos(a)*s, vy=math.sin(a)*s, t=0,
            life=0.5 + math.random()*0.3, color={0.7,0.7,0.7,0.8}, size=1.5 })
    end
    for i=1,3 do
        local a = math.random()*math.pi*2
        local rr = 5 + math.random()*10
        Effects.add({ type='smoke', x=x+math.cos(a)*rr, y=y+math.sin(a)*rr, r0=4, rg=20, t=0, life=0.6+math.random()*0.4,
            color={0.5,0.5,0.5,0.3} })
    end
end

return TurretEffects
