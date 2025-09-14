local Theme = require("src.core.theme")
local StateManager = require("src.managers.state_manager")
local Notifications = require("src.ui.notifications")

local SaveSlots = {}

function SaveSlots:new()
  local o = {}
  setmetatable(o, self)
  self.__index = self
  o.mode = "save" -- "save" or "load"
  o.selectedSlot = nil
  return o
end

function SaveSlots:setMode(mode)
  self.mode = mode
end

function SaveSlots:draw(x, y, w, h)
  local font = love.graphics.getFont()
  local lineHeight = font:getHeight() + 4
  local currentY = y + 20
  
  -- Title
  Theme.setColor(Theme.colors.text)
  local titleText = self.mode == "save" and "Save Game" or "Load Game"
  local titleW = font:getWidth(titleText)
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
  local slotHeight = 80
  local slotMargin = 10
  
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
    love.graphics.rectangle("fill", x + 30, slotY, w - 60, slotHeight)
    
    -- Border
    local borderColor = self.selectedSlot == i and Theme.colors.accent or Theme.colors.border
    Theme.setColor(borderColor)
    love.graphics.rectangle("line", x + 30, slotY, w - 60, slotHeight)
    
    -- Slot number
    Theme.setColor(Theme.colors.accent)
    love.graphics.print("Slot " .. i, x + 40, slotY + 10)
    
    if isEmpty then
      -- Empty slot
      Theme.setColor(Theme.colors.textSecondary)
      love.graphics.print("Empty", x + 40, slotY + 30)
    else
      -- Existing save
      Theme.setColor(Theme.colors.text)
      local description = slot.description or ("Save " .. i)
      love.graphics.print(description, x + 40, slotY + 30)
      
      -- Save info
      local infoText = string.format("Level %d | %d GC | %s", 
        slot.playerLevel or 1, 
        slot.playerCredits or 0, 
        slot.realTime or "Unknown")
      Theme.setColor(Theme.colors.textSecondary)
      love.graphics.print(infoText, x + 40, slotY + 50)
      
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
    
    local buttonW = 60
    local buttonH = 30
    local buttonSpacing = 10
    local buttonsX = x + w - (buttonW * 2 + buttonSpacing) - 40  -- More margin from edge
    local buttonY = slotY + slotHeight - buttonH - 15  -- More margin from bottom
    
    -- Action button (Save/Load)
    if not isEmpty or self.mode == "save" then
      local actionColor = self.mode == "save" and Theme.colors.success or Theme.colors.info
      local actionText = self.mode == "save" and "Save" or "Load"
      
      -- Use styled button from theme (hover detection will be handled by the theme)
      local hover = false -- We'll let the theme handle hover detection
      
      Theme.drawStyledButton(buttonsX, buttonY, buttonW, buttonH, actionText, hover, love.timer.getTime(), actionColor, false)
    end
    
    -- Delete button (only for existing saves)
    if not isEmpty then
      local deleteX = buttonsX + buttonW + buttonSpacing
      
      local deleteHover = false -- Let the theme handle hover detection
      
      Theme.drawStyledButton(deleteX, buttonY, buttonW, buttonH, "Delete", deleteHover, love.timer.getTime(), Theme.colors.danger, false)
    end
  end
end

function SaveSlots:mousepressed(x, y, button, drawX, drawY, drawW, drawH)
  if button ~= 1 then return false end
  
  -- Use the same coordinate calculations as in draw()
  local font = love.graphics.getFont()
  local lineHeight = font:getHeight() + 4
  local currentY = drawY + 20 + lineHeight * 2 + lineHeight * 1.5  -- Title + instructions
  local slotHeight = 80
  local slotMargin = 10
  
  -- Get save slots data
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
  
  -- Check button clicks for each slot
  for i = 1, 3 do
    local slotY = currentY + (i - 1) * (slotHeight + slotMargin)
    local slot = slots[i]
    local isEmpty = slot == nil
    
    -- Skip if we'd draw outside the container
    if slotY + slotHeight > drawY + drawH then
      break
    end
    
    local buttonW = 60
    local buttonH = 30
    local buttonSpacing = 10
    local buttonsX = drawX + drawW - (buttonW * 2 + buttonSpacing) - 40  -- More margin from edge
    local buttonY = slotY + slotHeight - buttonH - 15  -- More margin from bottom
    
    -- Check action button (Save/Load)
    if (not isEmpty or self.mode == "save") and x >= buttonsX and x <= buttonsX + buttonW and y >= buttonY and y <= buttonY + buttonH then
      local slotName = "slot" .. i
      if self.mode == "save" then
        local description = "Save Slot " .. i .. " - " .. os.date("%m/%d %H:%M")
        local success = StateManager.saveGame(slotName, description)
        if success then
          Notifications.add("Game saved to Slot " .. i, "success")
          return "saved"
        else
          Notifications.add("Failed to save game", "error")
          return false
        end
      else
        -- For start screen, don't actually load yet - just return the slot number
        if StateManager.currentPlayer then
          local success = StateManager.loadGame(slotName)
          if success then
            Notifications.add("Game loaded from Slot " .. i, "info")
            return "loaded"
          else
            Notifications.add("Failed to load game", "error")
            return false
          end
        else
          -- Game not initialized yet, return slot info for later loading
          self.selectedSlot = i
          return "loadSelected"
        end
      end
    end
    
    -- Check delete button (only for existing saves)
    if not isEmpty then
      local deleteX = buttonsX + buttonW + buttonSpacing
      if x >= deleteX and x <= deleteX + buttonW and y >= buttonY and y <= buttonY + buttonH then
        local slotName = "slot" .. i
        local success = StateManager.deleteSave(slotName)
        if success then
          Notifications.add("Deleted save from Slot " .. i, "warning")
        else
          Notifications.add("Failed to delete save", "error")
        end
        return "deleted"
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