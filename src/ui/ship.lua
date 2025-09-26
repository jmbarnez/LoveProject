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
  -- No-op in production; left for potential future debugging hooks
end

local Theme = require("src.core.theme")
local Content = require("src.content.content")
local Turret = require("src.systems.turret.core")
local InventoryUI = require("src.ui.inventory")
local Viewport = require("src.core.viewport")
local IconSystem = require("src.core.icon_system")
local Tooltip = require("src.ui.tooltip")
local Log = require("src.core.log")
local Dropdown = require("src.ui.common.dropdown")
local PlayerRef = require("src.core.player_ref")

local function normalizePressArgs(playerArg, xArg, yArg, buttonArg)
    local player, x, y, button = playerArg, xArg, yArg, buttonArg

    if button == nil and type(player) == "number" and type(x) == "number" then
        button = y
        y = x
        x = player
        player = nil
    end

    if type(player) ~= "table" or not player.components then
        player = PlayerRef.get()
    end

    return player, x, y, button
end

local function normalizeMoveArgs(playerArg, xArg, yArg, dxArg, dyArg)
    local player, x, y, dx, dy = playerArg, xArg, yArg, dxArg, dyArg

    if dy == nil and type(player) == "number" and type(x) == "number" and type(y) == "number" then
        dy = dx
        dx = y
        y = x
        x = player
        player = nil
    end

    if type(player) ~= "table" or not player.components then
        player = PlayerRef.get()
    end

    return player, x, y, dx, dy
end

function Ship:new()
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.slotRects = {}
    o.slotDropdowns = {} -- To hold dropdown instances
    o.window = Window.new({
        title = "Ship Fitting",
        width = 600,
        height = 400,
        useLoadPanelTheme = true,
        draggable = true,
        closable = true,
        drawContent = function(window, x, y, w, h) o:draw(nil, x, y, w, h) end,
        onShow = function()
            Ship.visible = true
        end,
        onClose = function()
            Ship.visible = false
        end
    })
    Ship.window = o.window
    Ship._instance = Ship._instance or o
    return o
end

-- Drag state for drag-and-drop equipping
Ship.drag = nil -- { from = 'inventory'|'slot', id = string, slot = number }
Ship.removeButtons = {}
Ship.visible = false
Ship._instance = nil

function Ship.ensure()
  if not Ship._instance then
    Ship._instance = Ship:new()
  end
  return Ship._instance
end

function Ship.show()
  local instance = Ship.ensure()
  Ship.visible = true
  if instance.window then
    if not instance.window.visible then
      do
        local Viewport = require("src.core.viewport")
        local sw, sh = Viewport.getDimensions()
        instance.window.x = math.floor((sw - instance.window.width) * 0.5)
        instance.window.y = math.floor((sh - instance.window.height) * 0.5)
      end
    end
    instance.window:show()
  end
  local player = PlayerRef.get()
  if player then
    instance:updateDropdowns(player)
  end
  return true
end

function Ship.hide()
  if not Ship._instance then
    Ship.visible = false
    return false
  end
  if Ship._instance.window then
    Ship._instance.window:hide()
  end
  Ship.visible = false
  return false
end

function Ship.toggle()
  if Ship.visible then
    return Ship.hide()
  else
    return Ship.show()
  end
end

function Ship:getWindow()
    local instance = Ship.ensure()
    return instance.window
end

function Ship:getInstance()
    return Ship.ensure()
end

function Ship:updateDropdowns(player)
    player = player or PlayerRef.get()
    if not player then return end
    local equipment = player.components and player.components.equipment
    if not equipment or not equipment.grid then return end

    for i, slotData in ipairs(equipment.grid) do
        local slotIndex = i
        local options = {}
        local actions = {} -- maps option index -> { kind = 'keep'|'unequip'|'equip', id=?, turretData=? }

        -- Determine currently fitted module name
        local fittedName = nil
        if slotData and slotData.module then
            if slotData.type == "turret" then
                local baseId = (slotData.module and (slotData.module.baseId or slotData.module.id)) or slotData.id
                local tdef = baseId and Content.getTurret(baseId) or nil
                fittedName = (tdef and tdef.name) or (slotData.module and slotData.module.proceduralName) or (slotData.module and slotData.module.name) or baseId or "Fitted"
            else
                local mod = slotData.module
                local idef = (slotData.id and Content.getItem(slotData.id)) or nil
                fittedName = (mod and mod.name) or (idef and idef.name) or slotData.id or "Fitted"
            end
        end

        -- First option: show currently fitted (or Unequipped)
        if fittedName then
            table.insert(options, fittedName)
            actions[#options] = { kind = 'keep' }
        else
            table.insert(options, "Unequipped")
            actions[#options] = { kind = 'keep' }
        end

        -- Populate from player's cargo (inventory) only
        if player.components and player.components.cargo then
            player:iterCargo(function(slotKey, entry)
                local stackQty = entry.qty or 0
                if stackQty > 0 then
                    local def = Content.getItem(entry.id) or Content.getTurret(entry.id)
                    if def and def.module then
                        local label = def.name or tostring(entry.id)
                        if stackQty > 1 then
                            label = string.format('%s (x%d)', label, stackQty)
                        end
                        table.insert(options, label)
                        actions[#options] = { kind = 'equip', id = entry.id }
                    elseif def and def.kind then
                        local label = def.name or tostring(entry.id)
                        if stackQty > 1 then
                            label = string.format('%s (x%d)', label, stackQty)
                        end
                        table.insert(options, label)
                        actions[#options] = { kind = 'equip', id = entry.id }
                    end
                end
            end)
        end

        local selectedIndex = 1 -- default to show current fitted state

        local function handleSelection(index)
            local action = actions[index]
            if not action then return end
            if action.kind == 'equip' then
                player:equipModule(slotIndex, action.id, action.turretData)
            elseif action.kind == 'unequip' then
                player:unequipModule(slotIndex)
            end
            self:updateDropdowns(player)
            if InventoryUI and InventoryUI.refresh then
                InventoryUI.refresh()
            end
        end

        if not self.slotDropdowns[i] then
            self.slotDropdowns[i] = Dropdown.new({
                options = options,
                selectedIndex = selectedIndex,
                width = 180,
                optionHeight = 24,
                onSelect = handleSelection
            })
        else
            self.slotDropdowns[i]:setOptions(options)
            -- Ensure onSelect uses current actions
            self.slotDropdowns[i].onSelect = handleSelection
            self.slotDropdowns[i]:setSelectedIndex(selectedIndex)
        end
        self.slotDropdowns[i]._actions = actions
        self.removeButtons[i] = self.removeButtons[i] or {hover = false}
    end
end

function Ship:draw(player, x, y, w, h)
  player = player or PlayerRef.get()
  if not player then return end
  -- Safety checks for parameters
  if not x or not y or not w or not h then
    return
  end
  
  -- Ship Header Section
  local pad = (Theme.ui and Theme.ui.contentPadding) or 16
  local cx, cy = x + pad, y + pad
  local headerHeight = 60
  
  -- Ship visual/icon area
  Theme.drawGradientGlowRect(cx, cy, w - pad * 2, headerHeight, 6,
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

  -- Equipment Grid Section with Stats on the left
  local gridSlots = (player.components and player.components.equipment and player.components.equipment.grid) or {}

  local availableWidth = w - pad * 2
  local statsWidth = math.min(240, math.floor(availableWidth * 0.4))
  local spacing = 20
  local gridWidth = availableWidth - statsWidth - spacing
  if gridWidth < 220 then
      gridWidth = 220
      statsWidth = availableWidth - gridWidth - spacing
  end

  local gridHeight = h - headerHeight - 40

  Theme.drawGradientGlowRect(cx, cy, w - pad * 2, gridHeight, 6,
    Theme.colors.bg1, Theme.colors.bg0, Theme.colors.border, Theme.effects.glowWeak)

  -- Stats section
  local statsX = cx + 8
  local statsY = cy + 12
  local statsInnerWidth = statsWidth - 16

  Theme.setColor(Theme.colors.bg2)
  love.graphics.rectangle("fill", statsX, statsY, statsInnerWidth, gridHeight - 24, 4, 4)

  local contentX = statsX + 12
  local contentY = statsY + 12

  Theme.setColor(Theme.colors.textHighlight)
  love.graphics.setFont(Theme.fonts and Theme.fonts.medium or love.graphics.getFont())
  love.graphics.print("Ship Stats", contentX, contentY)

  contentY = contentY + 26
  love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())

  local hComp = player.components and player.components.health or {}
  local statsList = {}
  if hComp.maxHP and hComp.maxHP > 0 then
      table.insert(statsList, { label = "Hull HP", value = hComp.maxHP, color = Theme.colors.statusHull })
  end
  if hComp.maxShield and hComp.maxShield > 0 then
      table.insert(statsList, { label = "Shield HP", value = hComp.maxShield, color = Theme.colors.statusShield })
  end
  if hComp.maxEnergy and hComp.maxEnergy > 0 then
      table.insert(statsList, { label = "Capacitor", value = hComp.maxEnergy, color = Theme.colors.statusCapacitor })
  end
  if player.sig and player.sig > 0 then
      table.insert(statsList, { label = "Signature", value = player.sig, color = Theme.colors.text })
  end
  if player.cargoCapacity and player.cargoCapacity > 0 then
      table.insert(statsList, { label = "Cargo Hold", value = player.cargoCapacity, color = Theme.colors.text })
  end

  Theme.setColor(Theme.colors.textSecondary)
  local lineHeight = 22
  for _, statData in ipairs(statsList) do
      Theme.setColor(Theme.colors.textSecondary)
      love.graphics.print(statData.label .. ":", contentX, contentY)
      Theme.setColor(statData.color or Theme.colors.text)
      local valueStr = statData.value
      if type(statData.value) == "number" and statData.value >= 1000 then
          valueStr = string.format("%.1fk", statData.value / 1000)
      end
      love.graphics.print(tostring(valueStr), contentX + 110, contentY)
      contentY = contentY + lineHeight
  end

  -- Grid section (fitting)
  local gridX = statsX + statsWidth + spacing
  local gridY = cy + 12
  local gridPanelWidth = gridWidth - 16
  Theme.setColor(Theme.colors.bg2)
  love.graphics.rectangle("fill", gridX, gridY, gridPanelWidth, gridHeight - 24, 4, 4)

  Theme.setColor(Theme.colors.textHighlight)
  love.graphics.setFont(Theme.fonts and Theme.fonts.medium or love.graphics.getFont())
  love.graphics.print("Fitting Slots", gridX + 12, gridY + 12)

  love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
  local mx, my = Viewport.getMousePosition()
  local slotY = gridY + 44
  for i, slotData in ipairs(gridSlots) do
      local dropdown = self.slotDropdowns[i]
      if dropdown then
          Theme.setColor(Theme.colors.textSecondary)
          love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
          love.graphics.print("Slot " .. i .. ":", gridX + 12, slotY + 4)

          local dropdownX = gridX + 70
          dropdown:setPosition(dropdownX, slotY)
          dropdown:drawButtonOnly(mx, my)

          local removeBtnSize = dropdown.optionHeight
          local removeX = dropdownX + dropdown.width + 8
          local removeY = slotY
          local removeRect = {x = removeX, y = removeY, w = removeBtnSize, h = removeBtnSize}
          local hover = pointInRect(mx, my, removeRect)
          self.removeButtons[i].rect = removeRect
          self.removeButtons[i].hover = hover

          local bgColor = hover and Theme.colors.bg2 or Theme.colors.bg1
          Theme.setColor(bgColor)
          love.graphics.rectangle("fill", removeX, removeY, removeBtnSize, removeBtnSize, 3, 3)

          Theme.setColor(Theme.colors.border)
          love.graphics.setLineWidth(1)
          love.graphics.rectangle("line", removeX + 0.5, removeY + 0.5, removeBtnSize - 1, removeBtnSize - 1, 3, 3)

          Theme.setColor(0, 0, 0, 1)
          love.graphics.setLineWidth(2)
          love.graphics.line(removeX + 4, removeY + 4, removeX + removeBtnSize - 4, removeY + removeBtnSize - 4)
          love.graphics.line(removeX + 4, removeY + removeBtnSize - 4, removeX + removeBtnSize - 4, removeY + 4)

          love.graphics.setLineWidth(1)

          slotY = slotY + dropdown.optionHeight + 12
      end
  end
end

function Ship:drawDropdownOptions()
    local mx, my = Viewport.getMousePosition()
    for i, dropdown in ipairs(self.slotDropdowns) do
        if dropdown.open then
            dropdown:drawOptionsOnly(mx, my)
        end
    end
end

function Ship:mousepressed(playerArg, xArg, yArg, buttonArg)
    local instance = Ship.ensure()
    if not Ship.visible or not instance.window or not instance.window.visible then
        return false
    end

    local player, x, y, button = normalizePressArgs(playerArg, xArg, yArg, buttonArg)
    if not x or not y or not button then
        return false
    end

    local handled = instance.window:mousepressed(x, y, button)
    if handled then
        return true, false
    end

    local dropdownHandled = false
    if instance.slotDropdowns then
        for _, dropdown in ipairs(instance.slotDropdowns) do
            if dropdown:mousepressed(x, y, button) then
                dropdownHandled = true
                break
            end
        end
    end
    if dropdownHandled then
        return true, false
    end

    local content = instance.window:getContentBounds()
    if not content or x < content.x or x > content.x + content.w or y < content.y or y > content.y + content.h then
        return false
    end

    if not player or type(player) ~= "table" then
        return false
    end

    if button == 1 and instance.removeButtons then
        for index, removeButton in ipairs(instance.removeButtons) do
            local rect = removeButton and removeButton.rect
            if rect and pointInRect(x, y, rect) then
                local unequipped = player.unequipModule and player:unequipModule(index)
                if unequipped then
                    instance:updateDropdowns(player)
                    if InventoryUI and InventoryUI.refresh then
                        InventoryUI.refresh()
                    end
                end
                return true, false
            end
        end
    end

    return false
end

function Ship:mousereleased(playerArg, xArg, yArg, buttonArg)
    local instance = Ship.ensure()
    if not Ship.visible or not instance.window or not instance.window.visible then
        return false, false
    end

    local player, x, y, button = normalizePressArgs(playerArg, xArg, yArg, buttonArg)
    if not x or not y or not button then
        return false, false
    end

    local handled = instance.window:mousereleased(x, y, button)
    if handled then
        return true, false
    end

    if instance.slotDropdowns then
        for _, dropdown in ipairs(instance.slotDropdowns) do
            if dropdown.mousereleased then
                local dropdownHandled = dropdown:mousereleased(x, y, button)
                if dropdownHandled then
                    return true, false
                end
            end
        end
    end

    return false, false
end

function Ship:mousemoved(playerArg, xArg, yArg, dxArg, dyArg)
    local instance = Ship.ensure()
    if not Ship.visible or not instance.window or not instance.window.visible then
        return false
    end

    local player, x, y, dx, dy = normalizeMoveArgs(playerArg, xArg, yArg, dxArg, dyArg)
    if not x or not y or dx == nil or dy == nil then
        return false
    end

    local handled = instance.window:mousemoved(x, y, dx, dy)

    if instance.slotDropdowns then
        for _, dropdown in ipairs(instance.slotDropdowns) do
            dropdown:mousemoved(x, y)
        end
    end

    return handled
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

return Ship
