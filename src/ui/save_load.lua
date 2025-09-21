local Theme = require("src.core.theme")
local StateManager = require("src.managers.state_manager")
local Window = require("src.ui.common.window")

local SaveLoad = {}

function SaveLoad:new()
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.selectedSlot = nil
    o.newSaveName = ""
    o.showNewSave = false
    o.window = Window.new({
        title = "Save & Load Game",
        width = 400,
        height = 500,
        drawContent = function(window, x, y, w, h) o:draw(player, x, y, w, h) end
    })
    return o
end

function SaveLoad:draw(player, x, y, w, h)
  local font = love.graphics.getFont()
  local lineHeight = font:getHeight() + 4
  local currentY = y + 10
  
  -- Title
  Theme.setColor(Theme.colors.text)
  love.graphics.print("Save & Load Game", x + 10, currentY)
  currentY = currentY + lineHeight * 1.5
  
  -- Quick actions
  Theme.setColor(Theme.colors.textSecondary)
  love.graphics.print("F5: Quick Save  |  F9: Quick Load", x + 10, currentY)
  currentY = currentY + lineHeight * 1.5
  
  -- Auto-save status
  local stats = StateManager.getStats()
  local statusText = string.format("Auto-save: %s | Last save: %s", 
    stats.autoSaveEnabled and "ON" or "OFF", 
    stats.lastSave)
  love.graphics.print(statusText, x + 10, currentY)
  currentY = currentY + lineHeight * 2
  
  -- New save section
  Theme.setColor(Theme.colors.accent)
  love.graphics.print("Create New Save:", x + 10, currentY)
  currentY = currentY + lineHeight
  
  -- New save input (placeholder for now - would need proper text input)
  Theme.setColor(Theme.colors.bg1)
  love.graphics.rectangle("fill", x + 10, currentY, w - 20, lineHeight * 1.2)
  Theme.setColor(Theme.colors.border)
  love.graphics.rectangle("line", x + 10, currentY, w - 20, lineHeight * 1.2)
  
  Theme.setColor(Theme.colors.text)
  local saveName = self.newSaveName ~= "" and self.newSaveName or "Enter save name..."
  love.graphics.print(saveName, x + 15, currentY + 2)
  currentY = currentY + lineHeight * 2
  
  -- Save button
  local saveButtonW = 80
  local saveButtonH = lineHeight * 1.5
  Theme.setColor(Theme.colors.success)
  love.graphics.rectangle("fill", x + 10, currentY, saveButtonW, saveButtonH)
  Theme.setColor(Theme.colors.text)
  love.graphics.print("Save", x + 35, currentY + 4)
  
  currentY = currentY + saveButtonH + lineHeight
  
  -- Existing saves
  Theme.setColor(Theme.colors.accent)
  love.graphics.print("Existing Saves:", x + 10, currentY)
  currentY = currentY + lineHeight
  
  -- List save slots
  local slots = StateManager.getSaveSlots()
  
  if #slots == 0 then
    Theme.setColor(Theme.colors.textSecondary)
    love.graphics.print("No save files found", x + 10, currentY)
  else
    for i, slot in ipairs(slots) do
      -- Skip auto-saves in main list (show them separately)
      if slot.name ~= "autosave" then
        local slotY = currentY
        local slotH = lineHeight * 2.5
        
        -- Background
        local bgColor = (self.selectedSlot == slot.name) and Theme.colors.bg2 or Theme.colors.bg1
        Theme.setColor(bgColor)
        love.graphics.rectangle("fill", x + 10, slotY, w - 20, slotH)
        
        -- Border
        Theme.setColor(Theme.colors.border)
        love.graphics.rectangle("line", x + 10, slotY, w - 20, slotH)
        
        -- Slot info
        Theme.setColor(Theme.colors.text)
        love.graphics.print(slot.description or slot.name, x + 15, slotY + 4)
        
        local infoText = string.format("Level %d | %d GC | %s", 
          slot.playerLevel or 1, 
          slot.playerCredits or 0, 
          slot.realTime or "Unknown time")
        Theme.setColor(Theme.colors.textSecondary)
        love.graphics.print(infoText, x + 15, slotY + lineHeight + 2)
        
        -- Load button
        local loadButtonX = x + w - 100
        local loadButtonW = 60
        local loadButtonH = lineHeight * 1.2
        Theme.setColor(Theme.colors.info)
        love.graphics.rectangle("fill", loadButtonX, slotY + 4, loadButtonW, loadButtonH)
        Theme.setColor(Theme.colors.text)
        love.graphics.print("Load", loadButtonX + 18, slotY + 8)
        
        -- Delete button
        local deleteButtonX = loadButtonX - 70
        Theme.setColor(Theme.colors.danger)
        love.graphics.rectangle("fill", deleteButtonX, slotY + 4, loadButtonW, loadButtonH)
        Theme.setColor(Theme.colors.text)
        love.graphics.print("Delete", deleteButtonX + 12, slotY + 8)
        
        currentY = currentY + slotH + 4
      end
    end
  end
  
  -- Auto-save section (at bottom)
  currentY = currentY + lineHeight
  Theme.setColor(Theme.colors.warning)
  love.graphics.print("Auto-Save:", x + 10, currentY)
  currentY = currentY + lineHeight
  
  -- Find autosave slot
  local autosave = nil
  for _, slot in ipairs(slots) do
    if slot.name == "autosave" then
      autosave = slot
      break
    end
  end
  
  if autosave then
    local autosaveY = currentY
    local autosaveH = lineHeight * 2
    
    Theme.setColor(Theme.colors.bg1)
    love.graphics.rectangle("fill", x + 10, autosaveY, w - 20, autosaveH)
    Theme.setColor(Theme.colors.border)
    love.graphics.rectangle("line", x + 10, autosaveY, w - 20, autosaveH)
    
    Theme.setColor(Theme.colors.text)
    love.graphics.print("Auto-save " .. (autosave.realTime or "Unknown"), x + 15, autosaveY + 4)
    
    local autoInfo = string.format("Level %d | %d GC", 
      autosave.playerLevel or 1, 
      autosave.playerCredits or 0)
    Theme.setColor(Theme.colors.textSecondary)
    love.graphics.print(autoInfo, x + 15, autosaveY + lineHeight + 2)
    
    -- Auto-save load button
    local autoLoadButtonX = x + w - 80
    local autoLoadButtonW = 60
    local autoLoadButtonH = lineHeight * 1.2
    Theme.setColor(Theme.colors.warning)
    love.graphics.rectangle("fill", autoLoadButtonX, autosaveY + 4, autoLoadButtonW, autoLoadButtonH)
    Theme.setColor(Theme.colors.text)
    love.graphics.print("Load", autoLoadButtonX + 18, autosaveY + 8)
  else
    Theme.setColor(Theme.colors.textSecondary)
    love.graphics.print("No auto-save available", x + 10, currentY)
  end
end

function SaveLoad:mousepressed(player, x, y, button, w, h)
  if button ~= 1 then return false end

  local font = love.graphics.getFont()
  local lineHeight = font:getHeight() + 4
  local checkY = y + lineHeight * 6.5 -- Approximate position after header

  -- Check new save button
  if x >= 10 and x <= 90 and y >= checkY and y <= checkY + lineHeight * 1.5 then
    -- Create new save with current timestamp as name
    local saveName = self.newSaveName ~= "" and self.newSaveName or ("Save " .. os.date("%H%M%S"))
    StateManager.saveGame(saveName, "Manual save - " .. os.date("%Y-%m-%d %H:%M:%S"))
    return true
  end

  -- Check save slots for load/delete buttons
  local slots = StateManager.getSaveSlots()
  local currentY = checkY + lineHeight * 4 -- Approximate start of save list

  for i, slot in ipairs(slots) do
    if slot.name ~= "autosave" then
      local slotH = lineHeight * 2.5
      local slotY = currentY

      -- Load button area (positioned relative to the window)
      local loadButtonX = x + w - 100
      if x >= loadButtonX and x <= loadButtonX + 60 and y >= slotY + 4 and y <= slotY + lineHeight * 1.2 + 4 then
        StateManager.loadGame(slot.name)
        return true
      end

      -- Delete button area (positioned relative to the window)
      local deleteButtonX = x + w - 170
      if x >= deleteButtonX and x <= deleteButtonX + 60 and y >= slotY + 4 and y <= slotY + lineHeight * 1.2 + 4 then
        StateManager.deleteSave(slot.name)
        return true
      end

      currentY = currentY + slotH + 4
    end
  end

  return false
end

function SaveLoad:textinput(text)
  -- Simple text input for save name
  if text and text:match("[%w%s%-_]") then
    if #self.newSaveName < 30 then
      self.newSaveName = self.newSaveName .. text
    end
    return true
  end
  return false
end

function SaveLoad:keypressed(key)
  if key == "backspace" and #self.newSaveName > 0 then
    self.newSaveName = self.newSaveName:sub(1, -2)
    return true
  end
  return false
end

return SaveLoad