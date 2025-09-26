local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local StateManager = require("src.managers.state_manager")
local Notifications = require("src.ui.notifications")

local SaveSlots = {}

function SaveSlots:new()
  local o = {}
  setmetatable(o, self)
  self.__index = self
  o.mode = "save" -- "save" or "load"
  o.selectedSlot = nil
  o.buttonRects = {} -- Store button rectangles for click detection
  return o
end

-- Compute preferred content size for the slots view (content area only)
function SaveSlots:getPreferredSize()
  local font = love.graphics.getFont()
  local fontHeight = 12 -- default font height
  if font then
    local success, height = pcall(function() return font:getHeight() end)
    if success and height then
      fontHeight = height
    end
  end
  local lineHeight = fontHeight + 4

  local pad = (Theme.ui and Theme.ui.contentPadding) or 20
  local topBlocks = pad + lineHeight * 2 + lineHeight * 1.5 -- title + instructions
  local slotHeight = 90
  local slotMargin = (Theme.ui and Theme.ui.buttonSpacing) or 10
  local slotsCount = 3

  local contentH = topBlocks + slotHeight * slotsCount + slotMargin * (slotsCount - 1) + 10 -- small bottom pad

  -- Width must accommodate left/right padding and two action buttons on the right
  local buttonFont = (Theme.fonts and Theme.fonts.normal) or love.graphics.getFont()
  local padX = ((Theme.ui and Theme.ui.menuButtonPaddingX) or 12)
  local actionText = (self and self.mode == "save") and "Save" or "Load"
  local maxTextW = 0
  local success1, w1 = pcall(function() return buttonFont:getWidth(actionText) end)
  local success2, w2 = pcall(function() return buttonFont:getWidth("Delete") end)
  if success1 and w1 then maxTextW = math.max(maxTextW, w1) end
  if success2 and w2 then maxTextW = math.max(maxTextW, w2) end
  local buttonW = math.max(90, math.floor((maxTextW or 0) + padX * 2 + 0.5))
  local buttonSpacing = ((Theme.ui and Theme.ui.buttonSpacing) or 10)
  local sidePadding = ((Theme.ui and Theme.ui.contentPadding) or 40) * 2 -- left/right internal paddings used in draw
  local minTextWidth = 300 -- reasonable text region
  local contentW = sidePadding + (buttonW * 2 + buttonSpacing) + minTextWidth

  -- Clamp to a sensible minimum
  contentW = math.max(520, contentW)

  -- Ensure we return numbers
  if type(contentW) ~= "number" then contentW = 520 end
  if type(contentH) ~= "number" then contentH = 300 end

  return contentW, contentH
end

function SaveSlots:setMode(mode)
  self.mode = mode
end

function SaveSlots:draw(x, y, w, h)
  self.buttonRects = {}
  local font = love.graphics.getFont()
  local fontHeight = 12 -- default font height
  if font then
    local success, height = pcall(function() return font:getHeight() end)
    if success and height then
      fontHeight = height
    end
  end
  local lineHeight = fontHeight + 4
  local pad = (Theme.ui and Theme.ui.contentPadding) or 20
  local currentY = y + pad

  -- Compute dynamic button width so labels like "Delete" fit cleanly
  local buttonFont = (Theme.fonts and Theme.fonts.normal) or love.graphics.getFont()
  local padXButtons = ((Theme.ui and Theme.ui.menuButtonPaddingX) or 12)
  local actionTextGlobal = self.mode == "save" and "Save" or "Load"
  local maxTextW = 0
  local ok1, tw1 = pcall(function() return buttonFont:getWidth(actionTextGlobal) end)
  local ok2, tw2 = pcall(function() return buttonFont:getWidth("Delete") end)
  if ok1 and tw1 then maxTextW = math.max(maxTextW, tw1) end
  if ok2 and tw2 then maxTextW = math.max(maxTextW, tw2) end
  local buttonW = math.max(90, math.floor((maxTextW or 0) + padXButtons * 2 + 0.5))
  local buttonH = (Theme.ui and Theme.ui.buttonHeight) or 28
  local buttonSpacing = (Theme.ui and Theme.ui.buttonSpacing) or 10

  -- Title
  Theme.setColor(Theme.colors.text)
  local titleText = self.mode == "save" and "Save Game" or "Load Game"
  local titleW = 0
  if font then
    local success, width = pcall(function() return font:getWidth(titleText) end)
    if success and width then
      titleW = width
    end
  end
  love.graphics.print(titleText, x + (w - titleW) / 2, currentY)
  currentY = currentY + lineHeight * 2
  
  -- Instructions
  Theme.setColor(Theme.colors.textSecondary)
  local instructText = self.mode == "save" and "Select a slot to save to:" or "Select a slot to load:"
  love.graphics.print(instructText, x + 20, currentY)
  currentY = currentY + lineHeight * 1.5
  
  -- Get save slots
  local allSlots = StateManager.getSaveSlots()
  local slots = {}
  
  -- Create array for slots 1, 2, 3 (checking if they exist)
  for i = 1, 3 do
    local slotName = "slot" .. i
    local existingSlot = nil
    
    for _, slot in ipairs(allSlots) do
      if slot.name == slotName then
        existingSlot = slot
        break
      end
    end
    
    slots[i] = existingSlot
  end
  
  -- Draw slots
  local slotHeight = 90
  local slotMargin = (Theme.ui and Theme.ui.buttonSpacing) or 10
  
  for i = 1, 3 do
    local slotY = currentY + (i - 1) * (slotHeight + slotMargin)
    local slot = slots[i]
    local isEmpty = slot == nil
    
    -- Debug: Ensure we're drawing within bounds
    if slotY + slotHeight > y + h then
      break -- Stop if we'd draw outside the container
    end
    
    -- Background
    local bgColor = isEmpty and Theme.colors.bg0 or Theme.colors.bg1
    if self.selectedSlot == i then
      bgColor = Theme.colors.bg2
    end

    Theme.setColor(bgColor)
    love.graphics.rectangle("fill", x + pad, slotY, w - (pad * 2), slotHeight)

    -- Border
    local borderColor = self.selectedSlot == i and Theme.colors.accent or Theme.colors.border
    Theme.setColor(borderColor)
    love.graphics.rectangle("line", x + pad, slotY, w - (pad * 2), slotHeight)
    
    -- Slot number
    Theme.setColor(Theme.colors.accent)
    love.graphics.print("Slot " .. i, x + pad + 20, slotY + 10)
    
    if isEmpty then
      -- Empty slot
      Theme.setColor(Theme.colors.textSecondary)
      love.graphics.print("Empty", x + pad + 20, slotY + 30)
    else
      -- Existing save
      Theme.setColor(Theme.colors.text)
      local description = slot.description or ("Save " .. i)
      love.graphics.print(description, x + pad + 20, slotY + 30)
      
      -- Save info
      local infoText = string.format("Level %d | %d GC | %s",
        slot.playerLevel or 1,
        slot.playerCredits or 0,
        slot.realTime or "Unknown")
      Theme.setColor(Theme.colors.textSecondary)
      love.graphics.print(infoText, x + pad + 20, slotY + 45)
      
    end
  end
  
  -- Draw action buttons for each slot
  for i = 1, 3 do
    local slotY = currentY + (i - 1) * (slotHeight + slotMargin)
    local slot = slots[i]
    local isEmpty = slot == nil
    
    -- Skip if we'd draw outside the container
    if slotY + slotHeight > y + h then
      break
    end
    
    local buttonsX = x + w - (buttonW * 2 + buttonSpacing) - ((Theme.ui and Theme.ui.contentPadding) or 40)
    local buttonY = slotY + slotHeight - buttonH - 5  -- More margin from bottom
    
    -- Action button (Save/Load)
    if not isEmpty or self.mode == "save" then
      local actionColor = self.mode == "save" and Theme.colors.success or Theme.colors.info
      local actionText = actionTextGlobal

      -- Calculate hover state for the button (use virtual mouse coordinates)
      local mx, my = Viewport.getMousePosition()
      local hover = mx >= buttonsX and mx <= buttonsX + buttonW and my >= buttonY and my <= buttonY + buttonH

      -- Store button rect for click detection
      local actionButtonRect = { x = buttonsX, y = buttonY, w = buttonW, h = buttonH }
      self.buttonRects["action_" .. i] = actionButtonRect

      Theme.drawStyledButton(buttonsX, buttonY, buttonW, buttonH, actionText, hover, love.timer.getTime(), actionColor, false, { menuButton = true })
    end

    -- Delete button (only for existing saves)
    if not isEmpty then
      local deleteX = buttonsX + buttonW + buttonSpacing

      -- Calculate hover state for the delete button (use virtual mouse coordinates)
      local mx, my = Viewport.getMousePosition()
      local deleteHover = mx >= deleteX and mx <= deleteX + buttonW and my >= buttonY and my <= buttonY + buttonH

      -- Store button rect for click detection
      local deleteButtonRect = { x = deleteX, y = buttonY, w = buttonW, h = buttonH }
      self.buttonRects["delete_" .. i] = deleteButtonRect

      Theme.drawStyledButton(deleteX, buttonY, buttonW, buttonH, "Delete", deleteHover, love.timer.getTime(), Theme.colors.danger, false, { menuButton = true })
    end
  end
end

function SaveSlots:mousepressed(x, y, button, drawX, drawY, drawW, drawH)
  if button ~= 1 then return false end

  -- Get save slots data to check if a slot is empty
  local allSlots = StateManager.getSaveSlots()
  local slots = {}
  for i = 1, 3 do
    local slotName = "slot" .. i
    local existingSlot = nil
    for _, slot in ipairs(allSlots) do
      if slot.name == slotName then
        existingSlot = slot
        break
      end
    end
    slots[i] = existingSlot
  end

  -- Check all stored button rectangles
  for key, rect in pairs(self.buttonRects) do
    if rect and x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h then
      -- Click is on a button, parse key to get action and slot index
      local action, slotIndexStr = key:match("^(%a+)_(%d+)$")
      if action and slotIndexStr then
        local slotIndex = tonumber(slotIndexStr)
        if slotIndex then
          local isEmpty = slots[slotIndex] == nil
          local slotName = "slot" .. slotIndex

          if action == "action" then
            if not isEmpty or self.mode == "save" then
              if self.mode == "save" then
                local description = "Save Slot " .. slotIndex .. " - " .. os.date("%m/%d %H:%M")
                if StateManager.saveGame(slotName, description) then
                  Notifications.add("Game saved to Slot " .. slotIndex, "success")
                else
                  Notifications.add("Failed to save game", "error")
                end
                return "saved"
              elseif not isEmpty then -- load mode, only on non-empty slots
                if StateManager.loadGame(slotName, true) then
                  Notifications.add("Game loaded from Slot " .. slotIndex, "info")
                else
                  Notifications.add("Failed to load game", "error")
                end
                return "loaded"
              end
            end
          elseif action == "delete" then
            if not isEmpty then
              if StateManager.deleteSave(slotName) then
                Notifications.add("Deleted save from Slot " .. slotIndex, "warning")
              else
                Notifications.add("Failed to delete save", "error")
              end
              return "deleted"
            end
          end
        end
      end
    end
  end

  return false
end

function SaveSlots:performAction()
  if not self.selectedSlot then return false end
  
  local slotName = "slot" .. self.selectedSlot
  
  if self.mode == "save" then
    local description = "Save Slot " .. self.selectedSlot .. " - " .. os.date("%m/%d %H:%M")
    return StateManager.saveGame(slotName, description)
  else
    return StateManager.loadGame(slotName)
  end
end

return SaveSlots
