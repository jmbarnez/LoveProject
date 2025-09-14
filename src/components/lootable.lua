local Lootable = {}
Lootable.__index = Lootable

function Lootable.new(args)
    local lootable = {}
    setmetatable(lootable, Lootable)
    lootable.drops = args.drops or {}
    return lootable
end

return Lootable