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
    -- Build dynamic list of available items (only active modules)
    local items = {}

    -- Add equipped active modules from player (turrets and other activatable modules)
    if player and player.components and player.components.equipment and player.components.equipment.grid then
        for _, gridData in ipairs(player.components.equipment.grid) do
          -- Only include active modules that can be activated/used
          if gridData.type == "turret" and gridData.module then
            table.insert(items, "turret_slot_" .. tostring(gridData.slot))
          end
          -- Add other active module types here if they exist
          -- For example: if gridData.type == "weapon" and gridData.module then
          --   table.insert(items, "weapon_slot_" .. tostring(gridData.slot))
          -- end
        end
    end

    -- Only show the panel if there are active modules available
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

function HotbarSelection.draw()
    if not HotbarSelection.visible then return end

    Theme.drawGradientGlowRect(panel.x, panel.y, panel.w, panel.h, 4, Theme.colors.bg1, Theme.colors.bg2, Theme.colors.primary, Theme.effects.glowWeak * 0.1)
    Theme.drawEVEBorder(panel.x, panel.y, panel.w, panel.h, 4, Theme.colors.border, 2)

    for i, item in ipairs(HotbarSelection.items) do
        local col = (i - 1) % panel.itemsPerRow
        local row = math.floor((i - 1) / panel.itemsPerRow)
        local itemX = panel.x + panel.itemGap + col * (panel.itemSize + panel.itemGap)
        local itemY = panel.y + panel.itemGap + row * (panel.itemSize + panel.itemGap)

        local mx, my = Viewport.getMousePosition()
        local hover = mx > itemX and mx < itemX + panel.itemSize and my > itemY and my < itemY + panel.itemSize
        Theme.setColor(hover and Theme.colors.bg3 or Theme.colors.bg2)
        love.graphics.rectangle("fill", itemX, itemY, panel.itemSize, panel.itemSize)

        if item == "turret" then
            local Hotbar = require("src.ui.hud.hotbar")
            Hotbar.drawTurretIcon("gun", Theme.colors.accent, itemX + 4, itemY + 4, panel.itemSize - 8)
        elseif item == "boost" then
            local Hotbar = require("src.ui.hud.hotbar")
            Hotbar.drawBoostIcon(itemX + 4, itemY + 4, panel.itemSize - 8, true)
        elseif type(item) == 'string' and item:match('^turret_slot_%d+$') then
            -- Draw specific turret slot icon
            local idx = tonumber(item:match('^turret_slot_(%d+)$'))
            if HotbarSelection.player and HotbarSelection.player.components and HotbarSelection.player.components.equipment and idx then
                local turret = nil
                for _, gridData in ipairs(HotbarSelection.player.components.equipment.grid) do
                  if gridData.type == "turret" and gridData.module and gridData.slot == idx then
                    turret = gridData.module
                    break
                  end
                end
                if turret then
                    local kind = turret.kind or 'gun'
                    local col = (turret.tracer and turret.tracer.color) or Theme.colors.accent
                    local Hotbar = require("src.ui.hud.hotbar")
                    Hotbar.drawTurretIcon(kind, col, itemX + 4, itemY + 4, panel.itemSize - 8)
                end
            end
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

        if x > itemX and x < itemX + panel.itemSize and y > itemY and y < itemY + panel.itemSize then
            -- Record old slot index before clearing
            local oldSlotIndex = nil
            -- Check if the item is already in another slot
            for j, slot in ipairs(HotbarSystem.slots) do
                if slot.item == item then
                    oldSlotIndex = j
                    slot.item = nil
                end
            end

            HotbarSystem.slots[HotbarSelection.slot].item = item

            -- If moved to a different hotbar slot with different hotkey, deactivate turret state
            if oldSlotIndex and oldSlotIndex ~= HotbarSelection.slot and
               type(item) == 'string' and item:match('^turret_slot_(%d+)$') then
                local idx = tonumber(item:match('^turret_slot_(%d+)$'))
                local oldKey = HotbarSystem.getSlotKey(oldSlotIndex)
                local newKey = HotbarSystem.getSlotKey(HotbarSelection.slot)
                if oldKey ~= newKey then
                    HotbarSystem.state.active.turret_slots = HotbarSystem.state.active.turret_slots or {}
                    HotbarSystem.state.active.turret_slots[idx] = false
                end
            end

            -- Persist new hotbar layout
            if HotbarSystem.save then HotbarSystem.save() end
            HotbarSelection.hide()
            return true
        end
    end

    return true
end

return HotbarSelection
