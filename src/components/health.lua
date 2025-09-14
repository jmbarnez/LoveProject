local Health = {}
Health.__index = Health

function Health.new(values)
    local instance = setmetatable({}, Health)
    -- Basic hull
    instance.hp = (values and values.hp) or 100
    instance.maxHP = (values and values.maxHP) or 100
    -- Optional shields and capacitor/energy if provided
    instance.shield = (values and values.shield) or 0
    instance.maxShield = (values and values.maxShield) or 0
    instance.energy = (values and values.energy) or 0
    instance.maxEnergy = (values and values.maxEnergy) or 0
    return instance
end

return Health
