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

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
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
local HotbarSystem = require("src.systems.hotbar")
local Notifications = require("src.ui.notifications")
local HotbarUI = require("src.ui.hud.hotbar")

local function formatHotbarKeyLabel(key)
    if not key or key == "" then return "Unbound" end
    key = tostring(key)
    if key == "mouse1" then return "LMB" end
    if key == "mouse2" then return "RMB" end
    if key == "space" then return "SPACE" end
    if key == "lshift" or key == "rshift" then return "SHIFT" end
    if #key == 1 then return key:upper() end
    return key:upper()
end

local function resolveModuleDisplayName(entry)
    if not entry then return nil end
    local module = entry.module
    if module then
        return module.proceduralName or module.name or entry.id
    end
    return entry.id
end

local function resolveSlotType(slotData)
    if not slotData then return nil end
    return slotData.baseType or slotData.type
end

local function resolveSlotHeaderLabel(slotType)
    if slotType == "turret" then
        return "Turret Slots"
    elseif slotType == "shield" then
        return "Shield Slots"
    elseif slotType == "utility" then
        return "Utility Slots"
    end
    return "Module Slots"
end

local function buildHotbarPreview(player, gridOverride)
    local slots = HotbarSystem.slots or {}
    local totalSlots = #slots
    local preview = {}
    local grid = gridOverride or (player.components and player.components.equipment and player.components.equipment.grid) or {}

    -- Seed with current hotbar content for context
    for i = 1, totalSlots do
        local slot = slots[i]
        if slot and slot.item then
            local label = slot.item
            local idx = tostring(slot.item):match("^turret_slot_(%d+)$")
            if idx then
                idx = tonumber(idx)
                if grid[idx] then
                    label = resolveModuleDisplayName(grid[idx]) or label
                end
            end
            preview[i] = {
                item = slot.item,
                label = label,
                origin = "actual",
                gridIndex = idx
            }
        end
    end

    local forced = {}
    local autos = {}

    for _, gridData in ipairs(grid) do
        if gridData.type == "turret" and gridData.module then
            local entry = {
                key = "turret_slot_" .. tostring(gridData.slot),
                label = resolveModuleDisplayName(gridData) or ("Turret " .. tostring(gridData.slot)),
                origin = "auto",
                gridIndex = gridData.slot
            }
            local preferred = tonumber(gridData.hotbarSlot)
            if preferred and preferred >= 1 and preferred <= totalSlots then
                forced[preferred] = forced[preferred] or {
                    key = entry.key,
                    label = entry.label,
                    origin = "preferred",
                    gridIndex = entry.gridIndex
                }
            else
                table.insert(autos, entry)
            end
        end
    end

    for slotIndex, entry in pairs(forced) do
        if slotIndex >= 1 and slotIndex <= totalSlots then
            preview[slotIndex] = {
                item = entry.key,
                label = entry.label,
                origin = entry.origin,
                gridIndex = entry.gridIndex
            }
        end
    end

    local function placeEntry(entry)
        -- First try to match existing slot already holding this key
        for i = 1, totalSlots do
            if preview[i] and preview[i].item == entry.key then
                preview[i] = {
                    item = entry.key,
                    label = entry.label,
                    origin = entry.origin or "auto",
                    gridIndex = entry.gridIndex
                }
                return
            end
        end
        -- Then look for empty slot
        for i = 1, totalSlots do
            if not preview[i] or not preview[i].item then
                preview[i] = {
                    item = entry.key,
                    label = entry.label,
                    origin = entry.origin or "auto",
                    gridIndex = entry.gridIndex
                }
                return
            end
        end
    end

    for _, entry in ipairs(autos) do
        placeEntry(entry)
    end

    return preview
end

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
    o.hotbarButtons = {}
    o.window = Window.new({
        title = "Ship Fitting",
        width = 1280,
        height = 800,
        resizable = true,
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
    o.statsScroll = 0
    o.slotScroll = 0
    o.statsViewRect = nil
    o.slotViewRect = nil
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
  instance.statsScroll = 0
  instance.slotScroll = 0
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

    self.slotDropdowns = self.slotDropdowns or {}
    self.removeButtons = self.removeButtons or {}
    self.hotbarButtons = self.hotbarButtons or {}

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

        -- First option: show current module when one is fitted, otherwise allow unequip
        if fittedName then
            table.insert(options, fittedName)
            actions[#options] = { kind = 'keep' }
        else
            table.insert(options, 'None')
            actions[#options] = { kind = 'keep' }
        end

        -- Populate from player's cargo (inventory) only
        if player.components and player.components.cargo then
            player:iterCargo(function(slotKey, entry)
                local stackQty = entry.qty or 0
                if stackQty > 0 then
                    local itemDef = Content.getItem(entry.id)
                    local turretDef = Content.getTurret(entry.id)
                    local def = itemDef or turretDef
                    if def then
                        local allowed = false
                        local slotType = resolveSlotType(slotData)
                        if slotType == "turret" then
                            allowed = turretDef ~= nil
                        elseif slotType == "shield" then
                            if itemDef and itemDef.module and itemDef.module.type == "shield" then
                                allowed = true
                            elseif turretDef and turretDef.module and turretDef.module.type == "shield" then
                                allowed = true
                            end
                        else
                            -- For any slot (including those with different module types equipped),
                            -- show all items that have modules or are turrets
                            if itemDef and itemDef.module then
                                allowed = true
                            elseif turretDef and turretDef.module then
                                allowed = true
                            end
                        end

                        if allowed then
                            local label = def.name or tostring(entry.id)
                            if stackQty > 1 then
                                label = string.format('%s (x%d)', label, stackQty)
                            end
                            table.insert(options, label)
                            actions[#options] = { kind = 'equip', id = entry.id }
                        end
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
            if self.slotDropdowns[i] then
                self.slotDropdowns[i]:setSelectedIndex(index)
            end
            -- Update other dropdowns since cargo state may have changed
            -- Refresh dropdowns after mutating cargo/equipment state
            if InventoryUI and InventoryUI.refresh then
                InventoryUI.refresh()
            end
            -- Update button states after equipping/unequipping
            self:updateDropdowns(player)
        end

        if not self.slotDropdowns[i] then
            self.slotDropdowns[i] = Dropdown.new({
                options = options,
                selectedIndex = selectedIndex,
                width = 200,
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
        self.hotbarButtons[i] = self.hotbarButtons[i] or {}
        local hotbarValue = slotData and slotData.hotbarSlot or 0
        self.hotbarButtons[i].value = hotbarValue or 0
        local baseSlotType = resolveSlotType(slotData)
        self.hotbarButtons[i].enabled = baseSlotType == "turret" and slotData and slotData.module
        self.hotbarButtons[i].rect = nil
    end
end

function Ship:draw(player, x, y, w, h)
    player = player or PlayerRef.get()
    if not player then
        return
    end

    if not x or not y or not w or not h then
        return
    end

    local pad = (Theme.ui and Theme.ui.contentPadding) or 16
    local cx, cy = x + pad, y + pad
    local headerHeight = 60

    Theme.drawGradientGlowRect(cx, cy, w - pad * 2, headerHeight, 6,
        Theme.colors.bg2, Theme.colors.bg1, Theme.colors.accent, Theme.effects.glowWeak)

    local iconSize = 48
    local iconX, iconY = cx + 8, cy + 6

    Theme.setColor(Theme.colors.accent)
    love.graphics.circle("line", iconX + iconSize / 2, iconY + iconSize / 2, iconSize / 2 - 2)
    Theme.setColor(Theme.colors.textSecondary)
    love.graphics.printf("SHIP", iconX, iconY + iconSize / 2 - 6, iconSize, "center")

    local infoX = iconX + iconSize + 12
    Theme.setColor(Theme.colors.textHighlight)
    love.graphics.setFont(Theme.fonts and Theme.fonts.medium or love.graphics.getFont())
    local shipName = player.name or (player.ship and player.ship.name) or "Unknown Ship"
    love.graphics.print(shipName, infoX, iconY + 2)

    Theme.setColor(Theme.colors.text)
    local smallFont = Theme.fonts and Theme.fonts.small or love.graphics.getFont()
    love.graphics.setFont(smallFont)
    local shipClass = player.class or (player.ship and player.ship.class) or "Unknown Class"
    love.graphics.print("Class: " .. shipClass, infoX, iconY + 22)

    local statusColor = player.docked and Theme.colors.success or Theme.colors.warning
    local statusText = player.docked and "DOCKED - Fitting Available" or "UNDOCKED - Fitting Locked"
    Theme.setColor(statusColor)
    love.graphics.print(statusText, infoX, iconY + 36)

    cy = cy + headerHeight + 20

    local gridSlots = (player.components and player.components.equipment and player.components.equipment.grid) or {}
    local availableWidth = w - pad * 2
    local statsWidth = math.min(320, math.floor(availableWidth * 0.4))
    local spacing = 24
    local gridWidth = availableWidth - statsWidth - spacing
    if gridWidth < 480 then
        gridWidth = 480
        statsWidth = availableWidth - gridWidth - spacing
    end

    local gridHeight = h - headerHeight - 40

    Theme.drawGradientGlowRect(cx, cy, w - pad * 2, gridHeight, 6,
        Theme.colors.bg1, Theme.colors.bg0, Theme.colors.border, Theme.effects.glowWeak)

    local statsX = cx + 8
    local statsY = cy + 12
    local statsInnerWidth = statsWidth - 16
    local statsViewHeight = gridHeight - 24

    Theme.setColor(Theme.colors.bg2)
    love.graphics.rectangle("fill", statsX, statsY, statsInnerWidth, statsViewHeight, 4, 4)

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

    local lineHeight = 22
    local statsContentHeight = 26 + (#statsList * lineHeight) + 16
    local statsClipX, statsClipY, statsClipW, statsClipH = statsX, statsY, statsInnerWidth, statsViewHeight
    local statsViewInnerHeight = math.max(0, statsClipH - 24)
    local statsMinScroll = math.min(0, statsViewInnerHeight - statsContentHeight)
    self.statsScroll = clamp(self.statsScroll or 0, statsMinScroll, 0)
    local statsScroll = self.statsScroll

    love.graphics.setScissor(statsClipX, statsClipY, statsClipW, statsClipH)
    love.graphics.push()
    love.graphics.translate(0, statsScroll)

    local contentX = statsX + 12
    local contentY = statsY + 12

    Theme.setColor(Theme.colors.textHighlight)
    love.graphics.setFont(Theme.fonts and Theme.fonts.medium or love.graphics.getFont())
    love.graphics.print("Ship Stats", contentX, contentY)

    contentY = contentY + 26
    love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())

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

    love.graphics.pop()
    love.graphics.setScissor()
    self.statsViewRect = {
        x = statsClipX,
        y = statsClipY,
        w = statsClipW,
        h = statsClipH,
        minScroll = statsMinScroll
    }

    local gridX = statsX + statsWidth + spacing
    local gridY = cy + 12

    local hotbarPreviewHeight = 80
    local hotbarPreviewWidth = gridWidth - 16
    Theme.setColor(Theme.colors.bg2)
    love.graphics.rectangle("fill", gridX, gridY, hotbarPreviewWidth, hotbarPreviewHeight, 4, 4)

    local slotSize = 40
    local slotGap = 14
    local slotsY = gridY + 32
    local slotsX = gridX + 12
    local hotbarPreview = buildHotbarPreview(player)
    for slotIndex = 1, #HotbarSystem.slots do
        local sx = slotsX + (slotIndex - 1) * (slotSize + slotGap)
        Theme.setColor(Theme.colors.bg1)
        love.graphics.rectangle("fill", sx, slotsY, slotSize, slotSize, 4, 4)
        Theme.setColor(Theme.colors.border)
        love.graphics.rectangle("line", sx, slotsY, slotSize, slotSize, 4, 4)

        local keyLabel = formatHotbarKeyLabel(HotbarSystem.getSlotKey and HotbarSystem.getSlotKey(slotIndex))
        Theme.setColor(Theme.colors.textSecondary)
        love.graphics.setFont(Theme.fonts and Theme.fonts.tiny or love.graphics.getFont())
        love.graphics.printf(keyLabel, sx, slotsY - 18, slotSize, "center")

        local previewEntry = hotbarPreview[slotIndex]
        if previewEntry and previewEntry.item then
            local entryLabel = previewEntry.label or previewEntry.item
            if previewEntry.origin == "preferred" then
                Theme.setColor(Theme.colors.textHighlight)
            elseif previewEntry.origin == "auto" then
                Theme.setColor(Theme.colors.text)
            else
                Theme.setColor(Theme.colors.textSecondary)
            end

            if previewEntry.gridIndex and player.components and player.components.equipment and player.components.equipment.grid[previewEntry.gridIndex] then
                local gridEntry = player.components.equipment.grid[previewEntry.gridIndex]
                Theme.setColor(Theme.colors.text)
                local iconSize = slotSize - 6
                HotbarUI.drawTurretIcon(gridEntry.module or resolveModuleDisplayName(gridEntry), sx + 3, slotsY + 3, iconSize)
            elseif entryLabel then
                love.graphics.printf(entryLabel, sx - 30, slotsY + slotSize * 0.5 - 6, slotSize + 60, "center")
            end
        end
    end

    local infoY = gridY + hotbarPreviewHeight + 8
    gridY = infoY + 20
    local gridPanelWidth = gridWidth - 16
    local slotPanelHeight = gridHeight - (gridY - (cy + 12)) - 24
    Theme.setColor(Theme.colors.bg2)
    love.graphics.rectangle("fill", gridX, gridY, gridPanelWidth, slotPanelHeight, 4, 4)

    Theme.setColor(Theme.colors.textHighlight)
    love.graphics.setFont(Theme.fonts and Theme.fonts.medium or love.graphics.getFont())
    love.graphics.print("Fitting Slots", gridX + 12, gridY + 12)

    love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
    local labelFont = Theme.fonts and Theme.fonts.small or love.graphics.getFont()
    local labelHeights = {}
    local slotClipX = gridX + 4
    local slotClipY = gridY + 40
    local slotClipW = gridPanelWidth - 8
    local slotClipH = math.max(40, slotPanelHeight - 40)
    local maxLabelWidthAvailable = math.max(1, slotClipW - 24)

    local slotBaseY = gridY + 44
    local slotCursor = slotBaseY
    local lastSlotType = nil
    local rowSpacing = 20
    for i, slotData in ipairs(gridSlots) do
        local slotType = resolveSlotType(slotData) or "module"
        if lastSlotType ~= slotType then
            slotCursor = slotCursor + 30
            lastSlotType = slotType
        end
        local dropdown = self.slotDropdowns[i]
        local optionHeight = (dropdown and dropdown.optionHeight) or 24
        local labelText = ((slotData and slotData.label) or ("Slot " .. i)) .. ":"
        local labelWidth = labelFont:getWidth(labelText)
        local lineCount = math.max(1, math.ceil(labelWidth / maxLabelWidthAvailable))
        local labelHeight = lineCount * labelFont:getHeight()
        labelHeights[i] = labelHeight
        local extraHotbarHeight = (slotType == "turret") and (optionHeight + 20) or 0
        slotCursor = slotCursor + labelHeight + optionHeight + extraHotbarHeight + rowSpacing
    end
    local slotContentHeight = slotCursor - slotBaseY + 16
    local slotViewInnerHeight = math.max(0, slotClipH - 16)
    local slotMinScroll = math.min(0, slotViewInnerHeight - slotContentHeight)
    self.slotScroll = clamp(self.slotScroll or 0, slotMinScroll, 0)
    local slotScroll = self.slotScroll

    love.graphics.setScissor(slotClipX, slotClipY, slotClipW, slotClipH)
    local slotY = slotBaseY
    local currentSlotHeader = nil
    local mx, my = Viewport.getMousePosition()

    for i, slotData in ipairs(gridSlots) do
        local slotType = resolveSlotType(slotData) or "module"
        if currentSlotHeader ~= slotType then
            Theme.setColor(Theme.colors.textHighlight)
            love.graphics.setFont(Theme.fonts and Theme.fonts.medium or love.graphics.getFont())
            love.graphics.print(resolveSlotHeaderLabel(slotType), gridX + 12, slotY + slotScroll)
            slotY = slotY + 30
            currentSlotHeader = slotType
        end

        local dropdown = self.slotDropdowns[i]
        if dropdown then
            local drawY = slotY + slotScroll
            local labelHeight = labelHeights[i] or labelFont:getHeight()
            local extraHotbarHeight = (slotType == "turret") and (dropdown.optionHeight + 20) or 0
            local rowRectX = slotClipX + 2
            local rowRectY = drawY - 6
            local rowRectW = slotClipW - 4
            local rowRectH = math.max(36, labelHeight + dropdown.optionHeight + extraHotbarHeight + 16)

            local rowHover = mx and my and pointInRect(mx, my, { x = rowRectX, y = rowRectY, w = rowRectW, h = rowRectH })
            Theme.setColor(rowHover and Theme.withAlpha(Theme.colors.hover, 0.85) or Theme.withAlpha(Theme.colors.bg3, 0.55))
            love.graphics.rectangle("fill", rowRectX, rowRectY, rowRectW, rowRectH, 6, 6)

            Theme.setColor(Theme.withAlpha(Theme.colors.border, rowHover and 0.45 or 0.28))
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", rowRectX + 0.5, rowRectY + 0.5, rowRectW - 1, rowRectH - 1, 6, 6)

            Theme.setColor(Theme.withAlpha(Theme.colors.accent, rowHover and 0.8 or 0.45))
            love.graphics.rectangle("fill", gridX + 8, rowRectY + 6, 2, rowRectH - 12, 2, 2)

            Theme.setColor(Theme.colors.textSecondary)
            love.graphics.setFont(labelFont)
            local labelText = ((slotData and slotData.label) or ("Slot " .. i)) .. ":"
            love.graphics.printf(labelText, gridX + 12, drawY, slotClipW - 24, "left")

            local availableWidth = slotClipW - 24
            local controlsY = drawY + labelHeight + 6

            dropdown:setPosition(gridX + 12, controlsY)
            dropdown.width = math.min(availableWidth, 340)
            dropdown:drawButtonOnly(mx, my)

            local hotbarButton = self.hotbarButtons[i]
            if slotType == "turret" then
                local hotbarY = controlsY + dropdown.optionHeight + 6
                local hotbarWidth = availableWidth - dropdown.optionHeight - 8
                if hotbarWidth < 72 then
                    hotbarWidth = math.max(56, hotbarWidth)
                end
                local hotbarRect = { x = gridX + 12, y = hotbarY, w = hotbarWidth, h = dropdown.optionHeight }
                local removeRect = { x = hotbarRect.x + hotbarRect.w + 8, y = hotbarRect.y, w = dropdown.optionHeight, h = dropdown.optionHeight }
                if removeRect.x + removeRect.w > gridX + 12 + availableWidth then
                    local overflow = (removeRect.x + removeRect.w) - (gridX + 12 + availableWidth)
                    hotbarRect.w = math.max(56, hotbarRect.w - overflow)
                    removeRect.x = hotbarRect.x + hotbarRect.w + 8
                end
                local hotbarHover = pointInRect(mx, my, hotbarRect)

                hotbarButton.rect = hotbarRect
                hotbarButton.hover = hotbarHover
                hotbarButton.enabled = slotData and slotData.module

                local hotbarLabel = "Auto Assign"
                local hbValue = hotbarButton.value or 0
                if slotData and slotData.module then
                    if hbValue > 0 then
                        local keyLabel = formatHotbarKeyLabel(HotbarSystem.getSlotKey and HotbarSystem.getSlotKey(hbValue))
                        if keyLabel == "Unbound" then
                            hotbarLabel = string.format("Slot %d", hbValue)
                        else
                            hotbarLabel = string.format("Slot %d (%s)", hbValue, keyLabel)
                        end
                    else
                        hotbarLabel = "Auto Assign"
                    end
                else
                    hotbarLabel = "No turret"
                end

                Theme.setColor(hotbarButton.enabled and (hotbarHover and Theme.colors.bg3 or Theme.colors.bg2) or Theme.colors.bg1)
                love.graphics.rectangle("fill", hotbarRect.x, hotbarRect.y, hotbarRect.w, hotbarRect.h, 4, 4)
                Theme.setColor(Theme.colors.border)
                love.graphics.rectangle("line", hotbarRect.x + 0.5, hotbarRect.y + 0.5, hotbarRect.w - 1, hotbarRect.h - 1, 4, 4)
                Theme.setColor(hotbarButton.enabled and Theme.colors.text or Theme.colors.textDisabled)
                local oldFont = love.graphics.getFont()
                if Theme.fonts and Theme.fonts.tiny then
                    love.graphics.setFont(Theme.fonts.tiny)
                elseif Theme.fonts and Theme.fonts.small then
                    love.graphics.setFont(Theme.fonts.small)
                end
                love.graphics.printf(hotbarLabel, hotbarRect.x + 6, hotbarRect.y + (hotbarRect.h - love.graphics.getFont():getHeight()) * 0.5, hotbarRect.w - 12, "center")
                if oldFont then love.graphics.setFont(oldFont) end

                if slotData and slotData.module then
                    local removeHover = pointInRect(mx, my, removeRect)

                    self.removeButtons[i].rect = removeRect
                    self.removeButtons[i].hover = removeHover
                    hotbarButton.removeRect = removeRect
                    hotbarButton.removeHover = removeHover

                    Theme.setColor(removeHover and Theme.colors.danger or Theme.colors.bg1)
                    love.graphics.rectangle("fill", removeRect.x, removeRect.y, removeRect.w, removeRect.h, 4, 4)
                    Theme.setColor(Theme.colors.border)
                    love.graphics.rectangle("line", removeRect.x + 0.5, removeRect.y + 0.5, removeRect.w - 1, removeRect.h - 1, 4, 4)
                    Theme.setColor(Theme.colors.text)
                    love.graphics.printf("x", removeRect.x, removeRect.y + (removeRect.h - love.graphics.getFont():getHeight()) * 0.5, removeRect.w, "center")
                else
                    hotbarButton.removeRect = nil
                    hotbarButton.removeHover = nil
                    self.removeButtons[i].rect = nil
                    self.removeButtons[i].hover = false
                end
            else
                hotbarButton.enabled = false
                hotbarButton.rect = nil
                hotbarButton.removeRect = nil
                hotbarButton.removeHover = nil
                self.removeButtons[i].rect = nil
                self.removeButtons[i].hover = false

                Theme.setColor(Theme.colors.textTertiary)
                love.graphics.setFont(labelFont)
                love.graphics.printf("Passive Module", gridX + 12, controlsY + dropdown.optionHeight + 4, slotClipW - 24, "left")
            end

            slotY = slotY + labelHeight + dropdown.optionHeight + extraHotbarHeight + rowSpacing
        end
    end

    love.graphics.setScissor()
    self.slotViewRect = {
        x = slotClipX,
        y = slotClipY,
        w = slotClipW,
        h = slotClipH,
        minScroll = slotMinScroll
    }
end


function Ship:drawDropdownOptions()
    local mx, my = Viewport.getMousePosition()
    for i, dropdown in ipairs(self.slotDropdowns) do
        if dropdown.open then
            dropdown:drawOptionsOnly(mx, my)
        end
    end
end

local function pointInRectSimple(px, py, rect)
    return rect and px and py and px >= rect.x and px <= rect.x + rect.w and py >= rect.y and py <= rect.y + rect.h
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

    local content = instance.window:getContentBounds()
    local insideContent = content and pointInRectSimple(x, y, { x = content.x, y = content.y, w = content.w, h = content.h })

    -- Transform mouse coordinates to be relative to window content area
    local contentX = x - (content and content.x or 0)
    local contentY = y - (content and content.y or 0)


    -- Prioritize dropdown interaction when inside content area
    if insideContent and instance.slotDropdowns then
        for _, dropdown in ipairs(instance.slotDropdowns) do
            if dropdown:mousepressed(x, y, button) then
                -- Prevent window drag if dropdown consumed click
                if instance.window and instance.window.dragging then
                    instance.window.dragging = false
                end
                return true, false
            end
        end
    end

    local handled = instance.window:mousepressed(x, y, button)
    if handled then
        return true, false
    end

    if not insideContent or not player or type(player) ~= "table" then
        return false
    end

    if button == 1 and instance.hotbarButtons then
        for index, hbButton in ipairs(instance.hotbarButtons) do
            local rect = hbButton and hbButton.rect
            if hbButton and hbButton.enabled and rect and pointInRect(x, y, rect) then
                local playerModule = player.components and player.components.equipment and player.components.equipment.grid and player.components.equipment.grid[index]
                if playerModule and playerModule.module then -- Handle any module type
                    -- Cycle to next available hotbar slot, skipping occupied ones
                    local currentValue = hbButton.value or 0
                    local totalSlots = #HotbarSystem.slots

                    local attempts = 0
                    local foundSlot = false
                    local newValue = currentValue

                    while attempts < totalSlots + 1 and not foundSlot do
                        newValue = newValue + 1
                        if newValue > totalSlots then
                            newValue = 0
                        end

                        -- Check if this slot is available (not occupied by another module)
                        local slotOccupied = false
                        if newValue > 0 and player.components and player.components.equipment and player.components.equipment.grid then
                            for j, gridData in ipairs(player.components.equipment.grid) do
                                if gridData.hotbarSlot == newValue and j ~= index and gridData.module then
                                    slotOccupied = true
                                    break
                                end
                            end
                        end

                        if newValue == 0 or not slotOccupied then
                            foundSlot = true
                        end

                        attempts = attempts + 1
                    end

                    if foundSlot then
                        hbButton.value = newValue

                        if hbButton.value == 0 then
                            playerModule.hotbarSlot = nil
                        else
                            playerModule.hotbarSlot = hbButton.value
                        end

                        local keyName = nil
                        if hbButton.value == 0 then
                            keyName = "Auto"
                        else
                            keyName = HotbarSystem.getSlotKey and HotbarSystem.getSlotKey(hbButton.value) or ("hotbar_" .. tostring(hbButton.value))
                        end

                        if Notifications and Notifications.add then
                            Notifications.add(string.format("Slot %d bound to %s", index, keyName), "info")
                        end

                        local Hotbar = HotbarSystem
                        if Hotbar and Hotbar.populateFromPlayer then
                            Hotbar.populateFromPlayer(player, nil, index)
                        end

                        if InventoryUI and InventoryUI.refresh then
                            InventoryUI.refresh()
                        end
                        local instance = Ship.ensure()
                        if instance and instance.updateDropdowns then
                            instance:updateDropdowns(player)
                        end
                    end
                    return true, false
                end
            end
        end
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

                    -- Update hotbar after unequipping
                    local Hotbar = HotbarSystem
                    if Hotbar and Hotbar.populateFromPlayer then
                        Hotbar.populateFromPlayer(player, nil, index)
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

function Ship:wheelmoved(x, y, dx, dy)
    local instance = Ship.ensure()
    if not Ship.visible or not instance.window or not instance.window.visible then
        return false
    end

    -- Handle case where parameters might be nil
    if dy == nil or dy == 0 then
        return false
    end

    local handled = false
    local scrollDelta = dy * 28

    if instance.statsViewRect and pointInRectSimple(x, y, instance.statsViewRect) then
        local minScroll = instance.statsViewRect.minScroll or 0
        instance.statsScroll = clamp((instance.statsScroll or 0) + scrollDelta, minScroll, 0)
        handled = true
    end

    if instance.slotViewRect and pointInRectSimple(x, y, instance.slotViewRect) then
        local minScroll = instance.slotViewRect.minScroll or 0
        instance.slotScroll = clamp((instance.slotScroll or 0) + scrollDelta, minScroll, 0)
        handled = true
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
