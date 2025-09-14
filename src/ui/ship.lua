local Ship = {
  x = nil,
  y = nil,
  dragging = false,
  dragDX = 0,
  dragDY = 0,
  closeDown = false,
}

local UI = require("src.core.ui")
local Theme = require("src.core.theme")
local Content = require("src.content.content")
local Turret = require("src.systems.turret.core")
local InventoryUI = require("src.ui.inventory")
local Viewport = require("src.core.viewport")

function Ship:new()
  local o = {}
  setmetatable(o, self)
  self.__index = self
  o.slotRects = {}
  return o
end

local popup = {
  open = false,
  x = 0, y = 0, w = 300, h = 200,
  turrets = {},
  scroll = 0,
  selectedSlot = 1 -- Which turret slot is being modified
}

-- Drag state for drag-and-drop equipping
Ship.drag = nil -- { from = 'inventory'|'slot', id = string, slot = number }

local function pointInRect(px, py, r)
  return r and px >= r.x and py >= r.y and px <= r.x + r.w and py <= r.y + r.h
end

local function keyLabel(k)
  if not k then return "" end
  k = tostring(k)
  if k == 'lshift' or k == 'rshift' then return 'SHIFT' end
  if k == 'space' then return 'SPACE' end
  if k == 'mouse1' then return 'LMB' end
  if k == 'mouse2' then return 'RMB' end
  if #k == 1 then return k:upper() end
  return k:upper()
end

function Ship:draw(player, x, y, w, h)
  -- Ship Header Section
  local cx, cy = x + 16, y + 16
  local headerHeight = 60
  
  -- Ship visual/icon area
  Theme.drawGradientGlowRect(cx, cy, w - 32, headerHeight, 6,
    Theme.colors.bg2, Theme.colors.bg1, Theme.colors.accent, Theme.effects.glowWeak)
  
  local iconSize = 48
  local iconX, iconY = cx + 8, cy + 6
  
  -- Ship icon placeholder (could be actual ship sprite in future)
  Theme.setColor(Theme.colors.accent)
  love.graphics.circle("line", iconX + iconSize/2, iconY + iconSize/2, iconSize/2 - 2)
  Theme.setColor(Theme.colors.textSecondary) 
  love.graphics.printf("SHIP", iconX, iconY + iconSize/2 - 6, iconSize, "center")
  
  -- Ship info
  local infoX = iconX + iconSize + 12
  Theme.setColor(Theme.colors.textHighlight)
  local font = Theme.fonts and Theme.fonts.medium or love.graphics.getFont()
  love.graphics.setFont(font)
  local shipName = player.name or (player.ship and player.ship.name) or "Unknown Ship"
  love.graphics.print(shipName, infoX, iconY + 2)
  
  Theme.setColor(Theme.colors.text)
  local smallFont = Theme.fonts and Theme.fonts.small or love.graphics.getFont()
  love.graphics.setFont(smallFont)
  local shipClass = player.class or (player.ship and player.ship.class) or "Unknown Class"
  love.graphics.print("Class: " .. shipClass, infoX, iconY + 22)
  
  -- Status indicator
  local statusColor = player.docked and Theme.colors.success or Theme.colors.warning
  local statusText = player.docked and "DOCKED - Fitting Available" or "UNDOCKED - Fitting Locked"
  Theme.setColor(statusColor)
  love.graphics.print(statusText, infoX, iconY + 36)
  
  cy = cy + headerHeight + 20

  -- Ship Stats Section
  local statsHeight = 100
  Theme.drawGradientGlowRect(cx, cy, w - 32, statsHeight, 6,
    Theme.colors.bg1, Theme.colors.bg0, Theme.colors.border, Theme.effects.glowWeak)
  
  -- Stats header
  Theme.setColor(Theme.colors.textHighlight)
  love.graphics.setFont(Theme.fonts and Theme.fonts.medium or love.graphics.getFont())
  love.graphics.print("Ship Statistics", cx + 8, cy + 8)
  
  -- Stats content
  love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
  local statsX, statsY = cx + 12, cy + 32
  local col2X = cx + (w-32)/2 + 20
  local hComp = player.components and player.components.health or {}
  local phys = player.components and player.components.physics or {}
  local body = phys and phys.body or {}
  
  local function stat(label, value, x, y, color)
    Theme.setColor(Theme.colors.textSecondary)
    love.graphics.print(label, x, y)
    Theme.setColor(color or Theme.colors.text)
    local valueStr = tostring(value or "-")
    if type(value) == "number" and value >= 1000 then
      valueStr = string.format("%.1fk", value / 1000)
    end
    love.graphics.print(valueStr, x + 90, y)
  end
  
  -- Defensive stats
  stat("Hull HP:", hComp.maxHP, statsX, statsY, Theme.colors.statusHull)
  stat("Shield HP:", hComp.maxShield, statsX, statsY + 16, Theme.colors.statusShield)
  stat("Capacitor:", hComp.maxEnergy, statsX, statsY + 32, Theme.colors.statusCapacitor)
  
  -- Ship characteristics  
  stat("Signature:", player.sig or "-", col2X, statsY)
  stat("Cargo Hold:", player.cargoCapacity or "-", col2X, statsY + 16)
  stat("Ship Mass:", (body and body.mass) or (phys and phys.mass) or "-", col2X, statsY + 32)

  cy = cy + statsHeight + 20

  -- Weapon Hardpoints Section
  local hardpoints = (player.ship and player.ship.hardpoints) or {}
  local numSlots = #hardpoints
  local docked = player.docked
  local mx, my = Viewport.getMousePosition()
  local time = love.timer.getTime()
  
  -- Calculate layout for turret slots
  local slotSize = 72
  local slotSpacing = 16
  local totalSlotsWidth = numSlots * slotSize + (numSlots - 1) * slotSpacing
  local fittingHeight = 160
  
  -- Weapon fitting area background
  Theme.drawGradientGlowRect(cx, cy, w - 32, fittingHeight, 6,
    Theme.colors.bg1, Theme.colors.bg0, Theme.colors.border, Theme.effects.glowWeak)
  
  -- Header
  Theme.setColor(Theme.colors.textHighlight)
  love.graphics.setFont(Theme.fonts and Theme.fonts.medium or love.graphics.getFont())
  love.graphics.print("Weapon Hardpoints (" .. numSlots .. ")", cx + 8, cy + 8)
  
  if not docked then
    Theme.setColor(Theme.colors.warning)
    love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
    love.graphics.print("⚠ Dock at a station to modify your ship's fitting", cx + 8, cy + 28)
  else
    Theme.setColor(Theme.colors.success) 
    love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
    love.graphics.print("✓ Drag weapons from your inventory to equip them", cx + 8, cy + 28)
  end

  -- Draw turret slots in a cleaner layout
  local startX = cx + (w - 32 - totalSlotsWidth) / 2
  local slotY = cy + 50
  
  self.slotRects = {}
  for slotNum = 1, numSlots do
    local slotX = startX + (slotNum - 1) * (slotSize + slotSpacing)
    local t = player:getTurretInSlot(slotNum)
    local isHovered = mx >= slotX and mx <= slotX + slotSize and my >= slotY and my <= slotY + slotSize
    
    -- Slot background with better visual states
    local bgColor, borderColor
    if not docked then
      bgColor, borderColor = Theme.colors.bg0, Theme.colors.danger
    elseif isHovered then
      bgColor, borderColor = Theme.colors.bg3, Theme.colors.accent
    elseif t then
      bgColor, borderColor = Theme.colors.bg2, Theme.colors.success  
    else
      bgColor, borderColor = Theme.colors.bg1, Theme.colors.border
    end
    
    Theme.drawGradientGlowRect(slotX, slotY, slotSize, slotSize, 8,
      bgColor, Theme.colors.bg0, borderColor, Theme.effects.glowWeak)

    -- Slot content
    if t then
      -- Equipped turret
      UI.drawTurretIcon(t.kind, t.tracer and t.tracer.color, slotX + 8, slotY + 8, slotSize - 16)
      
      -- Turret name below icon
      Theme.setColor(Theme.colors.text)
      love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
      love.graphics.printf(t.name or "Turret", slotX, slotY + slotSize + 4, slotSize, "center")
    else
      -- Empty slot
      local emptyAlpha = 0.3 + 0.1 * math.sin(time * 2)
      Theme.setColor(Theme.withAlpha(Theme.colors.textSecondary, emptyAlpha))
      
      -- Plus icon for empty slots
      local centerX, centerY = slotX + slotSize/2, slotY + slotSize/2
      local iconSize = 16
      love.graphics.setLineWidth(3)
      love.graphics.line(centerX - iconSize/2, centerY, centerX + iconSize/2, centerY)
      love.graphics.line(centerX, centerY - iconSize/2, centerX, centerY + iconSize/2)
      love.graphics.setLineWidth(1)
      
      Theme.setColor(Theme.colors.textDisabled)
      love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
      love.graphics.printf("Empty", slotX, slotY + slotSize + 4, slotSize, "center")
    end
    
    -- Slot number badge
    Theme.setColor(Theme.colors.bg3)
    love.graphics.circle("fill", slotX + 12, slotY + 12, 8)
    Theme.setColor(Theme.colors.text)
    love.graphics.printf(slotNum, slotX + 4, slotY + 6, 16, "center")

    -- Hotkey hint badge for where this turret will map on the hotbar
    local Settings = require("src.core.settings")
    local HotbarSystem = require("src.systems.hotbar")
    local keymap = Settings.getKeymap()
    local hotkeyText = nil
    if slotNum == 1 then
      hotkeyText = keyLabel(keymap.hotbar_1)
    else
      -- Find which hotbar slot is assigned to this turret slot via HotbarSystem.slots
      if HotbarSystem and HotbarSystem.slots then
        for hIndex, hSlot in ipairs(HotbarSystem.slots) do
          if type(hSlot.item) == 'string' and hSlot.item == ('turret_slot_' .. tostring(slotNum)) then
            local key = keymap['hotbar_' .. tostring(hIndex)]
            hotkeyText = keyLabel(key)
            break
          end
        end
      end
    end
    if hotkeyText then
      local badgeW, badgeH = 30, 16
      local bx = slotX + slotSize - badgeW - 6
      local by = slotY + 6
      Theme.drawGradientGlowRect(bx, by, badgeW, badgeH, 4, Theme.colors.bg3, Theme.colors.bg2, Theme.colors.border, Theme.effects.glowWeak * 0.2)
      Theme.setColor(Theme.colors.textHighlight)
      love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
      love.graphics.printf(hotkeyText, bx, by + 2, badgeW, 'center')
    end

    -- Lock overlay for undocked
    if not docked then
      Theme.setColor(Theme.withAlpha(Theme.colors.danger, 0.7))
      love.graphics.rectangle('fill', slotX, slotY, slotSize, slotSize, 8, 8)
      
      -- Lock icon
      Theme.setColor(Theme.colors.text)
      local lockX, lockY = slotX + slotSize - 20, slotY + 8
      love.graphics.circle('line', lockX + 8, lockY + 6, 6)
      love.graphics.rectangle('fill', lockX + 5, lockY + 8, 6, 6)
    end

    -- Record slot rect for interactions
    self.slotRects[slotNum] = { x = slotX, y = slotY, w = slotSize, h = slotSize }

    -- Highlight compatibility when dragging an item/module
    do
      local drag = Ship.drag or (InventoryUI and InventoryUI.drag)
      if drag and drag.id then
        local def = Content.getTurret(drag.id)
        local compatible = def ~= nil
        local sameSlot = (drag.from == 'slot' and drag.slot == slotNum)
        local col
        if not docked then
          -- Show muted highlight to indicate docking required
          col = Theme.colors.textSecondary
        elseif compatible and not sameSlot then
          col = Theme.colors.success
        else
          col = Theme.colors.danger
        end
        -- Draw subtle overlay + border glow
        Theme.setColor(Theme.withAlpha(col, 0.18))
        love.graphics.rectangle('fill', slotX, slotY, slotSize, slotSize)
        Theme.setColor(Theme.withAlpha(col, 0.35))
        love.graphics.rectangle('line', slotX, slotY, slotSize, slotSize)
      end
    end

    -- No weapons-disabled lock here: equipment changes are only locked when not docked

    -- Cooldown bar (simple and sleek)
    if t and t.cooldown and t.cooldown > 0 and t.cycle and t.cycle > 0 then
      local cooldownProgress = math.max(0, math.min(1, t.cooldown / t.cycle))
      local barHeight = math.floor(slotSize * cooldownProgress)

      -- Cooldown overlay (semi-transparent)
      love.graphics.setColor(0.2, 0.4, 0.8, 0.6)
      love.graphics.rectangle("fill", slotX, slotY + slotSize - barHeight, slotSize, barHeight)

      -- Cooldown border
      love.graphics.setColor(0.4, 0.6, 1.0, 0.8)
      love.graphics.setLineWidth(1)
      love.graphics.rectangle("line", slotX, slotY + slotSize - barHeight, slotSize, barHeight)
    end

    -- Draw the border
    Theme.drawEVEBorder(slotX, slotY, slotSize, slotSize, 8, Theme.colors.border, 6)

    -- Tooltip
    if pointInRect(mx, my, {x = slotX, y = slotY, w = slotSize, h = slotSize}) then
      local tooltip
      if not docked then
        tooltip = "Must be at the station to modify."
      end
      if tooltip and tooltip ~= "" then
        local tw = 10 + love.graphics.getFont():getWidth(tooltip)
        local th = 28
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", mx + 12, my, tw, th)
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.print(tooltip, mx + 18, my + 6)
      end
    end
  end

  -- Update layout for remaining content
  cy = cy + fittingHeight + 20

  -- Equipped Modules Details Section
  local modulesHeight = 140
  Theme.drawGradientGlowRect(cx, cy, w - 32, modulesHeight, 6,
    Theme.colors.bg1, Theme.colors.bg0, Theme.colors.border, Theme.effects.glowWeak)
    
  Theme.setColor(Theme.colors.textHighlight)
  love.graphics.setFont(Theme.fonts and Theme.fonts.medium or love.graphics.getFont())
  love.graphics.print("Installed Modules", cx + 8, cy + 8)
  
  love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
  
  -- Show equipped modules or "no modules" message
  local equippedCount = 0
  for i = 1, numSlots do
    local tdata
    for _, td in ipairs((player.components and player.components.equipment and player.components.equipment.turrets) or {}) do 
      if td.slot == i then 
        tdata = td 
        break 
      end 
    end
    if tdata and tdata.turret then
      equippedCount = equippedCount + 1
    end
  end
  
  if equippedCount == 0 then
    Theme.setColor(Theme.colors.textDisabled)
    love.graphics.printf("No weapons installed", cx + 8, cy + 50, w - 48, "center")
    love.graphics.printf("Drag weapons from your inventory to equip them", cx + 8, cy + 70, w - 48, "center")
  else
    local listY = cy + 28
    for i = 1, numSlots do
      local tdata
      for _, td in ipairs((player.components and player.components.equipment and player.components.equipment.turrets) or {}) do 
        if td.slot == i then 
          tdata = td 
          break 
        end 
      end
      local t = tdata and tdata.turret
      
      if t then
        local id = tdata and tdata.id
        local def = id and Content.getTurret(id)
        local name = (def and def.name) or id or t.kind or ("Weapon " .. i)
        
        -- Module name
        Theme.setColor(Theme.colors.textHighlight)
        love.graphics.print(string.format("[%d] %s", i, name), cx + 12, listY)
        
        -- Module stats in compact format
        Theme.setColor(Theme.colors.textSecondary)
        local dmg = (t.damageMin or 0)
        if t.damageMax and t.damageMax ~= t.damageMin then 
          dmg = string.format("%d-%d", t.damageMin, t.damageMax) 
        end
        
        local statsText = string.format("DMG: %s  |  CYCLE: %.2fs  |  RANGE: %s",
          tostring(dmg), t.cycle or 0, tostring(t.optimal or "-"))
        love.graphics.print(statsText, cx + 24, listY + 14)
        
        listY = listY + 32
        if listY > cy + modulesHeight - 20 then break end -- Don't overflow
      end
    end
  end

  -- Draw dragged turret icon following cursor (slot or inventory source)
  if Ship.drag or (InventoryUI and InventoryUI.drag) then
    local mx, my = Viewport.getMousePosition()
    local drag = Ship.drag or InventoryUI.drag
    local id = drag and drag.id
    local tdef = id and Content.getTurret(id)
    if tdef then
      local drawSize = slotSize
      local dx = mx - drawSize / 2
      local dy = my - drawSize / 2
      Theme.setColor({1,1,1,0.9})
      UI.drawTurretIcon(tdef.type or tdef.kind or "gun", (tdef.tracer and tdef.tracer.color), dx + 4, dy + 4, drawSize - 8)
    end
  end
end

function Ship:mousepressed(player, x, y, button)
  -- Drag start: from slot
  if button == 1 then
    -- Check slots first
    for i, r in ipairs(self.slotRects) do
      if r and pointInRect(x, y, r) then
        local tdata
        for _, td in ipairs((player.components and player.components.equipment and player.components.equipment.turrets) or {}) do if td.slot == i then tdata = td break end end
        if tdata and tdata.turret and tdata.id and player and player.docked then
          Ship.drag = { from = 'slot', slot = i, id = tdata.id }
          return true, false
        end
      end
    end
  end
  return false
end

function Ship:mousereleased(player, x, y, button)
  local consumed = false
  if button == 1 then
    -- Drop handling for drag-and-drop
    if Ship.drag or (InventoryUI and InventoryUI.drag) then
      local drag = Ship.drag or InventoryUI.drag
      Ship.drag = nil
      if InventoryUI and InventoryUI.drag then InventoryUI.drag = nil end
      -- Dropped on a slot?
      for i, r in ipairs(self.slotRects or {}) do
        if r and pointInRect(x, y, r) then
          if drag.from == 'inventory' or (drag.from == nil and drag.id) then
            -- Only allow fitting while docked
            if player and player.docked then
              player:equipTurret(i, drag.id)
            end
            return true, false
          elseif drag.from == 'slot' then
            if i ~= drag.slot then
              -- Move slot -> slot via inventory (unequip then equip)
              if player and player.docked then
                local ok = player:unequipTurret(drag.slot)
                if ok then
                  player:equipTurret(i, drag.id)
                end
              end
              return true, false
            end
          end
        end
      end
      -- Dropped back to inventory tray (or anywhere else): if from slot, unequip
      if drag.from == 'slot' then
        player:unequipTurret(drag.slot)
        return true, false
      end
    end
  elseif button == 2 then -- Right-click to unequip (only when docked)
    for i, r in ipairs(self.slotRects or {}) do
      if r and pointInRect(x, y, r) then
        if player and player.docked then
          player:unequipTurret(i)
        end
        return true, false
      end
    end
  end
  return consumed, false
end

function Ship:mousemoved(player, x, y, dx, dy)
  return false
end

function Ship:update(dt)
  -- Placeholder for future update logic
end

return Ship
