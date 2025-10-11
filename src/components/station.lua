local Station = {}
Station.__index = Station

function Station.new(values)
    values = values or {}
    local instance = setmetatable({}, Station)
    instance.type = values.type
    instance.name = values.name or "Station"
    instance.services = values.services or {}
    instance.description = values.description
    return instance
end

return Station
