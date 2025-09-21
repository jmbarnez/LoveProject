local Window = require("src.ui.common.window")

local Ship = {}

-- Helper function to check if point is inside rectangle
local function pointInRect(px, py, rect)
  -- Handle nil values gracefully
  if px == nil or py == nil or rect == nil or rect.x == nil or rect.y == nil or rect.w == nil or rect.h == nil then
    return false
  end
  return px >= rect.x and px < rect.x + rect.w and py >= rect.y and py < rect.y + rect.h
end

-- Debug function to check loaded turrets
function Ship.debugTurrets()
  local Log = require("src.core.log")
  Log.info("=== DEBUG: Available Turrets ===")
  for id, turret in pairs(Content.byId.turret) do
    Log.info("Turret ID: " .. id .. ", Name: " .. (turret.name or "unnamed") .. ", Type: " .. (turret.type or "unknown"))
  end
  Log.info("Total turrets loaded: " .. #Content.turrets)
  Log.info("=== END DEBUG ===")
end

local UI = require("src.core.ui")
local Theme = require("src.core.theme")
local Content = require("src.content.content")
local Turret = require("src.systems.turret.core")
local InventoryUI = require("src.ui.inventory")
local Viewport = require("src.core.viewport")
local IconSystem = require("src.core.icon_system")
local Tooltip = require("src.ui.tooltip")

function Ship:new()
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.slotRects = {}
    o.window = Window.new({
        title = "Ship Fitting",
        width = 600,
        height = 400,
        drawContent = function(window, x, y, w, h) o:draw(player, x, y, w, h) end
    })
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
  -- Handle nil values gracefully
  if px == nil or py == nil or r == nil or r.x == nil or r.y == nil or r.w == nil or r.h == nil then
    return false
  end
  return px >= r.x and py >= r.y and px <= r.x + r.w and py <= r.y + r.h
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
  -- Safety checks for parameters
  if not x or not y or not w or not h then
    return
  end
  
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

  -- Equipment Grid Section (3x3) with Stats on the left
  local gridSlots = (player.components and player.components.equipment and player.components.equipment.grid) or {}
  local docked = player.docked
  local mx, my = Viewport.getMousePosition()
  
  -- Layout: Stats on left, Grid on right - fill entire panel
  local statsWidth = 200
  local gridSize = 3  -- 3x3 grid
  local slotSize = 64  -- Compact slots
  local slotSpacing = 10
  local totalGridWidth = gridSize * slotSize + (gridSize - 1) * slotSpacing
  local gridHeight = h - headerHeight - 40  -- Fill remaining height
  local totalWidth = statsWidth + 20 + totalGridWidth
  
  -- Main container background
  Theme.drawGradientGlowRect(cx, cy, w - 32, gridHeight, 6,
    Theme.colors.bg1, Theme.colors.bg0, Theme.colors.border, Theme.effects.glowWeak)
  
  -- Stats section (left side)
  local statsX = cx + 8
  local statsY = cy + 8
  
  -- Stats header
  Theme.setColor(Theme.colors.textHighlight)
  love.graphics.setFont(Theme.fonts and Theme.fonts.medium or love.graphics.getFont())
  love.graphics.print("Ship Statistics", statsX, statsY)
  
  -- Stats content
  love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
  local hComp = player.components and player.components.health or {}
  
  local function stat(label, value, x, y, color)
    Theme.setColor(Theme.colors.textSecondary)
    love.graphics.print(label, x, y)
    Theme.setColor(color or Theme.colors.text)
    local valueStr = tostring(value or "-")
    if type(value) == "number" and value >= 1000 then
      valueStr = string.format("%.1fk", value / 1000)
    end
    love.graphics.print(valueStr, x + 80, y)
  end
  
  -- Only show actually used stats
  stat("Hull HP:", hComp.maxHP, statsX, statsY + 30, Theme.colors.statusHull)
  stat("Shield HP:", hComp.maxShield, statsX, statsY + 50, Theme.colors.statusShield)
  stat("Capacitor:", hComp.maxEnergy, statsX, statsY + 70, Theme.colors.statusCapacitor)
  stat("Signature:", player.sig or "-", statsX, statsY + 90, Theme.colors.text)
  stat("Cargo Hold:", player.cargoCapacity or "-", statsX, statsY + 110, Theme.colors.text)
  
  -- Grid section (right side)
  local gridX = cx + statsWidth + 20
  local gridY = cy + 8
  
  -- Draw 3x3 grid (centered vertically)
  local gridStartX = gridX
  local gridStartY = gridY + (gridHeight - (3 * slotSize + 2 * slotSpacing)) / 2
  
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
          -- For turrets, try to get base definition first, fall back to module data
          def = Content.getTurret(id)
          if not def and module and module.baseId then
            def = Content.getTurret(module.baseId)
          end
          -- If still no def, use the module data itself for display
          if not def and module then
            def = module
          end
        end
      end
      
      -- Draw slot background
      Theme.setColor(Theme.colors.bg2)
      love.graphics.rectangle('fill', slotX, slotY, slotSize, slotSize)
      
      -- Draw module if equipped
      if module and def then
        -- Draw module icon using unified system (smaller icons)
        local iconSize = 40  -- Compact icon size
        local iconX = slotX + (slotSize - iconSize) / 2
        local iconY = slotY + 8
        
        if moduleType == "turret" then
          IconSystem.drawTurretIcon(module, iconX, iconY, iconSize, 0.9)
        elseif def.icon and IconSystem.getIcon(def) then
          IconSystem.drawItemIcon(def, iconX, iconY, iconSize, 0.9)
        end
        
        --[[ -- Draw module name underneath icon (each word on new line)
        local name = def.name or def.proceduralName or id or "Module"
        Theme.setColor(Theme.colors.textHighlight)
        love.graphics.setFont(Theme.fonts and Theme.fonts.tiny or love.graphics.getFont())
        
        -- Split name into words and put each on a new line
        local words = {}
        for word in name:gmatch("%S+") do
          table.insert(words, word)
        end
        
        -- Limit to 2 lines maximum to fit in slot
        if #words > 2 then
          words = {words[1], words[2] .. "..."}
        end
        
        local multiLineText = table.concat(words, "\n")
        
        -- Position text at the bottom of the slot
        local textY = slotY + slotSize - 20
        love.graphics.printf(multiLineText, slotX + 2, textY, slotSize - 4, "center")
         ]]
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
        love.graphics.setFont(Theme.fonts and Theme.fonts.tiny or love.graphics.getFont())
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
          local turretData = drag.turretData
          -- Any item with a module property or any turret (def or data) is compatible
          local compatible = (itemDef and itemDef.module) or turretDef ~= nil or (type(turretData) == 'table' and turretData.damage ~= nil)
          local sameSlot = (drag.from == 'grid_slot' and drag.slot == slotIndex)

          local col
          if not docked then
            -- Show muted highlight to indicate docking required
            col = Theme.colors.textSecondary
          elseif sameSlot then
            -- Same slot - show success to indicate it's safe to drop here
            col = Theme.colors.success
          elseif compatible then
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
    local tdata = drag and drag.turretData
    local idef = id and Content.getItem(id)
    
    if tdef or tdata then
      local drawSize = slotSize
      local dx = mx - drawSize / 2
      local dy = my - drawSize / 2
      IconSystem.drawTurretIcon(tdata or tdef, dx + 4, dy + 4, drawSize - 8, 0.9)
    elseif idef then
      local drawSize = slotSize
      local dx = mx - drawSize / 2
      local dy = my - drawSize / 2
      IconSystem.drawItemIcon(idef, dx + 4, dy + 4, drawSize - 8, 0.9)
    end
  end

  -- Draw tooltips for hovered modules
  local mx, my = Viewport.getMousePosition()
  for i, r in ipairs(self.gridSlotRects or {}) do
    if r and pointInRect(mx, my, r) then
      local moduleData = gridSlots[i]
      if moduleData and moduleData.module and moduleData.id then
        local module = moduleData.module
        local id = moduleData.id
        local moduleType = moduleData.type
        
        -- Get module definition
        local def = nil
        if id then
          if moduleType == "shield" or moduleType == "module" then
            def = Content.getItem(id)
          elseif moduleType == "turret" then
            def = Content.getTurret(id)
            if not def and module and module.baseId then
              def = Content.getTurret(module.baseId)
            end
            if not def and module then
              def = module
            end
          end
        end
        
        if def then
          Tooltip.drawItemTooltip(def, mx, my)
        end
        break
      end
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
            if i == drag.slot then
              -- Dropped back in the same slot - do nothing
              return true, false
            elseif i ~= drag.slot then
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

function Ship.keypressed(key)
  if key == "f9" then
    Ship.debugTurrets()
    return true
  end
  return false
end

function Ship:update(dt)
  -- Placeholder for future update logic
end

-- Draw detailed tooltip for equipped modules
--[[ function Ship.drawModuleTooltip(def, module, moduleType, mx, my)
  if not def then return end

  local oldFont = love.graphics.getFont()
  local padding = 8
  local maxWidth = 300

  -- Fonts
  local nameFont = Theme.fonts and Theme.fonts.medium or love.graphics.getFont()
  local statFont = Theme.fonts and Theme.fonts.small or love.graphics.getFont()

  -- Get module name
  local name = def.name or def.proceduralName or "Unknown Module"

  -- Collect stats based on module type
  local stats = {}

  if moduleType == "shield" and def.module then
    -- Shield module stats
    if def.module.shield_hp then
      stats[#stats + 1] = {name = "Shield HP", value = def.module.shield_hp}
    end
    if def.module.shield_regen then
      stats[#stats + 1] = {name = "Shield Regen", value = def.module.shield_regen .. "/s"}
    end
    if def.module.slot_type then
      stats[#stats + 1] = {name = "Slot Type", value = def.module.slot_type}
    end
  elseif moduleType == "turret" then
    -- Turret stats
    if def.damage then stats[#stats + 1] = {name = "Damage", value = def.damage} end
    if def.damageMin and def.damageMax then
      stats[#stats + 1] = {name = "Damage", value = def.damageMin .. "-" .. def.damageMax}
    end
    if def.optimal then stats[#stats + 1] = {name = "Range", value = def.optimal .. (def.falloff and " (" .. def.falloff .. " falloff)" or "")} end
    if def.cycle then stats[#stats + 1] = {name = "Cycle Time", value = def.cycle .. "s"} end
    if def.projectileSpeed then stats[#stats + 1] = {name = "Projectile Speed", value = def.projectileSpeed} end
    if def.capCost then stats[#stats + 1] = {name = "Energy Cost", value = def.capCost} end
    if def.baseAccuracy then stats[#stats + 1] = {name = "Accuracy", value = math.floor(def.baseAccuracy * 100) .. "%"} end
  end

  -- Add general module stats
  if def.value then stats[#stats + 1] = {name = "Value", value = def.value} end
  if def.mass then stats[#stats + 1] = {name = "Mass", value = def.mass} end
  if def.volume then stats[#stats + 1] = {name = "Volume", value = def.volume} end
  if def.tier then stats[#stats + 1] = {name = "Tier", value = def.tier} end
  if def.rarity then stats[#stats + 1] = {name = "Rarity", value = def.rarity} end

  -- Calculate dimensions
  local nameH = nameFont:getHeight()
  local statH = statFont:getHeight()
  local h = padding * 2 + nameH + 8
  if #stats > 0 then
    h = h + (#stats * (statH + 2)) + 4
  end

  local nameW = nameFont:getWidth(name)
  local w = nameW + padding * 2

  -- Check stat widths
  for _, stat in ipairs(stats) do
    local statText = stat.name .. ": " .. tostring(stat.value)
    local statW = statFont:getWidth(statText)
    w = math.max(w, statW + padding * 2)
  end

  -- Add extra width for longer stat names
  w = math.max(w, 250)  -- Minimum width for readability
  w = math.min(w, maxWidth)
  
  -- Position tooltip (offset from cursor)
  local tx = mx + 15
  local ty = my - h - 10
  
  -- Keep on screen
  local sw, sh = love.graphics.getDimensions()
  if tx + w > sw then tx = mx - w - 15 end
  if ty < 0 then ty = my + 10 end
  
  -- Draw background
  Theme.drawGradientGlowRect(tx, ty, w, h, 4,
    Theme.colors.bg1, Theme.colors.bg0, Theme.colors.border, Theme.effects.glowWeak)
  
  -- Draw content
  local currentY = ty + padding

  -- Module name
  love.graphics.setFont(nameFont)
  Theme.setColor(Theme.colors.textHighlight)
  love.graphics.print(name, tx + padding, currentY)
  currentY = currentY + nameH + 8

  -- Module stats
  if #stats > 0 then
    love.graphics.setFont(statFont)
    for _, stat in ipairs(stats) do
      local statText = stat.name .. ": " .. tostring(stat.value)
      Theme.setColor(Theme.colors.text)
      love.graphics.print(statText, tx + padding, currentY)
      currentY = currentY + statH + 2
    end
  end
  
  -- Restore font
  if oldFont then love.graphics.setFont(oldFont) end
end
]]
function Ship:update(dt)
  -- Placeholder for future update logic
end

return Ship
