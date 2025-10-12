local HotbarSystem = require("src.systems.hotbar")

local ShipUtils = {}

function ShipUtils.resolveModuleDisplayName(entry)
    if not entry then return nil end
    local module = entry.module
    if module then
        return module.proceduralName or module.name or entry.id
    end
    return entry.id
end

function ShipUtils.resolveSlotType(slotData)
    if not slotData then return nil end
    return slotData.baseType or slotData.type
end

function ShipUtils.resolveSlotHeaderLabel(slotType)
    if slotType == "turret" then
        return "Turrets:"
    elseif slotType == "shield" then
        return "Shield Slots"
    elseif slotType == "utility" then
        return "Utility Slots"
    end
    return "Module Slots"
end

function ShipUtils.buildHotbarPreview(player, gridOverride)
    local slots = HotbarSystem.slots or {}
    local totalSlots = #slots
    local preview = {}
    local grid = gridOverride or (player.components and player.components.equipment and player.components.equipment.grid) or {}

    for i = 1, totalSlots do
        local slot = slots[i]
        if slot and slot.item then
            local label = slot.item
            local idx = tostring(slot.item):match("^slot_(%d+)$")
            if idx then
                idx = tonumber(idx)
                if grid[idx] then
                    label = ShipUtils.resolveModuleDisplayName(grid[idx]) or label
                end
            end
            preview[i] = {
                item = slot.item,
                label = label,
                origin = "actual",
                gridIndex = idx
            }
        end
    end

    local forced = {}
    local autos = {}

    for _, gridData in ipairs(grid) do
        if gridData.type == "weapon" and gridData.module then
            local entry = {
                key = "slot_" .. tostring(gridData.slot),
                label = ShipUtils.resolveModuleDisplayName(gridData) or ("Turret " .. tostring(gridData.slot)),
                origin = "auto",
                gridIndex = gridData.slot
            }
            local preferred = tonumber(gridData.hotbarSlot)
            if preferred and preferred >= 1 and preferred <= totalSlots then
                forced[preferred] = forced[preferred] or {
                    key = entry.key,
                    label = entry.label,
                    origin = "preferred",
                    gridIndex = entry.gridIndex
                }
            else
                table.insert(autos, entry)
            end
        end
    end

    for slotIndex, entry in pairs(forced) do
        if slotIndex >= 1 and slotIndex <= totalSlots then
            preview[slotIndex] = {
                item = entry.key,
                label = entry.label,
                origin = entry.origin,
                gridIndex = entry.gridIndex
            }
        end
    end

    local function placeEntry(entry)
        for i = 1, totalSlots do
            if preview[i] and preview[i].item == entry.key then
                preview[i] = {
                    item = entry.key,
                    label = entry.label,
                    origin = entry.origin or "auto",
                    gridIndex = entry.gridIndex
                }
                return
            end
        end
        for i = 1, totalSlots do
            if not preview[i] or not preview[i].item then
                preview[i] = {
                    item = entry.key,
                    label = entry.label,
                    origin = entry.origin or "auto",
                    gridIndex = entry.gridIndex
                }
                return
            end
        end
    end

    for _, entry in ipairs(autos) do
        placeEntry(entry)
    end

    return preview
end

return ShipUtils
