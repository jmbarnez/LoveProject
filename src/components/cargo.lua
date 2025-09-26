local Util = require("src.core.util")

local Cargo = {}
Cargo.__index = Cargo

local DEFAULT_CAPACITY = math.huge

function Cargo.new(props)
    props = props or {}
    local self = setmetatable({}, Cargo)
    self.capacity = props.capacity or DEFAULT_CAPACITY
    self.stackLimit = props.stackLimit or math.huge
    self.massLimit = props.massLimit or nil
    self.currentMass = 0
    self.stacks = {}
    self.order = {}
    return self
end

function Cargo:clone()
    local copy = Cargo.new({
        capacity = self.capacity,
        stackLimit = self.stackLimit,
        massLimit = self.massLimit
    })
    copy.currentMass = self.currentMass
    for _, stack in ipairs(self.order) do
        local entry = self.stacks[stack]
        copy.stacks[stack] = {
            id = entry.id,
            qty = entry.qty,
            meta = entry.meta and Util.deepCopy(entry.meta) or nil
        }
        table.insert(copy.order, stack)
    end
    return copy
end

function Cargo:serialize()
    local data = {
        capacity = self.capacity,
        stackLimit = self.stackLimit,
        massLimit = self.massLimit,
        currentMass = self.currentMass,
        order = Util.deepCopy(self.order),
        stacks = {}
    }
    for slot, entry in pairs(self.stacks) do
        data.stacks[slot] = {
            id = entry.id,
            qty = entry.qty,
            meta = entry.meta and Util.deepCopy(entry.meta) or nil
        }
    end
    return data
end

function Cargo.deserialize(data)
    local component = Cargo.new({
        capacity = data and data.capacity,
        stackLimit = data and data.stackLimit,
        massLimit = data and data.massLimit
    })
    component.currentMass = data and data.currentMass or 0
    if data and type(data.stacks) == "table" then
        for slot, entry in pairs(data.stacks) do
            component.stacks[slot] = {
                id = entry.id,
                qty = entry.qty,
                meta = entry.meta and Util.deepCopy(entry.meta) or nil
            }
        end
    end
    if data and type(data.order) == "table" then
        component.order = Util.deepCopy(data.order)
    else
        for slot, _ in pairs(component.stacks) do
            table.insert(component.order, slot)
        end
    end
    return component
end

local function normalizeId(id)
    if type(id) ~= "string" or id == "" then
        return nil
    end
    return id
end

local function uniqueSlot(base, existing)
    local slot = base
    local index = 1
    while existing[slot] do
        slot = string.format("%s_%d", base, index)
        index = index + 1
    end
    return slot
end

function Cargo:_ensureSlot(slot)
    if not self.stacks[slot] then
        self.stacks[slot] = { id = nil, qty = 0, meta = nil }
        table.insert(self.order, slot)
    end
    return self.stacks[slot]
end

function Cargo:add(itemId, qty, meta, opts)
    itemId = normalizeId(itemId)
    if not itemId then return false end
    qty = qty or 1
    if qty <= 0 then return false end

    opts = opts or {}
    if opts.slot then
        local entry = self:_ensureSlot(opts.slot)
        entry.id = itemId
        entry.qty = (entry.qty or 0) + qty
        entry.meta = meta and Util.deepCopy(meta) or entry.meta
        return opts.slot
    end

    if meta then
        local lastSlot
        for _ = 1, qty do
            local slotId = uniqueSlot(itemId, self.stacks)
            local entry = self:_ensureSlot(slotId)
            entry.id = itemId
            entry.qty = 1
            entry.meta = Util.deepCopy(meta)
            lastSlot = slotId
        end
        return lastSlot
    end

    for _, stackSlot in ipairs(self.order) do
        local entry = self.stacks[stackSlot]
        if entry.id == itemId and (entry.qty or 0) < self.stackLimit and entry.meta == nil then
            local available = self.stackLimit - entry.qty
            local toAdd = math.min(qty, available)
            entry.qty = entry.qty + toAdd
            qty = qty - toAdd
            if qty <= 0 then
                return stackSlot
            end
        end
    end

    local lastSlot
    while qty > 0 do
        local slotId = uniqueSlot(itemId, self.stacks)
        local entry = self:_ensureSlot(slotId)
        entry.id = itemId
        local toAdd = math.min(qty, self.stackLimit)
        entry.qty = toAdd
        entry.meta = nil
        qty = qty - toAdd
        lastSlot = slotId
    end
    return lastSlot
end

function Cargo:extract(itemId)
    itemId = normalizeId(itemId)
    if not itemId then return nil end
    for idx = #self.order, 1, -1 do
        local slot = self.order[idx]
        local entry = self.stacks[slot]
        if entry.id == itemId then
            entry.qty = (entry.qty or 0) - 1
            local meta = entry.meta and Util.deepCopy(entry.meta) or nil
            if entry.meta then
                self.stacks[slot] = nil
                table.remove(self.order, idx)
            elseif entry.qty <= 0 then
                self.stacks[slot] = nil
                table.remove(self.order, idx)
            end
            return meta or true
        end
    end
    return nil
end

function Cargo:remove(itemId, qty)
    itemId = normalizeId(itemId)
    if not itemId then return false end
    qty = qty or 1
    if qty <= 0 then return true end

    local remaining = qty
    for idx = #self.order, 1, -1 do
        local slot = self.order[idx]
        local entry = self.stacks[slot]
        if entry.id == itemId then
            local take = math.min(entry.qty or 0, remaining)
            entry.qty = entry.qty - take
            remaining = remaining - take
            if entry.qty <= 0 then
                self.stacks[slot] = nil
                table.remove(self.order, idx)
            end
            if remaining <= 0 then break end
        end
    end
    return remaining <= 0
end

function Cargo:getQuantity(itemId)
    itemId = normalizeId(itemId)
    if not itemId then return 0 end
    local total = 0
    for _, slot in ipairs(self.order) do
        local entry = self.stacks[slot]
        if entry.id == itemId then
            total = total + (entry.qty or 0)
        end
    end
    return total
end

function Cargo:has(itemId, qty)
    return self:getQuantity(itemId) >= (qty or 1)
end

function Cargo:iterate(cb)
    for _, slot in ipairs(self.order) do
        local entry = self.stacks[slot]
        if entry and entry.id then
            cb(slot, entry)
        end
    end
end

function Cargo:clear()
    self.stacks = {}
    self.order = {}
    self.currentMass = 0
end

function Cargo:toList()
    local list = {}
    self:iterate(function(_, entry)
        table.insert(list, {
            id = entry.id,
            qty = entry.qty,
            meta = entry.meta and Util.deepCopy(entry.meta) or nil,
        })
    end)
    return list
end

return Cargo
