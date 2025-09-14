local Util = require("src.core.util")
local SpaceStationSystem = {}

function SpaceStationSystem.update(dt, spaceStation)
  if not spaceStation then return end

  spaceStation.rotation = (spaceStation.rotation or 0) + (spaceStation.rotationSpeed or 0.3) * dt
end

function SpaceStationSystem.isInside(spaceStation, x, y)
    if not spaceStation or not spaceStation.components or not spaceStation.components.position then
        return false
    end
    local sx = spaceStation.components.position.x
    local sy = spaceStation.components.position.y
    -- Use shield radius for weapons disable zone, not physical collidable
    local shieldRadius = (spaceStation.shieldRadius) or 600
    return Util.distance(x, y, sx, sy) <= shieldRadius
end

return SpaceStationSystem
