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
  
  -- Styling
  self.titleBarHeight = 32  -- Match other panels like inventory
  self.borderSize = 2
  self.cornerRadius = 0
  self.shadow = options.shadow ~= false -- default true

  -- Aurora title shader (optional)
  self.auroraShader = nil
  
  -- Content area callback
  self.drawContent = options.drawContent
  
  -- Event callbacks
  self.onClose = options.onClose
  self.onResize = options.onResize
  self.onMove = options.onMove

  -- Initialize aurora shader for title effect (lazy initialization)
  self.auroraShader = nil

  return self
end

-- Show the window
function Window:show()
  self.visible = true
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
    h = self.height - self.titleBarHeight - self.borderSize
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
  
  -- Draw window background (unified panel)
  Theme.setColor(Theme.colors.windowBg)
  love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
  
  -- Title bar separator line
  Theme.setColor(Theme.colors.border)
  love.graphics.line(self.x, self.y + self.titleBarHeight, self.x + self.width, self.y + self.titleBarHeight)
  
  -- Window title (scaled to fit available space) with aurora effect
  local paddingLeft = 8
  local paddingRight = (self.closable and (20 + 6) or 8)  -- Adjusted for smaller close button
  local maxTextW = math.max(10, self.width - paddingLeft - paddingRight)
  local baseFont = Theme.fonts and Theme.fonts.small or love.graphics.getFont()  -- Use smaller font
  local fontH = baseFont:getHeight()
  local scale = math.max(0.7, math.min(1.4, maxTextW / math.max(1, baseFont:getWidth(self.title))))
  local titleY = self.y + (self.titleBarHeight - fontH * scale) * 0.5

  -- Initialize aurora shader if needed
  if not self.auroraShader then
    self.auroraShader = AuroraTitle.new()
  end

  -- Aurora shader fill (fallback to static color if shader unavailable)
  if self.auroraShader then
    self.auroraShader:send("time", love.timer.getTime())
    love.graphics.setShader(self.auroraShader)
    Theme.setColor(1, 1, 1, 1)
    love.graphics.printf(self.title, self.x + paddingLeft, titleY, maxTextW, "left")
    love.graphics.setShader()
  else
    -- Fallback to static aurora-like color
    Theme.setColor({0.4, 0.8, 1.0, 1.0})  -- Cyan aurora color
    love.graphics.printf(self.title, self.x + paddingLeft, titleY, maxTextW, "left")
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
  
  -- Content background
  Theme.setColor(Theme.colors.bg1)
  love.graphics.rectangle("fill", content.x, content.y, content.w, content.h)
  
  -- Draw custom content
  if self.drawContent then
    -- Set up clipping to content area
    love.graphics.push()
    love.graphics.intersectScissor(content.x, content.y, content.w, content.h)
    
    self.drawContent(self, content.x, content.y, content.w, content.h)
    
    love.graphics.pop()
  end
  
  -- Window border
  Theme.drawEVEBorder(self.x, self.y, self.width, self.height, self.cornerRadius,
                     Theme.colors.borderBright, 8)
end

-- Handle mouse press
function Window:mousepressed(x, y, button)
  if not self.visible then return false end
  
  if button == 1 then
    -- Close button
    if self.closable and self:pointInCloseButton(x, y) then
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
