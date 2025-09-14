local LootContainer = {}
LootContainer.__index = LootContainer

function LootContainer.new(props)
    local self = setmetatable({}, LootContainer)
    self.items = props.items or {}
    self.entity = props.entity
    return self
end

return LootContainer
