local Equipment = {}
Equipment.__index = Equipment

function Equipment.new(args)
    local equipment = setmetatable({}, Equipment)
    args = args or {}
    equipment.turrets = args.turrets or {}
    equipment.grid = args.grid or {}
    return equipment
end

return Equipment