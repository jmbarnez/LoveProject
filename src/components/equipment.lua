local Equipment = {}
Equipment.__index = Equipment

function Equipment.new(args)
    local equipment = {}
    setmetatable(equipment, Equipment)
    equipment.turrets = args.turrets or {}
    return equipment
end

return Equipment