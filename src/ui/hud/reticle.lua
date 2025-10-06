local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local Settings = require("src.core.settings")

local Reticle = {}

function Reticle.draw(player, world, camera)
  local mx, my = Viewport.getMousePosition()
  local t = love.timer.getTime()

  local g = Settings.getGraphicsSettings()
  local userColor
  if g and g.reticle_color_rgb and type(g.reticle_color_rgb) == 'table' then
    userColor = { g.reticle_color_rgb[1] or 1, g.reticle_color_rgb[2] or 1, g.reticle_color_rgb[3] or 1, g.reticle_color_rgb[4] or 1 }
  else
    userColor = Theme.colors.accent
  end

  love.graphics.push()
  love.graphics.translate(mx, my)
  
  -- Simple crosshair reticle
  local scale = 1.0
  local len = 8 * scale
  local gap = 2 * scale
  local thick = 1 * scale
  
  love.graphics.setLineWidth(thick)
  Theme.setColor(userColor)
  
  -- Draw simple cross
  love.graphics.line(gap, 0, gap + len, 0)
  love.graphics.line(-gap, 0, -gap - len, 0)
  love.graphics.line(0, gap, 0, gap + len)
  love.graphics.line(0, -gap, 0, -gap - len)
  
  -- Center dot
  love.graphics.circle('fill', 0, 0, 1)
  
  love.graphics.pop()
end

return Reticle