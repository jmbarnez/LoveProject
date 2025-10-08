local Player = {}
Player.__index = Player

function Player.new(values)
    values = values or {}
    local instance = setmetatable({}, Player)
    instance.id = values.id
    instance.faction = values.faction
    instance.isPlayer = values.isPlayer ~= false
    return instance
end

return Player
