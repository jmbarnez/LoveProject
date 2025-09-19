local ShieldDurability = {}

function ShieldDurability.new()
    return {current_hits = 3, max_hits = 3}
end

function ShieldDurability.reset(durability)
    if durability then
        durability.current_hits = durability.max_hits
    end
end

return ShieldDurability