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

local UI = require("src.core.ui")
local Theme = require("src.core.theme")
local Content = require("src.content.content")
local Turret = require("src.systems.turret.core")
local InventoryUI = require("src.ui.inventory")
local Viewport = require("src.core.viewport")
local IconSystem = require("src.core.icon_system")
local Tooltip = require("src.ui.tooltip")
local Log = require("src.core.log")
local Dropdown = require("src.ui.common.dropdown")

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
        drawContent = function(window, x, y, w, h) o:draw(player, x, y, w, h) end
    })
    return o
end

-- Drag state for drag-and-drop equipping
Ship.drag = nil -- { from = 'inventory'|'slot', id = string, slot = number }

function Ship:updateDropdowns(player)
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

        -- Always offer Unequip as an explicit choice
        table.insert(options, "Unequip")
        actions[#options] = { kind = 'unequip', slot = i }

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
    end
end

function Ship:draw(player, x, y, w, h)
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
  
  -- Layout: Stats on left, Grid on right - fill entire panel
  local statsWidth = 200
  local gridHeight = h - headerHeight - 40  -- Fill remaining height
  
  -- Main container background
  Theme.drawGradientGlowRect(cx, cy, w - pad * 2, gridHeight, 6,
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
  
  local mx, my = Viewport.getMousePosition()
  local slotY = gridY
  for i, slotData in ipairs(gridSlots) do
      local dropdown = self.slotDropdowns[i]
      if dropdown then
          -- Draw slot label
          Theme.setColor(Theme.colors.textSecondary)
          love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
          love.graphics.print("Slot " .. i .. ":", gridX - 50, slotY + 4)

          dropdown:setPosition(gridX, slotY)
          dropdown:drawButtonOnly(mx, my)
          slotY = slotY + dropdown.optionHeight + 10
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

function Ship:mousepressed(player, x, y, button)
    if button == 1 then
        for i, dropdown in ipairs(self.slotDropdowns) do
            if dropdown:mousepressed(x, y, button) then
                return true, false
            end
        end
    end
    return false
end

function Ship:mousereleased(player, x, y, button)
  return false, false
end

function Ship:mousemoved(player, x, y, dx, dy)
    local handled = false
    for _, dropdown in ipairs(self.slotDropdowns) do
        if dropdown and dropdown:mousemoved(x, y) then
            handled = true
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
