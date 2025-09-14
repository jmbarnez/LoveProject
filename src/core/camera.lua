local Viewport = require("src.core.viewport")

local Camera = {}
Camera.__index = Camera

function Camera.new()
  local self = setmetatable({}, Camera)
  self.x, self.y = 0, 0
  -- Default zoomed out to 0.5x (new baseline)
  self.scale = 0.5
  self.targetScale = 0.5
  self.minScale = 0.25
  self.maxScale = 2.0
  self.zoomLerp = 8 -- how quickly zoom eases to target
  self.target = nil
  self.smooth = 6
  return self
end

function Camera:setTarget(t)
  self.target = t
  if t and t.components and t.components.position then self.x, self.y = t.components.position.x, t.components.position.y end
end

function Camera:update(dt)
  if self.target and self.target.components and self.target.components.position then
    self.x = self.x + (self.target.components.position.x - self.x) * math.min(1, self.smooth * dt)
    self.y = self.y + (self.target.components.position.y - self.y) * math.min(1, self.smooth * dt)
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

function Camera:screenToWorld(sx, sy)
  local w, h = Viewport.getDimensions()
  local x = (sx - w * 0.5) / self.scale + self.x
  local y = (sy - h * 0.5) / self.scale + self.y
  return x, y
end

function Camera:setZoom(scale)
  local s = math.max(self.minScale, math.min(self.maxScale, scale))
  self.targetScale = s
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
