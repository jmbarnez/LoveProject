local Settings = require("src.core.settings")
local Log = require("src.core.log")

local Hotbar = {}

-- Runtime state for hold/toggle actions
Hotbar.state = {
    active = {
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

-- Populate hotbar from player's equipped turrets in the grid
function Hotbar.populateFromPlayer(player, newModuleId, slotNum)
    if not player or not player.components or not player.components.equipment or not player.components.equipment.grid then
        return
    end

    -- Ensure slots are initialized
    if not Hotbar.slots then
        Hotbar.slots = {
            { item = nil },
            { item = nil },
            { item = nil },
            { item = nil },
            { item = nil },
        }
    end

    local previous = {}
    for i = 1, #Hotbar.slots do
        previous[i] = Hotbar.slots[i].item
        Hotbar.slots[i].item = nil
    end

    local forcedAssignment = {}
    local seenTurrets = {}

    if player.components and player.components.equipment and player.components.equipment.grid then
        for _, gridData in ipairs(player.components.equipment.grid) do
            if gridData.type == "turret" and gridData.module then
                local key = "turret_slot_" .. tostring(gridData.slot)
                seenTurrets[key] = true
                local preferred = tonumber(gridData.hotbarSlot)
                if preferred and preferred >= 1 and preferred <= #Hotbar.slots then
                    if not forcedAssignment[preferred] then
                        forcedAssignment[preferred] = key
                        Hotbar.slots[preferred].item = key
                    end
                end
            end
        end
    end

    local function place(itemKey)
        if not itemKey then return false end
        for i = 1, #Hotbar.slots do
            if Hotbar.slots[i].item == nil then
                Hotbar.slots[i].item = itemKey
                return true
            end
        end
        return false
    end

    -- Place any remaining turrets that haven't been assigned yet
    for key in pairs(seenTurrets) do
        local exists = false
        for i = 1, #Hotbar.slots do
            if Hotbar.slots[i].item == key then
                exists = true
                break
            end
        end
        if not exists then
            place(key)
        end
    end

    -- Normalize to remove any duplicates
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
            if type(item) == 'string' and (item:match('^turret_slot_%d+$') or item:match('^module_slot_%d+$')) then
                -- Handle turret firing based on fireMode
                local idx = tonumber(item:match('^turret_slot_(%d+)$') or item:match('^module_slot_(%d+)$'))
                if idx then
                    -- Get the turret to check its fireMode
                    local Turret = require("src.systems.turret.core")
                    local turret = Turret.getTurretBySlot(player, idx)
                    if turret then
                        if turret.fireMode == "automatic" then
                            -- For automatic mode: toggle the autoFire state
                            Hotbar.state.active.turret_slots = Hotbar.state.active.turret_slots or {}
                            Hotbar.state.active.turret_slots[idx] = not Hotbar.state.active.turret_slots[idx]
                        else
                            -- For manual mode: set firing to true (will be cleared on key release)
                            Hotbar.state.active.turret_slots = Hotbar.state.active.turret_slots or {}
                            Hotbar.state.active.turret_slots[idx] = true
                        end
                    end
                end
            else
                Hotbar.activate(i, player)
            end
            return
        end
    end
end

-- Handle keyboard releases for manual mode turrets
function Hotbar.keyreleased(key, player)
    for i, slot in ipairs(Hotbar.slots) do
        local bound = Hotbar.getSlotKey(i)
        if key == bound then
            local item = slot.item
            if type(item) == 'string' and (item:match('^turret_slot_%d+$') or item:match('^module_slot_%d+$')) then
                local idx = tonumber(item:match('^turret_slot_(%d+)$') or item:match('^module_slot_(%d+)$'))
                if idx then
                    -- Get the turret to check its fireMode
                    local Turret = require("src.systems.turret.core")
                    local turret = Turret.getTurretBySlot(player, idx)
                    if turret and turret.fireMode == "manual" then
                        -- For manual mode: clear the firing state on key release
                        Hotbar.state.active.turret_slots = Hotbar.state.active.turret_slots or {}
                        Hotbar.state.active.turret_slots[idx] = false
                    end
                end
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
            if type(slot.item) == 'string' and slot.item:match('^turret_slot_%d+$') then
                local idx = tonumber(slot.item:match('^turret_slot_(%d+)$'))
                if idx then
                    -- Get the turret to check its fireMode
                    local Turret = require("src.systems.turret.core")
                    local turret = Turret.getTurretBySlot(player, idx)
                    if turret then
                        if turret.fireMode == "automatic" then
                            -- For automatic mode: toggle the autoFire state
                            Hotbar.state.active.turret_slots = Hotbar.state.active.turret_slots or {}
                            Hotbar.state.active.turret_slots[idx] = not Hotbar.state.active.turret_slots[idx]
                        else
                            -- For manual mode: set firing to true (will be cleared on mouse release)
                            Hotbar.state.active.turret_slots = Hotbar.state.active.turret_slots or {}
                            Hotbar.state.active.turret_slots[idx] = true
                        end
                    end
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
            if type(slot.item) == 'string' and slot.item:match('^turret_slot_%d+$') then
                local idx = tonumber(slot.item:match('^turret_slot_(%d+)$'))
                if idx then
                    -- Get the turret to check its fireMode
                    local Turret = require("src.systems.turret.core")
                    local turret = Turret.getTurretBySlot(player, idx)
                    if turret and turret.fireMode == "manual" then
                        -- For manual mode: clear the firing state on mouse release
                        Hotbar.state.active.turret_slots = Hotbar.state.active.turret_slots or {}
                        Hotbar.state.active.turret_slots[idx] = false
                    end
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
    end
end

return Hotbar
