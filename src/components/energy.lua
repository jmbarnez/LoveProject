local Energy = {}
Energy.__index = Energy

function Energy.new(values)
    local instance = setmetatable({}, Energy)
    -- Energy/capacitor system
    instance.energy = (values and values.energy) or 0
    instance.maxEnergy = (values and values.maxEnergy) or 100
    return instance
end

return Energy
