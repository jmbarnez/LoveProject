-- Station collision listener
-- Handles shield bubble instant-kill interactions and associated FX.

local CollisionEvents = require("src.systems.collision.collision_events")
local StationShields = require("src.systems.collision.station_shields")
local Effects = require("src.systems.effects")

local function isStation(entity)
    return entity
        and (entity.tag == "station" or (entity.components and entity.components.station))
end

local function spawnShieldImpactFx(station, other)
    if not Effects or not Effects.spawnSonicBoom then
        return
    end

    local target = (other and other.isEnemy) and other or station
    local pos = target and target.components and target.components.position
    if not pos then
        return
    end

    local col = target.components.collidable
    local shipRadius = (col and col.radius) or 15
    local sizeScale = math.max(0.3, math.min(2.0, shipRadius / 15))

    Effects.spawnSonicBoom(pos.x, pos.y, {
        color = { 1.0, 0.75, 0.25, 0.5 },
        sizeScale = sizeScale,
    })
end

CollisionEvents.on("pre_resolve", function(context)
    if not context then
        return
    end

    local entityA = context.entityA
    local entityB = context.entityB
    if not entityA or not entityB then
        return
    end

    local station, other
    if isStation(entityA) then
        station, other = entityA, entityB
    elseif isStation(entityB) then
        station, other = entityB, entityA
    else
        return
    end

    if StationShields.handleStationShieldCollision(station, other) then
        spawnShieldImpactFx(station, other)
        context.cancel = true
        context.resolved = false
    end
end)
