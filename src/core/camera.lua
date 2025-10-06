local Viewport = require("src.core.viewport")

local Camera = {}
Camera.__index = Camera

function Camera.new()
  local self = setmetatable({}, Camera)
  self.x, self.y = 0, 0
  
  -- Smooth zoom with continuous scaling
  self.scale = 0.5 -- Start at 0.5x zoom
  self.targetScale = self.scale
  self.minScale = 0.5 -- Minimum zoom out to 0.5x
  self.maxScale = 2.0 -- Maximum zoom in to 2.0x
  self.zoomLerp = 8 -- Smooth zoom transition speed
  self.zoomSpeed = 0.1 -- Speed of zoom changes per wheel tick
  self.target = nil
  self.smooth = 6
  
  -- Camera deviation properties
  self.deviationX = 0
  self.deviationY = 0
  self.maxDeviation = 300 -- Maximum deviation distance in pixels (increased from 200)
  self.deviationLerp = 8 -- How quickly deviation returns to center (increased for stiffer feel)
  self.movementDeviation = 0.1 -- How much movement affects deviation (reduced significantly)
  self.cursorDeviation = 0.15 -- How much cursor position affects deviation (much reduced for stiffer feel)
  
  return self
end

function Camera:setTarget(t)
  self.target = t
  if t and t.components and t.components.position then self.x, self.y = t.components.position.x, t.components.position.y end
end

function Camera:update(dt)
  if self.target and self.target.components and self.target.components.position then
    local targetX = self.target.components.position.x
    local targetY = self.target.components.position.y
    
    -- Calculate deviation based on movement and cursor position
    local targetDeviationX = 0
    local targetDeviationY = 0
    
    -- Movement-based deviation
    if self.target.components.physics and self.target.components.physics.body then
      local body = self.target.components.physics.body
      local velocity = math.sqrt(body.vx * body.vx + body.vy * body.vy)
      if velocity > 20 then -- Only apply deviation when moving fast (increased threshold)
        local moveAngle = math.atan2(body.vy, body.vx)
        local deviationAmount = math.min(velocity * self.movementDeviation, self.maxDeviation)
        targetDeviationX = math.cos(moveAngle) * deviationAmount
        targetDeviationY = math.sin(moveAngle) * deviationAmount
      end
    end
    
    -- Cursor-based deviation removed to prevent circular dependency
    -- Camera deviation should only be based on movement, not cursor position
    -- This ensures accurate cursor-to-world coordinate conversion
    
    -- Clamp total deviation to maxDeviation
    local totalDeviation = math.sqrt(targetDeviationX * targetDeviationX + targetDeviationY * targetDeviationY)
    if totalDeviation > self.maxDeviation then
      local scale = self.maxDeviation / totalDeviation
      targetDeviationX = targetDeviationX * scale
      targetDeviationY = targetDeviationY * scale
    end
    
    -- Smooth deviation towards target
    self.deviationX = self.deviationX + (targetDeviationX - self.deviationX) * math.min(1, self.deviationLerp * dt)
    self.deviationY = self.deviationY + (targetDeviationY - self.deviationY) * math.min(1, self.deviationLerp * dt)
    
    -- Apply deviation to camera position
    local finalTargetX = targetX + self.deviationX
    local finalTargetY = targetY + self.deviationY
    
    self.x = self.x + (finalTargetX - self.x) * math.min(1, self.smooth * dt)
    self.y = self.y + (finalTargetY - self.y) * math.min(1, self.smooth * dt)
  end
  
  -- Smooth zoom towards targetScale
  if self.targetScale and self.scale ~= self.targetScale then
    local k = math.min(1, (self.zoomLerp or 8) * dt)
    self.scale = self.scale + (self.targetScale - self.scale) * k
  end
end

function Camera:apply()
  love.graphics.push()
  local w, h = Viewport.getDimensions()
  love.graphics.translate(w * 0.5, h * 0.5)
  love.graphics.scale(self.scale, self.scale)
  love.graphics.translate(-math.floor(self.x), -math.floor(self.y))
end

function Camera:reset()
  love.graphics.pop()
end
function Camera:getBounds()
    local w = love.graphics.getWidth() / self.scale
    local h = love.graphics.getHeight() / self.scale
    -- Account for camera deviation in bounds calculation
    local cameraX = self.x + self.deviationX
    local cameraY = self.y + self.deviationY
    local x = cameraX - w / 2
    local y = cameraY - h / 2
    return x, y, w, h
end


function Camera:screenToWorld(sx, sy)
  local w, h = Viewport.getDimensions()
  -- Account for camera deviation in coordinate conversion
  local cameraX = self.x + self.deviationX
  local cameraY = self.y + self.deviationY
  local x = (sx - w * 0.5) / self.scale + cameraX
  local y = (sy - h * 0.5) / self.scale + cameraY
  return x, y
end

function Camera:worldToScreen(wx, wy)
  local w, h = Viewport.getDimensions()
  -- Account for camera deviation in coordinate conversion
  local cameraX = self.x + self.deviationX
  local cameraY = self.y + self.deviationY
  local sx = (wx - cameraX) * self.scale + w * 0.5
  local sy = (wy - cameraY) * self.scale + h * 0.5
  return sx, sy
end

function Camera:setZoom(scale)
  local s = math.max(self.minScale, math.min(self.maxScale, scale))
  self.targetScale = s
end

-- Smooth zoom in
function Camera:zoomIn()
  local newScale = self.targetScale + self.zoomSpeed
  self.targetScale = math.min(self.maxScale, newScale)
end

-- Smooth zoom out
function Camera:zoomOut()
  local newScale = self.targetScale - self.zoomSpeed
  self.targetScale = math.max(self.minScale, newScale)
end

-- Get current zoom scale
function Camera:getZoomScale()
  return self.scale
end

-- Get target zoom scale
function Camera:getTargetZoomScale()
  return self.targetScale
end

-- Camera deviation control functions
function Camera:setDeviationSettings(settings)
  if settings.maxDeviation then self.maxDeviation = settings.maxDeviation end
  if settings.deviationLerp then self.deviationLerp = settings.deviationLerp end
  if settings.movementDeviation then self.movementDeviation = settings.movementDeviation end
  if settings.cursorDeviation then self.cursorDeviation = settings.cursorDeviation end
end

function Camera:resetDeviation()
  self.deviationX = 0
  self.deviationY = 0
end

function Camera:getDeviation()
  return self.deviationX, self.deviationY
end

-- Zoom by multiplicative factor at a given screen pivot (sx, sy)
function Camera:zoomAtFactor(factor, sx, sy)
  local w, h = Viewport.getDimensions()
  local newTarget = math.max(self.minScale, math.min(self.maxScale, (self.targetScale or self.scale) * factor))
  -- Keep world point under cursor stable when zoom finishes
  local wx = (sx - w * 0.5) / self.scale + self.x
  local wy = (sy - h * 0.5) / self.scale + self.y
  self.targetScale = newTarget
  -- Adjust camera position towards desired center for the target scale
  self.x = wx - (sx - w * 0.5) / newTarget
  self.y = wy - (sy - h * 0.5) / newTarget
end

function Camera:setZoomBounds(minScale, maxScale)
  self.minScale, self.maxScale = minScale, maxScale
  self.targetScale = math.max(self.minScale, math.min(self.maxScale, self.targetScale or self.scale))
  self.scale = math.max(self.minScale, math.min(self.maxScale, self.scale))
end

return Camera
