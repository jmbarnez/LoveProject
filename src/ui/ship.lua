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

  -- Equipment Grid Section (3x3)
  local gridSlots = (player.components and player.components.equipment and player.components.equipment.grid) or {}
  local docked = player.docked
  local mx, my = Viewport.getMousePosition()
  
  -- Grid layout
  local gridSize = 3  -- 3x3 grid
  local slotSize = 80
  local slotSpacing = 12
  local totalGridWidth = gridSize * slotSize + (gridSize - 1) * slotSpacing
  local gridHeight = 280  -- Space for 3 rows + header
  
  -- Grid background
  Theme.drawGradientGlowRect(cx, cy, w - 32, gridHeight, 6,
    Theme.colors.bg1, Theme.colors.bg0, Theme.colors.border, Theme.effects.glowWeak)
  
  -- Header
  Theme.setColor(Theme.colors.textHighlight)
  love.graphics.setFont(Theme.fonts and Theme.fonts.medium or love.graphics.getFont())
  love.graphics.print("Equipment Grid (3x3)", cx + 8, cy + 8)
  
  
  if not docked then
    Theme.setColor(Theme.colors.warning)
    love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
    love.graphics.print("⚠ Dock at a station to modify your ship's equipment", cx + 8, cy + 28)
  else
    Theme.setColor(Theme.colors.success) 
    love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
    love.graphics.print("✓ Drag modules from your inventory to equip them", cx + 8, cy + 28)
  end

  -- Draw 3x3 grid
  local gridStartX = cx + (w - 32 - totalGridWidth) / 2
  local gridStartY = cy + 50
  
  for row = 0, 2 do
    for col = 0, 2 do
      local slotIndex = row * 3 + col + 1
      local slotX = gridStartX + col * (slotSize + slotSpacing)
      local slotY = gridStartY + row * (slotSize + slotSpacing)
      
      -- Find module data for this slot
      local moduleData = gridSlots[slotIndex]
      local module = moduleData and moduleData.module
      local id = moduleData and moduleData.id
      local moduleType = moduleData and moduleData.type
      
      -- Get module definition
      local def = nil
      if id then
        if moduleType == "shield" or moduleType == "module" then
          def = Content.getItem(id)
        elseif moduleType == "turret" then
          def = Content.getTurret(id)
        end
      end
      
      -- Draw slot background
      Theme.setColor(Theme.colors.bg2)
      love.graphics.rectangle('fill', slotX, slotY, slotSize, slotSize)
      
      -- Draw module if equipped
      if module and def then
        -- Draw module icon
        if def.icon then
          Theme.setColor({1,1,1,0.9})
          love.graphics.draw(def.icon, slotX + 4, slotY + 4, 0, (slotSize - 8) / 128, (slotSize - 8) / 128)
        end
        
        -- Draw module info
        local name = def.name or id or "Module"
        Theme.setColor(Theme.colors.textHighlight)
        love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
        local textWidth = love.graphics.getFont():getWidth(name)
        love.graphics.print(name, slotX + (slotSize - textWidth) / 2, slotY + slotSize - 20)
        
        -- Draw module type indicator
        Theme.setColor(Theme.colors.textSecondary)
        love.graphics.setFont(Theme.fonts and Theme.fonts.tiny or love.graphics.getFont())
        local typeText = moduleType == "shield" and "Shield" or (moduleType == "turret" and "Weapon" or (moduleType == "module" and "Module" or "Module"))
        local typeWidth = love.graphics.getFont():getWidth(typeText)
        love.graphics.print(typeText, slotX + (slotSize - typeWidth) / 2, slotY + slotSize - 8)
        
        -- Draw shield HP for shield modules
        if moduleType == "shield" and def.module and def.module.shield_hp then
          Theme.setColor(Theme.colors.textHighlight)
          love.graphics.print(tostring(def.module.shield_hp), slotX + 4, slotY + 4)
          
          -- Draw shield regen if available
          if def.module.shield_regen then
            Theme.setColor(Theme.colors.success)
            love.graphics.setFont(Theme.fonts and Theme.fonts.tiny or love.graphics.getFont())
            love.graphics.print("+" .. tostring(def.module.shield_regen) .. "/s", slotX + 4, slotY + 16)
          end
        end
      else
        -- Draw empty slot indicator
        Theme.setColor(Theme.colors.textDisabled)
        love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
        love.graphics.printf("Empty", slotX + 2, slotY + slotSize/2 - 8, slotSize - 4, "center")
      end
      
      -- Store slot rect for interaction
      if not self.gridSlotRects then self.gridSlotRects = {} end
      self.gridSlotRects[slotIndex] = { x = slotX, y = slotY, w = slotSize, h = slotSize }

      -- Highlight compatibility when dragging an item/module
      do
        local drag = Ship.drag or (InventoryUI and InventoryUI.drag)
        if drag and drag.id then
          local itemDef = Content.getItem(drag.id)
          local turretDef = Content.getTurret(drag.id)
          -- Any item with a module property or any turret is compatible
          local compatible = (itemDef and itemDef.module) or turretDef ~= nil
          local sameSlot = (drag.from == 'grid_slot' and drag.slot == slotIndex)
          
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

      -- Draw the border
      Theme.drawEVEBorder(slotX, slotY, slotSize, slotSize, 8, Theme.colors.border, 6)
    end
  end

  -- Draw dragged item icon following cursor
  if Ship.drag or (InventoryUI and InventoryUI.drag) then
    local mx, my = Viewport.getMousePosition()
    local drag = Ship.drag or InventoryUI.drag
    local id = drag and drag.id
    local tdef = id and Content.getTurret(id)
    local idef = id and Content.getItem(id)
    
    if tdef then
      local drawSize = slotSize
      local dx = mx - drawSize / 2
      local dy = my - drawSize / 2
      Theme.setColor({1,1,1,0.9})
      UI.drawTurretIcon(tdef.type or tdef.kind or "gun", (tdef.tracer and tdef.tracer.color), dx + 4, dy + 4, drawSize - 8)
    elseif idef and idef.icon then
      local drawSize = 60
      local dx = mx - drawSize / 2
      local dy = my - drawSize / 2
      Theme.setColor({1,1,1,0.9})
      love.graphics.draw(idef.icon, dx + 4, dy + 4, 0, (drawSize - 8) / 128, (drawSize - 8) / 128)
    end
  end
end

function Ship:mousepressed(player, x, y, button)
  -- Drag start: from grid slot
  if button == 1 then
    -- Check grid slots
    for i, r in ipairs(self.gridSlotRects or {}) do
      if r and pointInRect(x, y, r) then
        local moduleData = (player.components and player.components.equipment and player.components.equipment.grid and player.components.equipment.grid[i]) or {}
        if moduleData.module and moduleData.id and player and player.docked then
          Ship.drag = { from = 'grid_slot', slot = i, id = moduleData.id }
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
      
      -- Dropped on a grid slot?
      for i, r in ipairs(self.gridSlotRects or {}) do
        if r and pointInRect(x, y, r) then
          if drag.from == 'inventory' or (drag.from == nil and drag.id) then
            -- Only allow fitting while docked
            if player and player.docked then
              player:equipModule(i, drag.id)
            end
            return true, false
          elseif drag.from == 'grid_slot' then
            if i ~= drag.slot then
              -- Move slot -> slot via inventory (unequip then equip)
              if player and player.docked then
                local ok = player:unequipModule(drag.slot)
                if ok then
                  player:equipModule(i, drag.id)
                end
              end
              return true, false
            end
          end
        end
      end
      
      -- Dropped back to inventory tray (or anywhere else): if from slot, unequip
      if drag.from == 'grid_slot' then
        player:unequipModule(drag.slot)
        return true, false
      end
    end
  elseif button == 2 then -- Right-click to unequip (only when docked)
    -- Check grid slots
    for i, r in ipairs(self.gridSlotRects or {}) do
      if r and pointInRect(x, y, r) then
        if player and player.docked then
          player:unequipModule(i)
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
