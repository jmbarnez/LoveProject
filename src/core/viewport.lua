local Viewport = {}

-- Default virtual resolution (16:9)
local vw, vh = 1920, 1080
local winW, winH = 1920, 1080
local scale = 1
local ox, oy = 0, 0
local canvas

function Viewport.init(virtualW, virtualH)
  vw, vh = virtualW or vw, virtualH or vh
  -- Create the render target once
  if not canvas or canvas:getWidth() ~= vw or canvas:getHeight() ~= vh then
    canvas = love.graphics.newCanvas(vw, vh)
    -- Use nearest neighbor filtering for crisp UI and text
    canvas:setFilter('nearest', 'nearest', 1)
  end
  Viewport.resize(love.graphics.getWidth(), love.graphics.getHeight())
end

function Viewport.resize(w, h)
  winW, winH = w, h
  -- Calculate viewport scale without UI scale affecting it
  local sx = w / vw
  local sy = h / vh
  scale = math.min(sx, sy)
  local sw = math.floor(vw * scale + 0.5)
  local sh = math.floor(vh * scale + 0.5)
  ox = math.floor((w - sw) / 2)
  oy = math.floor((h - sh) / 2)
end

function Viewport.begin()
  love.graphics.push('all')
  -- Enable stencil writes while rendering to the virtual canvas
  love.graphics.setCanvas({ canvas, stencil = true })
  -- Do not clear here; let game decide its clear color
end

function Viewport.finish()
  love.graphics.setCanvas()
  -- Clear the backbuffer to black (letterbox bars)
  love.graphics.clear(0, 0, 0, 1)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(canvas, ox, oy, 0, scale, scale)
  love.graphics.pop()
end

function Viewport.toVirtual(x, y)
  return (x - ox) / scale, (y - oy) / scale
end

function Viewport.toScreen(x, y)
  return x * scale + ox, y * scale + oy
end

function Viewport.getMousePosition()
  local mx, my = love.mouse.getPosition()
  return Viewport.toVirtual(mx, my)
end

function Viewport.getScale()
  return scale
end

function Viewport.getOffset()
  return ox, oy
end

function Viewport.getDimensions()
  return vw, vh
end

function Viewport.getUIScale()
  local settings = require("src.core.settings")
  local graphicsSettings = settings.getGraphicsSettings()
  return graphicsSettings.ui_scale or 1.0
end

function Viewport.getFontScale()
  local settings = require("src.core.settings")
  local graphicsSettings = settings.getGraphicsSettings()
  return graphicsSettings.font_scale or 1.0
end

function Viewport.isInsideScreen(x, y)
  return x >= ox and y >= oy and x <= ox + vw * scale and y <= oy + vh * scale
end

return Viewport
