local Settings = require("src.core.settings")
local Log = require("src.core.log")

local Hotbar = {}

-- Runtime state for hold/toggle actions
Hotbar.state = {
    active = {
        shield = false,
        turret_slots = {},
    }
}

-- Ensure each item appears at most once across all hotbar slots
function Hotbar.normalizeSlots()
    if not Hotbar.slots then return end
    local seen = {}
    for i, slot in ipairs(Hotbar.slots) do
        local it = slot.item
        if it ~= nil then
            if seen[it] then
                -- Remove duplicate occurrences, keep the first
                Hotbar.slots[i].item = nil
            else
                seen[it] = true
            end
        end
    end
end

function Hotbar.load()
    -- Initialize slots and load items from settings
    Hotbar.slots = {
        { item = nil },
        { item = nil },
        { item = nil },
        { item = nil },
        { item = nil },
    }

    local hb = Settings.getHotbarSettings and Settings.getHotbarSettings()
    if hb and type(hb.items) == "table" then
        for i = 1, math.min(#Hotbar.slots, #hb.items) do
            local it = hb.items[i]
            Hotbar.slots[i].item = (it == 'boost') and nil or it
        end
        -- Deduplicate on load to avoid conflicting bindings (e.g., shield on E and R)
        Hotbar.normalizeSlots()
    end
end

function Hotbar.save()
    -- Persist current hotbar slot items into settings
    local items = {}
    for i, slot in ipairs(Hotbar.slots or {}) do
        items[i] = slot.item
    end
    local hb = Settings.getHotbarSettings and Settings.getHotbarSettings() or {}
    hb.items = items
    if Settings.setHotbarSettings then Settings.setHotbarSettings(hb) end
    if Settings.save then Settings.save() end
end

function Hotbar.update(dt)
    -- Update hotbar logic, e.g., cooldowns
end

function Hotbar.draw()
    -- The drawing logic will be in src/ui/hud/hotbar.lua
end

-- Populate hotbar from player's equipped turrets: slot1=LMB for turret 1, slot2=RMB shield,
-- subsequent keys (Q,E,R,...) map to turret slots 2..N.
function Hotbar.populateFromPlayer(player)
    if not player or not player.components or not player.components.equipment or not player.components.equipment.turrets then
        return
    end

    -- Ensure turret_slot_1 and shield are always in the first two slots
    Hotbar.slots[1].item = "turret_slot_1"
    Hotbar.slots[2].item = "shield"

    -- Find already assigned turret slots to avoid re-assigning them
    local assignedTurretSlots = {}
    for i = 1, #Hotbar.slots do
        local item = Hotbar.slots[i].item
        if type(item) == 'string' and item:match('^turret_slot_(%d+)$') then
            local slotNum = tonumber(item:match('^turret_slot_(%d+)$'))
            assignedTurretSlots[slotNum] = true
        end
    end

    -- Find the next available hotbar slot
    local nextHotbar = 3
    while Hotbar.slots[nextHotbar] and Hotbar.slots[nextHotbar].item do
        nextHotbar = nextHotbar + 1
    end

    -- Iterate through player's turrets and assign unassigned ones to hotbar
    for _, tslot in ipairs(player.components.equipment.turrets) do
        if tslot and tslot.slot and tslot.turret and not assignedTurretSlots[tslot.slot] then
            if nextHotbar <= #Hotbar.slots then
                Hotbar.slots[nextHotbar].item = "turret_slot_" .. tostring(tslot.slot)
                assignedTurretSlots[tslot.slot] = true -- Mark as assigned
                -- Find next available slot for the next turret
                repeat
                    nextHotbar = nextHotbar + 1
                until nextHotbar > #Hotbar.slots or not Hotbar.slots[nextHotbar].item
            else
                break -- No more available hotbar slots
            end
        end
    end

    -- Persist the changes
    -- Normalize first to guarantee uniqueness (no duplicate shield or turret slots)
    Hotbar.normalizeSlots()
    if Hotbar.save then Hotbar.save() end
end

-- Resolve the key bound to a given hotbar index from Settings
function Hotbar.getSlotKey(i)
    local km = Settings.getKeymap and Settings.getKeymap() or {}
    return km["hotbar_" .. tostring(i)]
end

function Hotbar.isActive(action)
    if not action then return false end
    if Hotbar.state.active[action] == true then return true end
    -- turret_slot_N actions
    local idx = tostring(action):match("^turret_slot_(%d+)$")
    if idx then
        Hotbar.state.active.turret_slots = Hotbar.state.active.turret_slots or {}
        return not not Hotbar.state.active.turret_slots[tonumber(idx)]
    end
    return false
end

-- Handle keyboard presses routed from Input
function Hotbar.keypressed(key, player)
    for i, slot in ipairs(Hotbar.slots) do
        local bound = Hotbar.getSlotKey(i)
        if key == bound then
            local item = slot.item
            -- No fallback behavior - only process if there's an item in the slot
            if item == "shield" then
                if bound ~= "mouse2" then
                    Hotbar.state.active.shield = not Hotbar.state.active.shield
                end
            elseif type(item) == 'string' and item:match('^turret_slot_%d+$') then
                -- Toggle specific turret slot on non-mouse hotkeys
                if bound ~= "mouse1" and bound ~= "mouse2" then
                    local idx = tonumber(item:match('^turret_slot_(%d+)$'))
                    if idx then
                        Hotbar.state.active.turret_slots = Hotbar.state.active.turret_slots or {}
                        Hotbar.state.active.turret_slots[idx] = not Hotbar.state.active.turret_slots[idx]
                    end
                end
            else
                Hotbar.activate(i, player)
            end
            return
        end
    end
end

-- Handle mouse button presses mapped to hotbar slots
function Hotbar.mousepressed(x, y, button, player)
    local HotbarSelection = require("src.ui.hud.hotbar_selection")
    if HotbarSelection.mousepressed(x, y, button) then return true end

    local btnKey = (button == 1) and "mouse1" or (button == 2) and "mouse2" or nil
    if not btnKey then return false end
    for i, slot in ipairs(Hotbar.slots) do
        local bound = Hotbar.getSlotKey(i)
        if bound == btnKey then
            if slot.item == "shield" then
                Hotbar.state.active.shield = true
                return true
            elseif type(slot.item) == 'string' and slot.item:match('^turret_slot_%d+$') then
                local idx = tonumber(slot.item:match('^turret_slot_(%d+)$'))
                if idx then
                    Hotbar.state.active.turret_slots = Hotbar.state.active.turret_slots or {}
                    Hotbar.state.active.turret_slots[idx] = true
                    return true
                end
            else
                -- One-shot actions (none currently)
                Hotbar.activate(i, player)
                return true
            end
        end
    end
    return false
end

-- Handle mouse button release to clear hold actions
function Hotbar.mousereleased(button, player)
    local btnKey = (button == 1) and "mouse1" or (button == 2) and "mouse2" or nil
    if not btnKey then return false end
    for i, slot in ipairs(Hotbar.slots) do
        local bound = Hotbar.getSlotKey(i)
        if bound == btnKey then
            if slot.item == "shield" then
                Hotbar.state.active.shield = false
                return true
            elseif type(slot.item) == 'string' and slot.item:match('^turret_slot_%d+$') then
                local idx = tonumber(slot.item:match('^turret_slot_(%d+)$'))
                if idx then
                    Hotbar.state.active.turret_slots = Hotbar.state.active.turret_slots or {}
                    Hotbar.state.active.turret_slots[idx] = false
                    return true
                end
            else
                -- no-op for one-shot actions
                return false
            end
        end
    end
    return false
end

function Hotbar.activate(slotIndex, player)
    local slot = Hotbar.slots[slotIndex]
    if not slot or not slot.item then return end

    if not player then return end

    if slot.item == "turret" then
        -- Turret activation is handled by state/hold; nothing on tap
    elseif slot.item == "shield" then
        -- Shield is handled via hold/toggle state
    end
end

return Hotbar
