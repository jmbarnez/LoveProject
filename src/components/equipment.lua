local Equipment = {}
Equipment.__index = Equipment

local function normalize_slot(slot)
    slot = slot or {}
    return {
        id = slot.id,
        module = slot.module,
        enabled = slot.enabled or false,
        slot = slot.slot,
        type = slot.type,
        baseType = slot.baseType,
        label = slot.label,
        icon = slot.icon,
        meta = slot.meta,
    }
end

function Equipment.new(args)
    args = args or {}
    local equipment = setmetatable({}, Equipment)
    equipment.turrets = args.turrets or {}
    equipment.grid = {}

    if args.grid then
        for _, slot in ipairs(args.grid) do
            equipment:addSlot(slot)
        end
    end

    return equipment
end

function Equipment:addSlot(slot)
    local normalized = normalize_slot(slot)
    normalized.slot = normalized.slot or (#self.grid + 1)
    table.insert(self.grid, normalized)
    return normalized
end

return Equipment
