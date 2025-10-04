local Theme = require("src.core.theme")
local Window = require("src.ui.common.window")
local Viewport = require("src.core.viewport")
local IconSystem = require("src.core.icon_system")
local Content = require("src.content.content")
local Notifications = require("src.ui.notifications")

local RepairPopup = {}
RepairPopup.__index = RepairPopup

RepairPopup.visible = false
RepairPopup.station = nil
RepairPopup.player = nil
RepairPopup.requirements = {}
RepairPopup.canRepair = false
RepairPopup.window = nil
RepairPopup.repairButton = nil
RepairPopup.onRepairAttempt = nil
RepairPopup.interactionRange = 220

local function getPlayerItemCount(player, itemId)
  local cargo = player and player.components and player.components.cargo
  if not cargo or not cargo.getQuantity then return 0 end
  local count = cargo:getQuantity(itemId)
  return count or 0
end

local function prettyName(itemId, def)
  if def and def.name then
    return def.name
  end
  local name = itemId:gsub("_", " ")
  return name:gsub("%f[%a].", string.upper)
end

local function ensureWindow()
  if RepairPopup.window then return end

  RepairPopup.window = Window.new({
    title = "Beacon Repair",
    width = 420,
    height = 320,
    minWidth = 320,
    minHeight = 240,
    maxHeight = 520,
    closable = true,
    draggable = true,
    resizable = false,
    useLoadPanelTheme = true,
    bottomBarHeight = (Theme.ui and Theme.ui.buttonHeight or 28) + 20,
    drawContent = function(self, x, y, w, h)
      RepairPopup.drawContent(self, x, y, w, h)
    end,
    onClose = function()
      RepairPopup.hide()
    end,
  })
end

local function clampWindowToScreen()
  if not RepairPopup.window then return end
  local w = RepairPopup.window
  local sw, sh = Viewport.getDimensions()
  if w.x + w.width > sw - 20 then
    w.x = math.max(20, sw - w.width - 20)
  end
  if w.y + w.height > sh - 20 then
    w.y = math.max(20, sh - w.height - 20)
  end
  if w.x < 20 then w.x = 20 end
  if w.y < 20 then w.y = 20 end
end

function RepairPopup.refresh()
  local station = RepairPopup.station
  local player = RepairPopup.player

  local requirements = {}
  local canRepair = true

  if station and station.components and station.components.repairable then
    local list = station.components.repairable.repairCost or {}
    for _, entry in ipairs(list) do
      local itemId = entry.item
      local needed = entry.amount or 0
      local success, def = pcall(Content.getItem, itemId)
      if not success then def = nil end
      local have = getPlayerItemCount(player, itemId)
      local hasEnough = have >= needed
      if not hasEnough then
        canRepair = false
      end
      requirements[#requirements + 1] = {
        itemId = itemId,
        def = def,
        name = prettyName(itemId, def),
        need = needed,
        have = have,
        hasEnough = hasEnough,
      }
    end
  else
    canRepair = false
  end

  RepairPopup.requirements = requirements
  RepairPopup.canRepair = canRepair

  if RepairPopup.window then
    local baseHeight = 190
    local rowHeight = 58
    local newHeight = baseHeight + (#requirements * rowHeight)
    newHeight = math.max(RepairPopup.window.minHeight or newHeight, newHeight)
    if RepairPopup.window.maxHeight then
      newHeight = math.min(RepairPopup.window.maxHeight, newHeight)
    end
    RepairPopup.window.height = newHeight
    clampWindowToScreen()
  end
end

local function isMouseInsideButton(mx, my, rect)
  if not rect or not mx or not my then return false end
  return mx >= rect.x and mx <= rect.x + rect.w and my >= rect.y and my <= rect.y + rect.h
end

function RepairPopup.drawContent(_, x, y, w, h)
  local padding = (Theme.ui and Theme.ui.contentPadding) or 15
  local contentWidth = w - padding * 2
  local startX = x + padding
  local cursorY = y + padding

  local previousFont = love.graphics.getFont()

  Theme.setColor(Theme.colors.text)
  love.graphics.setFont(Theme.fonts.medium)
  local header = "Defensive Beacon Array"
  love.graphics.print(header, startX, cursorY)
  cursorY = cursorY + Theme.fonts.medium:getHeight() + 6

  love.graphics.setFont(Theme.fonts.small)
  Theme.setColor(Theme.colors.textSecondary)
  local description = "Rebuild the beacon to reactivate the protective no-spawn field."
  love.graphics.printf(description, startX, cursorY, contentWidth, "left")
  cursorY = cursorY + Theme.fonts.small:getHeight() * 2

  love.graphics.setFont(Theme.fonts.normal)
  Theme.setColor(Theme.colors.text)
  love.graphics.print("Required Materials", startX, cursorY)
  cursorY = cursorY + Theme.fonts.normal:getHeight() + 6

  local rowHeight = 54
  local iconSize = 36
  local rowSpacing = 6

  for _, req in ipairs(RepairPopup.requirements) do
    local rowY = cursorY
    Theme.setColor(Theme.withAlpha(Theme.colors.bg2, 0.85))
    love.graphics.rectangle("fill", startX, rowY, contentWidth, rowHeight, 8, 8)
    Theme.setColor(Theme.colors.border)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", startX, rowY, contentWidth, rowHeight, 8, 8)

    local iconX = startX + 10
    local iconY = rowY + (rowHeight - iconSize) * 0.5
    IconSystem.drawIconAny({ req.def, req.itemId }, iconX, iconY, iconSize, 1.0)

    Theme.setColor(Theme.colors.text)
    love.graphics.setFont(Theme.fonts.normal)
    love.graphics.print(req.name, iconX + iconSize + 12, iconY)

    local amountText = string.format("%d / %d", req.have, req.need)
    local amountColor = req.hasEnough and Theme.colors.success or Theme.colors.danger
    Theme.setColor(amountColor)
    local amountW = Theme.fonts.normal:getWidth(amountText)
    love.graphics.print(amountText, startX + contentWidth - amountW - 10, iconY)

    cursorY = cursorY + rowHeight + rowSpacing
  end

  local statusY = cursorY + 4
  love.graphics.setFont(Theme.fonts.small)
  if RepairPopup.canRepair then
    Theme.setColor(Theme.colors.success)
    love.graphics.print("All materials acquired. Press [R] or click Repair.", startX, statusY)
  else
    Theme.setColor(Theme.colors.danger)
    love.graphics.print("Missing materials. Gather the required resources to proceed.", startX, statusY)
  end

  local buttonHeight = (Theme.ui and Theme.ui.buttonHeight) or 28
  local buttonWidth = contentWidth
  local buttonX = startX
  local buttonY = y + h - buttonHeight - padding

  RepairPopup.repairButton = RepairPopup.repairButton or {}
  RepairPopup.repairButton._rect = { x = buttonX, y = buttonY, w = buttonWidth, h = buttonHeight }

  local mx, my = Viewport.getMousePosition()
  local hover = isMouseInsideButton(mx, my, RepairPopup.repairButton._rect)
  local label = RepairPopup.canRepair and "Repair Beacon" or "Missing Materials"
  local buttonColor = RepairPopup.canRepair and Theme.colors.success or Theme.colors.danger

  Theme.drawStyledButton(buttonX, buttonY, buttonWidth, buttonHeight, label, hover, love.timer.getTime(), buttonColor, false)

  if previousFont then
    love.graphics.setFont(previousFont)
  end
end

function RepairPopup.show(station, player, onRepairAttempt)
  if not station or not player then return end

  ensureWindow()

  RepairPopup.station = station
  RepairPopup.player = player
  RepairPopup.onRepairAttempt = onRepairAttempt

  if RepairPopup.window then
    RepairPopup.window.title = "Beacon Repair"
    RepairPopup.window:show()
  end

  RepairPopup.visible = true
  RepairPopup.refresh()
end

function RepairPopup.hide()
  RepairPopup.visible = false
  RepairPopup.station = nil
  RepairPopup.player = nil
  RepairPopup.requirements = {}
  RepairPopup.canRepair = false
  RepairPopup.onRepairAttempt = nil
  RepairPopup.repairButton = nil
  if RepairPopup.window then
    if RepairPopup.window.hide then
      RepairPopup.window:hide()
    else
      RepairPopup.window.visible = false
    end
  end
end

function RepairPopup.hideIfStation(station)
  if not RepairPopup.visible then return end
  if not station or RepairPopup.station == station then
    RepairPopup.hide()
  end
end

function RepairPopup.onRepairSuccess()
  RepairPopup.hide()
end

local function notifyFailure()
  Notifications.add("Insufficient materials for repair", "error")
end

function RepairPopup.onRepairButtonPressed()
  if not RepairPopup.visible or not RepairPopup.station or not RepairPopup.player then
    return
  end

  if not RepairPopup.canRepair then
    notifyFailure()
    return
  end

  if RepairPopup.onRepairAttempt then
    local success = RepairPopup.onRepairAttempt(RepairPopup.station, RepairPopup.player)
    if success then
      Notifications.add("Beacon station repaired successfully!", "success")
      RepairPopup.onRepairSuccess()
    else
      notifyFailure()
      RepairPopup.refresh()
    end
  end
end

function RepairPopup.update(dt)
  if not RepairPopup.visible then return end

  local station = RepairPopup.station
  local player = RepairPopup.player
  if not station or not station.components or not station.components.repairable then
    RepairPopup.hide()
    return
  end

  if not station.components.repairable.broken then
    RepairPopup.hide()
    return
  end

  if not player or not player.components or not player.components.position then
    RepairPopup.hide()
    return
  end

  local stationPos = station.components.position
  if not stationPos then
    RepairPopup.hide()
    return
  end

  local playerPos = player.components.position
  local dx = playerPos.x - stationPos.x
  local dy = playerPos.y - stationPos.y
  local distSq = dx * dx + dy * dy
  if distSq > (RepairPopup.interactionRange * RepairPopup.interactionRange) then
    RepairPopup.hide()
    return
  end

  RepairPopup.refresh()
end

function RepairPopup.mousepressed(x, y, button)
  if not RepairPopup.visible or not RepairPopup.window then
    return false
  end

  if RepairPopup.window:mousepressed(x, y, button) then
    return true, false
  end

  if button == 1 and RepairPopup.repairButton and RepairPopup.repairButton._rect then
    local clicked = Theme.handleButtonClick(RepairPopup.repairButton, x, y, function()
      RepairPopup.onRepairButtonPressed()
    end)
    if clicked then
      return true, false
    end
  end

  return false
end

function RepairPopup.mousereleased(x, y, button)
  if not RepairPopup.visible or not RepairPopup.window then
    return false
  end
  return RepairPopup.window:mousereleased(x, y, button)
end

function RepairPopup.mousemoved(x, y, dx, dy)
  if not RepairPopup.visible or not RepairPopup.window then
    return false
  end
  return RepairPopup.window:mousemoved(x, y, dx, dy)
end

function RepairPopup.getRect()
  if not RepairPopup.visible or not RepairPopup.window then
    return nil
  end
  return {
    x = RepairPopup.window.x,
    y = RepairPopup.window.y,
    w = RepairPopup.window.width,
    h = RepairPopup.window.height,
  }
end

return RepairPopup
