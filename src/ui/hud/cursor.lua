local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")

local UICursor = {}

-- Current cursor state
local visible = false
local animationTime = 0
local pulsePhase = 0

function UICursor.setVisible(isVisible)
  visible = isVisible
end

function UICursor.isVisible()
  return visible
end

function UICursor.update(dt)
  animationTime = animationTime + dt
  pulsePhase = pulsePhase + dt * 3 -- Pulse every ~2 seconds
end

function UICursor.draw()
  if not visible then return end

  local mx, my = Viewport.getMousePosition()
  local time = love.timer.getTime()

  love.graphics.push()
  love.graphics.translate(mx, my)

  -- Pulsing glow effect
  local pulse = (math.sin(pulsePhase) + 1) * 0.5 -- 0 to 1
  local glowAlpha = 0.1 + pulse * 0.2

  -- Outer glow ring
  Theme.setColor(Theme.colors.glowStrong)
  love.graphics.setLineWidth(1.5)
  love.graphics.circle('line', 0, 0, 9)

  -- Inner glow ring
  Theme.setColor(Theme.withAlpha(Theme.colors.glow, glowAlpha))
  love.graphics.setLineWidth(1)
  love.graphics.circle('line', 0, 0, 6)

  -- Main targeting reticle (4 corners)
  Theme.setColor(Theme.colors.accent)
  love.graphics.setLineWidth(1)

  local reticleSize = 4
  local reticleGap = 2

  -- Top-left corner
  love.graphics.line(-reticleGap, -reticleGap, -reticleGap - reticleSize, -reticleGap)
  love.graphics.line(-reticleGap, -reticleGap, -reticleGap, -reticleGap - reticleSize)

  -- Top-right corner
  love.graphics.line(reticleGap, -reticleGap, reticleGap + reticleSize, -reticleGap)
  love.graphics.line(reticleGap, -reticleGap, reticleGap, -reticleGap - reticleSize)

  -- Bottom-left corner
  love.graphics.line(-reticleGap, reticleGap, -reticleGap - reticleSize, reticleGap)
  love.graphics.line(-reticleGap, reticleGap, -reticleGap, reticleGap + reticleSize)

  -- Bottom-right corner
  love.graphics.line(reticleGap, reticleGap, reticleGap + reticleSize, reticleGap)
  love.graphics.line(reticleGap, reticleGap, reticleGap, reticleGap + reticleSize)

  -- Center cross with subtle animation
  local crossScale = 1.0 + math.sin(time * 4) * 0.1 -- Gentle breathing effect
  local crossSize = 2 * crossScale

  love.graphics.setLineWidth(0.75)
  Theme.setColor(Theme.colors.info) -- Cyan accent

  -- Horizontal line
  love.graphics.line(-crossSize, 0, crossSize, 0)
  -- Vertical line
  love.graphics.line(0, -crossSize, 0, crossSize)

  -- Center dot with glow
  Theme.setColor(Theme.withAlpha(Theme.colors.glowStrong, 0.8))
  love.graphics.circle('fill', 0, 0, 0.75)

  Theme.setColor(Theme.colors.info)
  love.graphics.circle('fill', 0, 0, 0.4)

  -- Subtle trailing effect (optional)
  if pulse > 0.7 then
    Theme.setColor(Theme.withAlpha(Theme.colors.accent, (pulse - 0.7) * 3))
    love.graphics.setLineWidth(0.5)
    love.graphics.circle('line', 0, 0, 3 + pulse * 2)
  end

  love.graphics.pop()
end

-- Apply cursor settings from graphics settings
function UICursor.applySettings()
  -- Cursor now uses theme colors automatically
  -- No custom color settings needed
end

return UICursor