local Lootable = {}
Lootable.__index = Lootable

function Lootable.new(args)
    args = args or {}
    local lootable = setmetatable({}, Lootable)
    lootable.drops = args.drops or {}
    return lootable
end

return Lootable
