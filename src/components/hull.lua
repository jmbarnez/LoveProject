local Hull = {}
Hull.__index = Hull

function Hull.new(values)
    local instance = setmetatable({}, Hull)
    -- Basic hull integrity
    instance.hp = (values and values.hp) or 100
    instance.maxHP = (values and values.maxHP) or 100
    return instance
end

return Hull
