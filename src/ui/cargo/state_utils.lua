local CargoStateUtils = {}

function CargoStateUtils.snapshot(player)
    if not player or not player.components or not player.components.cargo then
        return nil
    end

    local cargo = player.components.cargo
    local snapshot = {}

    cargo:iterate(function(slot, entry)
        local metaSnapshot = nil
        if entry.meta then
            metaSnapshot = {
                instanceId = entry.meta.instanceId,
                baseId = entry.meta.baseId,
            }
        end

        snapshot[#snapshot + 1] = {
            slot = slot,
            id = entry.id,
            qty = entry.qty,
            meta = metaSnapshot,
        }
    end)

    table.sort(snapshot, function(a, b)
        if a.id == b.id then
            return a.slot < b.slot
        end
        return a.id < b.id
    end)

    return snapshot
end

function CargoStateUtils.hasChanged(previous, current)
    if previous == nil and current == nil then
        return false
    end

    if previous == nil or current == nil then
        return true
    end

    if #previous ~= #current then
        return true
    end

    for index = 1, #previous do
        local a = previous[index]
        local b = current[index]

        if not a or not b then
            return true
        end

        if a.id ~= b.id or a.qty ~= b.qty then
            return true
        end

        local metaA = a.meta
        local metaB = b.meta

        if (metaA and not metaB) or (metaB and not metaA) then
            return true
        end

        if metaA and metaB then
            if metaA.instanceId ~= metaB.instanceId or metaA.baseId ~= metaB.baseId then
                return true
            end
        end
    end

    return false
end

return CargoStateUtils
