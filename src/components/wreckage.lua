local Wreckage = {}
Wreckage.__index = Wreckage

function Wreckage.new(props)
    local self = setmetatable({}, Wreckage)
    self.resourceType = props.resourceType or "scraps"
    self.salvageAmount = props.salvageAmount or 1
    self.salvageProgress = 0
    self.salvageCycleTime = props.salvageCycleTime or 1.5
    self.isBeingSalvaged = false
    return self
end

return Wreckage