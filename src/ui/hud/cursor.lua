local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")

local UICursor = {}

-- Current cursor state
local visible = false

function UICursor.setVisible(isVisible)
  visible = isVisible
end

function UICursor.isVisible()
  return visible
end

function UICursor.draw()
  if not visible then return end
  
  local mx, my = Viewport.getMousePosition()
  
  love.graphics.push()
  love.graphics.translate(mx, my)
  
  -- Basic pointer triangle (wider, shorter)
  local s = 24
  local angle = -0.18
  local ca, sa = math.cos(angle), math.sin(angle)
  local function rot(x, y)
    return x * ca - y * sa, x * sa + y * ca
  end

  -- Wider, shorter pointer with blunted tip
  local tipx, tipy = rot(0, 0)
  local e1x, e1y = rot(s * 1.05, s * 1.10)  -- Wider span, reduced height
  local e2x, e2y = rot(s * 0.58, s * 0.85)  -- Fatter tail, shorter
  -- Flat tip edge (avoid needle look)
  local tipWidth = s * 0.18
  local tipDepth = s * 0.10
  local tLx, tLy = rot(-tipWidth * 0.5, tipDepth)
  local tRx, tRy = rot(tipWidth * 0.5, tipDepth)

  -- Fill with theme accent
  Theme.setColor({ Theme.colors.accent[1], Theme.colors.accent[2], Theme.colors.accent[3], 1.0 })
  love.graphics.polygon('fill', tLx, tLy, e1x, e1y, e2x, e2y, tRx, tRy)

  -- White border
  Theme.setColor({ 1.0, 1.0, 1.0, 1.0 })
  love.graphics.setLineWidth(2)
  love.graphics.polygon('line', tLx, tLy, e1x, e1y, e2x, e2y, tRx, tRy)
  
  love.graphics.pop()
end

-- Apply cursor settings from graphics settings
function UICursor.applySettings()
  -- Cursor now uses theme colors automatically
  -- No custom color settings needed
end

return UICursor