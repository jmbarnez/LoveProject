local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local Content = require("src.content.content")
local HotbarSystem = require("src.systems.hotbar")

local HotbarSelection = {}

-- (dash icon removed; boost icon is drawn via Hotbar.drawBoostIcon)

local function drawShieldIcon(x, y, size, active)
  local cx, cy = x + size * 0.5, y + size * 0.5
  local r = size * 0.35
  local base = Theme.colors.info or {0.35, 0.65, 0.95, 1}
  Theme.setColor(Theme.withAlpha(base, active and 0.9 or 0.5))
  love.graphics.circle('fill', cx, cy, r)
  Theme.setColor(Theme.withAlpha({1,1,1,1}, active and 0.35 or 0.2))
  love.graphics.circle('line', cx, cy, r)
  Theme.setColor(Theme.withAlpha({1,1,1,1}, active and 0.6 or 0.3))
  love.graphics.circle('fill', cx + r*0.35, cy - r*0.35, 2)
end

HotbarSelection.visible = false
HotbarSelection.slot = 0
HotbarSelection.items = {}
HotbarSelection.player = nil

local panel = {
    x = 0,
    y = 0,
    w = 200,
    h = 300,
    itemSize = 48,
    itemGap = 10,
    itemsPerRow = 3
}

function HotbarSelection.show(slot, x, y, player)
    -- Build dynamic list of equippable modules from cargo
    local items = {}

    -- Add modules from player's cargo that can be equipped
    if player and player.components and player.components.cargo then
        local Content = require("src.content.content")
        player.components.cargo:iterate(function(slotId, entry)
            if entry.id and entry.qty > 0 then
                local contentData = Content.getItem(entry.id)
                -- Only include items that have a module property (can be equipped)
                if contentData and contentData.module then
                    table.insert(items, entry.id)
                end
            end
        end)
    end

    -- Only show the panel if there are equippable modules available
    if #items > 0 then
        HotbarSelection.visible = true
        HotbarSelection.slot = slot
        HotbarSelection.player = player
        panel.x = x - panel.w / 2
        panel.y = y - panel.h - 20
        HotbarSelection.items = items
    else
        HotbarSelection.hide()
    end
end

function HotbarSelection.hide()
    HotbarSelection.visible = false
end

function HotbarSelection:findAvailableTurretSlot()
    if not HotbarSelection.player or not HotbarSelection.player.components or not HotbarSelection.player.components.equipment then
        return nil
    end

    local equipment = HotbarSelection.player.components.equipment
    if not equipment.turrets then
        return nil
    end

    -- Find an available turret slot
    for i, turretData in ipairs(equipment.turrets) do
        if not turretData.turret or not turretData.enabled then
            return turretData.slot
        end
    end

    return nil -- No available slots
end

function HotbarSelection:equipModuleToSlot(itemId)
    if not HotbarSelection.player or not HotbarSelection.player.equipModule then
        return nil
    end

    -- Find an available equipment slot for this module type
    local Content = require("src.content.content")
    local itemData = Content.getItem(itemId)

    if not itemData or not itemData.module then
        return nil
    end

    local moduleType = itemData.module.type
    local slotType = itemData.module.slot_type or moduleType

    -- Find an available slot of the appropriate type
    if HotbarSelection.player.components and HotbarSelection.player.components.equipment and HotbarSelection.player.components.equipment.grid then
        for i, gridData in ipairs(HotbarSelection.player.components.equipment.grid) do
            if not gridData.module or not gridData.enabled then
                -- Check if this slot can accept this module type
                -- Allow empty slots (type == nil) or slots that match the module type
                if gridData.type == nil or gridData.type == slotType then
                    local success = HotbarSelection.player:equipModule(gridData.slot, itemId)
                    if success then
                        -- Update ship window if it's open to refresh button states
                        local ShipUI = require("src.ui.ship")
                        if ShipUI and ShipUI.visible then
                            local shipInstance = ShipUI.getInstance()
                            if shipInstance and shipInstance.updateDropdowns then
                                shipInstance:updateDropdowns(HotbarSelection.player)
                            end
                        end
                        return "module_slot_" .. tostring(gridData.slot)
                    end
                end
            end
        end
    end

    return nil -- No available slots
end

function HotbarSelection.draw()
    if not HotbarSelection.visible then return end

    Theme.drawGradientGlowRect(panel.x, panel.y, panel.w, panel.h, 4, Theme.colors.bg1, Theme.colors.bg2, Theme.colors.primary, Theme.effects.glowWeak * 0.1)
    Theme.drawEVEBorder(panel.x, panel.y, panel.w, panel.h, 4, Theme.colors.border, 2)

    -- Get the key for the currently selected hotbar slot
    local selectedSlotKey = HotbarSystem.getSlotKey and HotbarSystem.getSlotKey(HotbarSelection.slot) or "?"

    -- Draw slot header with key binding
    local oldFont = love.graphics.getFont()
    if Theme.fonts and Theme.fonts.normal then love.graphics.setFont(Theme.fonts.normal) end
    Theme.setColor(Theme.colors.accent)
    love.graphics.printf("Slot " .. HotbarSelection.slot .. " (" .. selectedSlotKey:upper() .. ")", panel.x, panel.y - 25, panel.w, "center")
    if oldFont then love.graphics.setFont(oldFont) end

    for i, item in ipairs(HotbarSelection.items) do
        local col = (i - 1) % panel.itemsPerRow
        local row = math.floor((i - 1) / panel.itemsPerRow)
        local itemX = panel.x + panel.itemGap + col * (panel.itemSize + panel.itemGap)
        local itemY = panel.y + panel.itemGap + row * (panel.itemSize + panel.itemGap)

        local mx, my = Viewport.getMousePosition()
        local hover = mx > itemX and mx < itemX + panel.itemSize and my > itemY and my < itemY + panel.itemSize
        Theme.setColor(hover and Theme.colors.bg3 or Theme.colors.bg2)
        love.graphics.rectangle("fill", itemX, itemY, panel.itemSize, panel.itemSize)

        -- Draw module icon based on its type
        local Content = require("src.content.content")
        local itemData = Content.getItem(item)

        if itemData and itemData.module then
            local moduleType = itemData.module.type
            if moduleType == "turret" then
                local Hotbar = require("src.ui.hud.hotbar")
                Hotbar.drawTurretIcon(item, itemX + 4, itemY + 4, panel.itemSize - 8)
            elseif moduleType == "shield" then
                -- Draw shield icon
                local Hotbar = require("src.ui.hud.hotbar")
                Hotbar.drawShieldIcon(itemX + 4, itemY + 4, panel.itemSize - 8, true)
            else
                -- Generic module icon
                Theme.setColor(Theme.colors.textSecondary)
                love.graphics.setLineWidth(2)
                love.graphics.rectangle("line", itemX + 8, itemY + 8, panel.itemSize - 16, panel.itemSize - 16)
                love.graphics.circle("fill", itemX + panel.itemSize/2, itemY + panel.itemSize/2, 4)
            end
        else
            -- Fallback icon
            Theme.setColor(Theme.colors.textSecondary)
            love.graphics.rectangle("line", itemX + 8, itemY + 8, panel.itemSize - 16, panel.itemSize - 16)
        end

        Theme.drawEVEBorder(itemX, itemY, panel.itemSize, panel.itemSize, 4, Theme.colors.border, 2)
    end
end

function HotbarSelection.mousepressed(x, y, button)
    if not HotbarSelection.visible then return false end

    if not (x > panel.x and x < panel.x + panel.w and y > panel.y and y < panel.y + panel.h) then
        HotbarSelection.hide()
        return false
    end

    for i, item in ipairs(HotbarSelection.items) do
        local col = (i - 1) % panel.itemsPerRow
        local row = math.floor((i - 1) / panel.itemsPerRow)
        local itemX = panel.x + panel.itemGap + col * (panel.itemSize + panel.itemGap)
        local itemY = panel.y + panel.itemGap + row * (panel.itemSize + panel.itemGap)

        if x > itemX and x < itemX + panel.itemSize and y > itemY and my < itemY + panel.itemSize then
            -- This is a module from cargo - need to equip it first
            local Content = require("src.content.content")
            local itemData = Content.getItem(item)

            if itemData and itemData.module then
                local moduleType = itemData.module.type

                if moduleType == "turret" then
                    -- Equip as turret
                    local availableSlot = HotbarSelection:findAvailableTurretSlot()
                    if availableSlot and HotbarSelection.player.equipTurret then
                        local success = HotbarSelection.player:equipTurret(availableSlot, item)
                        if success then
                            local assignedItem = "turret_slot_" .. tostring(availableSlot)

                            -- Record old slot index before clearing
                            local oldSlotIndex = nil
                            -- Check if the item is already in another slot
                            for j, slot in ipairs(HotbarSystem.slots) do
                                if slot.item == item then
                                    oldSlotIndex = j
                                    slot.item = nil
                                end
                            end

                            HotbarSystem.slots[HotbarSelection.slot].item = assignedItem
                            if HotbarSystem.save then HotbarSystem.save() end

                            -- Also set the hotbarSlot value on the grid data for consistency with ship UI
                            if HotbarSelection.player and HotbarSelection.player.components and HotbarSelection.player.components.equipment and HotbarSelection.player.components.equipment.grid then
                                local idx = tonumber(assignedItem:match('^turret_slot_(%d+)$') or assignedItem:match('^module_slot_(%d+)$'))
                                if idx then
                                    for i, gridData in ipairs(HotbarSelection.player.components.equipment.grid) do
                                        if gridData.slot == idx then
                                            gridData.hotbarSlot = HotbarSelection.slot
                                            break
                                        end
                                    end
                                end
                            end

                            -- If moved to a different hotbar slot with different hotkey, deactivate turret state
                            if oldSlotIndex and oldSlotIndex ~= HotbarSelection.slot then
                                local idx = tonumber(assignedItem:match('^turret_slot_(%d+)$'))
                                local oldKey = HotbarSystem.getSlotKey(oldSlotIndex)
                                local newKey = HotbarSystem.getSlotKey(HotbarSelection.slot)
                                if oldKey ~= newKey then
                                    HotbarSystem.state.active.turret_slots = HotbarSystem.state.active.turret_slots or {}
                                    HotbarSystem.state.active.turret_slots[idx] = false
                                end
                            end
                        end
                    end
                else
                    -- For other module types (shields, etc.), try to equip to appropriate slot
                    local assignedItem = HotbarSelection:equipModuleToSlot(item)
                    if assignedItem then
                        -- Record old slot index before clearing
                        local oldSlotIndex = nil
                        -- Check if the item is already in another slot
                        for j, slot in ipairs(HotbarSystem.slots) do
                            if slot.item == item then
                                oldSlotIndex = j
                                slot.item = nil
                            end
                        end

                        HotbarSystem.slots[HotbarSelection.slot].item = assignedItem
                        if HotbarSystem.save then HotbarSystem.save() end

                        -- Also set the hotbarSlot value on the grid data for consistency with ship UI
                        if HotbarSelection.player and HotbarSelection.player.components and HotbarSelection.player.components.equipment and HotbarSelection.player.components.equipment.grid then
                            local idx = tonumber(assignedItem:match('^turret_slot_(%d+)$') or assignedItem:match('^module_slot_(%d+)$'))
                            if idx then
                                for i, gridData in ipairs(HotbarSelection.player.components.equipment.grid) do
                                    if gridData.slot == idx then
                                        gridData.hotbarSlot = HotbarSelection.slot
                                        break
                                    end
                                end
                            end
                        end
                    end
                end
            end

            HotbarSelection.hide()
            return true
        end
    end

    return true
end

return HotbarSelection
