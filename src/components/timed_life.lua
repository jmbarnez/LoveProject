local TimedLife = {}
TimedLife.__index = TimedLife

function TimedLife.new(timer)
    local instance = setmetatable({}, TimedLife)
    instance.timer = timer or 0
    instance.life = timer or 0 -- store initial lifetime for rendering fades
    return instance
end

return TimedLife
