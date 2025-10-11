local Wreckage = {}
Wreckage.__index = Wreckage

function Wreckage.new(props)
    local self = setmetatable({}, Wreckage)
    self.resourceType = props.resourceType or "scraps"
    self.salvageAmount = props.salvageAmount or 1
    self.maxSalvageAmount = props.maxSalvageAmount or self.salvageAmount
    self.salvageProgress = 0
    self.salvageCycleTime = props.salvageCycleTime or 1.5
    self.isBeingSalvaged = false
    -- Initialize partial salvage tracking fields
    self._partialSalvage = 0
    self._salvageDropped = 0
    return self
end

return Wreckage
