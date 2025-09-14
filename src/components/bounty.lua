local Bounty = {}
Bounty.__index = Bounty

function Bounty.new(args)
    local bounty = {}
    setmetatable(bounty, Bounty)
    bounty.value = args.value or 0
    return bounty
end

return Bounty