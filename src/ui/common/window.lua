local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local AuroraTitle = require("src.shaders.aurora_title")

local Window = {}
Window.__index = Window

-- Create a new reusable window
function Window.new(options)
  options = options or {}
  
  local self = setmetatable({}, Window)
  
  -- Window properties
  self.title = options.title or "Window"
  self.width = options.width or 400
  self.height = options.height or 300
  self.minWidth = options.minWidth or 200
  self.minHeight = options.minHeight or 150
  self.maxWidth = options.maxWidth or nil
  self.maxHeight = options.maxHeight or nil
  
  -- Position (centered by default)
  local sw, sh = Viewport.getDimensions()
  self.x = options.x or math.floor((sw - self.width) * 0.5)
  self.y = options.y or math.floor((sh - self.height) * 0.5)
  
  -- Window state
  self.visible = options.visible or false
  self.closable = options.closable ~= false -- default true
  self.draggable = options.draggable ~= false -- default true
  self.resizable = options.resizable or false
  self.modal = options.modal or false
  self.maximizable = options.maximizable ~= false -- default true
  self.maximized = false
  
  -- Drag state
  self.dragging = false
  self.dragOffsetX = 0
  self.dragOffsetY = 0
  
  -- Resize state
  self.resizing = false
  self.resizeHandle = nil
  self.resizeStartX = 0
  self.resizeStartY = 0
  self.resizeStartW = 0
  self.resizeStartH = 0
  
  -- Maximize state
  self.originalX = self.x
  self.originalY = self.y
  self.originalWidth = self.width
  self.originalHeight = self.height
  
  -- Styling
  self.titleBarHeight = (Theme.ui and Theme.ui.titleBarHeight) or 24
  self.borderSize = (Theme.ui and Theme.ui.borderWidth) or 2
  self.cornerRadius = 0
  self.shadow = options.shadow ~= false -- default true
  self.useLoadPanelTheme = options.useLoadPanelTheme or false
  self.bottomBarHeight = options.bottomBarHeight or 0

  
  -- Content area callback
  self.drawContent = options.drawContent
  
  -- Event callbacks
  self.onClose = options.onClose
  self.onResize = options.onResize
  self.onMove = options.onMove


  return self
end

-- Show the window
function Window:show()
  self.visible = true
  if self.onShow then
    self.onShow(self)
  end
end

-- Hide the window
function Window:hide()
  self.visible = false
  if self.onClose then
    self.onClose(self)
  end
end

-- Toggle window visibility
function Window:toggle()
  if self.visible then
    self:hide()
  else
    self:show()
  end
end

-- Get content area bounds
function Window:getContentBounds()
  return {
    x = self.x + self.borderSize,
    y = self.y + self.titleBarHeight,
    w = self.width - self.borderSize * 2,
    h = self.height - self.titleBarHeight - self.borderSize - self.bottomBarHeight
  }
end

-- Check if point is in window
function Window:containsPoint(x, y)
  return x >= self.x and x <= self.x + self.width and
         y >= self.y and y <= self.y + self.height
end

-- Check if point is in title bar
function Window:pointInTitleBar(x, y)
  return x >= self.x and x <= self.x + self.width and
         y >= self.y and y <= self.y + self.titleBarHeight
end

-- Check if point is in close button
function Window:pointInCloseButton(x, y)
  if not self.closable then return false end

  local btnSize = 20  -- Smaller button size
  local btnX = self.x + self.width - btnSize - 3
  local btnY = self.y + 2

  return x >= btnX and x <= btnX + btnSize and
         y >= btnY and y <= btnY + btnSize
end

-- Check if point is in maximize button
function Window:pointInMaximizeButton(x, y)
  if not self.maximizable then return false end

  local btnSize = 20  -- Same size as close button
  local btnX = self.x + self.width - btnSize - 3 - (self.closable and (btnSize + 3) or 0)
  local btnY = self.y + 2

  return x >= btnX and x <= btnX + btnSize and
         y >= btnY and y <= btnY + btnSize
end

-- Maximize window
function Window:maximize()
  if not self.maximizable or self.maximized then return end
  
  -- Store original state
  self.originalX = self.x
  self.originalY = self.y
  self.originalWidth = self.width
  self.originalHeight = self.height
  
  -- Maximize to screen
  local sw, sh = Viewport.getDimensions()
  self.x = 0
  self.y = 0
  self.width = sw
  self.height = sh
  
  self.maximized = true
end

-- Restore window
function Window:restore()
  if not self.maximized then return end
  
  -- Restore original state
  self.x = self.originalX
  self.y = self.originalY
  self.width = self.originalWidth
  self.height = self.originalHeight
  
  self.maximized = false
end

-- Toggle maximize/restore
function Window:toggleMaximize()
  if self.maximized then
    self:restore()
  else
    self:maximize()
  end
end

-- Get resize handle at point
function Window:getResizeHandle(x, y)
  if not self.resizable then return nil end
  
  local handleSize = 8
  local right = self.x + self.width
  local bottom = self.y + self.height
  
  -- Corner handles
  if x >= right - handleSize and y >= bottom - handleSize then
    return "se" -- southeast
  elseif x <= self.x + handleSize and y >= bottom - handleSize then
    return "sw" -- southwest
  elseif x >= right - handleSize and y <= self.y + handleSize then
    return "ne" -- northeast
  elseif x <= self.x + handleSize and y <= self.y + handleSize then
    return "nw" -- northwest
  end
  
  -- Edge handles
  if x >= right - handleSize then
    return "e" -- east
  elseif x <= self.x + handleSize then
    return "w" -- west
  elseif y >= bottom - handleSize then
    return "s" -- south
  elseif y <= self.y + handleSize then
    return "n" -- north
  end
  
  return nil
end

-- Draw the window
function Window:draw()
  if not self.visible then return end

  local mx, my = Viewport.getMousePosition()

  -- Draw solid dark black background for entire window
  Theme.setColor(Theme.colors.bg0)
  love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)

  -- Title bar separator line (always draw for all windows)
  Theme.setColor(Theme.colors.border)
  love.graphics.line(self.x, self.y + self.titleBarHeight, self.x + self.width, self.y + self.titleBarHeight)

  -- Maximize button
  if self.maximizable then
    local btnSize = 20  -- Same size as close button
    local btnX = self.x + self.width - btnSize - 3 - (self.closable and (btnSize + 3) or 0)
    local btnY = self.y + 2
    local maximizeHover = self:pointInMaximizeButton(mx, my)
    
    Theme.drawMaximizeButton({x = btnX, y = btnY, w = btnSize, h = btnSize}, maximizeHover, self.maximized)
  end
  
  -- Close button
  if self.closable then
    local btnSize = 20  -- Smaller close button for thinner title bar
    local btnX = self.x + self.width - btnSize - 3
    local btnY = self.y + 2
    local closeHover = self:pointInCloseButton(mx, my)
    
    Theme.drawCloseButton({x = btnX, y = btnY, w = btnSize, h = btnSize}, closeHover)
  end
  
  -- Draw content area
  local content = self:getContentBounds()

  -- Content background with load panel theme if enabled
  if self.useLoadPanelTheme then
    -- Skip content background for load panel theme to avoid visual bar
    -- Theme.setColor(Theme.colors.bg1)
    -- love.graphics.rectangle("fill", content.x, content.y, content.w, content.h)
  else
    -- Original content background
    Theme.setColor(Theme.colors.bg1)
    love.graphics.rectangle("fill", content.x, content.y, content.w, content.h)
  end
  
  -- Draw custom content
  if self.drawContent then
    -- Set up clipping to content area
    love.graphics.push()
    love.graphics.intersectScissor(content.x, content.y, content.w, content.h)
    
    self.drawContent(self, content.x, content.y, content.w, content.h)
    
    love.graphics.pop()
    -- IMPORTANT: Reset scissor after drawing content so subsequent frames
    -- and other draw calls aren't clipped to the window's content area.
    love.graphics.setScissor()
  end
  
  -- Window border with load panel theme if enabled
  if self.useLoadPanelTheme then
    -- Use sci-fi frame border for load panel theme
    Theme.drawSciFiFrame(self.x, self.y, self.width, self.height)
  else
    -- Simple window border without colored corners
    Theme.setColor(Theme.colors.border)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", math.floor(self.x + 0.5), math.floor(self.y + 0.5), self.width, self.height)
  end
end

-- Handle mouse press
function Window:mousepressed(x, y, button)
  if not self.visible then return false end
  
  if button == 1 then
    -- Maximize button
    if self.maximizable and self:pointInMaximizeButton(x, y) then
      self:toggleMaximize()
      return true
    end
    
    -- Close button
    if self.closable and self:pointInCloseButton(x, y) then
      -- Play click sound
      local Sound = require("src.core.sound")
      Sound.triggerEvent('ui_button_click')
      self:hide()
      return true
    end
    
    -- Resize handle
    if self.resizable then
      local handle = self:getResizeHandle(x, y)
      if handle then
        self.resizing = true
        self.resizeHandle = handle
        self.resizeStartX = x
        self.resizeStartY = y
        self.resizeStartW = self.width
        self.resizeStartH = self.height
        return true
      end
    end
    
    -- Title bar drag
    if self.draggable and self:pointInTitleBar(x, y) then
      self.dragging = true
      self.dragOffsetX = x - self.x
      self.dragOffsetY = y - self.y
      return true
    end
    
    -- Check if click is within window bounds, but not in the title bar
    if self:containsPoint(x, y) and not self:pointInTitleBar(x, y) then
      -- Don't consume the click, let the content handle it
      return false
    end
    
    -- Consume clicks on the title bar or outside the window if it's modal
    if self:pointInTitleBar(x, y) or (self.modal and not self:containsPoint(x, y)) then
      return true
    end
  end
  
  return false
end

-- Handle mouse release
function Window:mousereleased(x, y, button)
  if not self.visible then return false end
  
  if button == 1 then
    if self.dragging then
      self.dragging = false
      if self.onMove then
        self.onMove(self, self.x, self.y)
      end
      return true
    end
    
    if self.resizing then
      self.resizing = false
      if self.onResize then
        self.onResize(self, self.width, self.height)
      end
      return true
    end
  end
  
  return false
end

-- Handle mouse movement
function Window:mousemoved(x, y, dx, dy)
  if not self.visible then return false end
  
  if self.dragging then
    local newX = x - self.dragOffsetX
    local newY = y - self.dragOffsetY
    
    -- Keep window on screen
    local sw, sh = Viewport.getDimensions()
    newX = math.max(0, math.min(sw - self.width, newX))
    newY = math.max(0, math.min(sh - self.height, newY))
    
    self.x = newX
    self.y = newY
    return true
  end
  
  if self.resizing then
    local dx = x - self.resizeStartX
    local dy = y - self.resizeStartY
    
    if string.find(self.resizeHandle, "e") then
      self.width = math.max(self.minWidth, self.resizeStartW + dx)
      if self.maxWidth then
        self.width = math.min(self.maxWidth, self.width)
      end
    end
    
    if string.find(self.resizeHandle, "s") then
      self.height = math.max(self.minHeight, self.resizeStartH + dy)
      if self.maxHeight then
        self.height = math.min(self.maxHeight, self.height)
      end
    end
    
    return true
  end
  
  return false
end

return Window
