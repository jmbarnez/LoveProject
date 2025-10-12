-- Station Collision Handler
-- Handles collision resolution specific to stations and station shields

local StationShields = require("src.systems.collision.station_shields")
local Effects = require("src.systems.effects")

local StationCollision = {}

-- Check if entity is a station
function StationCollision.isStation(entity)
    return entity.tag == "station" or 
           (entity.components and entity.components.station)
end

-- Handle station shield collision
function StationCollision.handleStationShieldCollision(entity1, entity2)
    return StationShields.handleStationShieldCollision(entity1, entity2)
end

-- Handle station collision with other entities
function StationCollision.handleStationCollision(station, other, collision, dt)
    if not StationCollision.isStation(station) then return end
    
    -- Check for station shield special handling
    if StationCollision.handleStationShieldCollision(station, other) then
        -- Create explosion effects immediately
        local ex = (other.isEnemy and other or station).components.position.x
        local ey = (other.isEnemy and other or station).components.position.y
        if Effects and Effects.spawnSonicBoom then
            local enemy = other.isEnemy and other or station
            local col = enemy.components.collidable
            local shipRadius = (col and col.radius) or 15
            local sizeScale = math.max(0.3, math.min(2.0, shipRadius / 15))
            Effects.spawnSonicBoom(ex, ey, { color = {1.0, 0.75, 0.25, 0.5}, sizeScale = sizeScale })
        end
        return true -- Skip normal collision resolution
    end
    
    -- For normal station collisions, use standard ship collision handling
    local ShipCollision = require("src.systems.collision.handlers.ship_collision")
    ShipCollision.handleShipToShip(station, other, collision, dt)
    
    return false -- Continue with normal collision resolution
end

return StationCollision
