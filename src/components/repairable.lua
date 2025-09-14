local Repairable = {}
Repairable.__index = Repairable

function Repairable.new(data)
    local self = setmetatable({}, Repairable)

    self.broken = data.broken or false
    self.repairCost = data.repairCost or {}
    self.onRepair = data.onRepair or nil -- Callback function when repaired

    return self
end

return Repairable