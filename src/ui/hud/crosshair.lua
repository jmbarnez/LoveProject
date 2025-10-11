local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local Settings = require("src.core.settings")

local Crosshair = {}

function Crosshair.draw(player, world, camera)
  local mx, my = Viewport.getMousePosition()
  local t = love.timer.getTime()

  local g = Settings.getGraphicsSettings()
  local userColor
  if g and g.crosshair_color_rgb and type(g.crosshair_color_rgb) == 'table' then
    userColor = { g.crosshair_color_rgb[1] or 1, g.crosshair_color_rgb[2] or 1, g.crosshair_color_rgb[3] or 1, g.crosshair_color_rgb[4] or 1 }
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

  -- Missile lock-on progress ring (if any missile turret is selected/active)
  if player and player.components and player.components.equipment and player.components.equipment.grid then
    local lockProgress = nil
    local isLocked = false
    for _, gridData in ipairs(player.components.equipment.grid) do
      local turret = gridData and gridData.module
      if turret and turret.kind == 'missile' then
        if turret.lockOnProgress and turret.lockOnProgress > 0 then
          lockProgress = math.max(0, math.min(1, turret.lockOnProgress))
          isLocked = turret.isLockedOn == true
          break
        end
      end
    end

    if lockProgress then
      local radius = 14
      local segments = 48
      local startAngle = -math.pi / 2
      local endAngle = startAngle + (lockProgress * math.pi * 2)

      -- Background ring
      Theme.setColor(Theme.withAlpha(userColor, 0.25))
      love.graphics.setLineWidth(2)
      love.graphics.circle('line', 0, 0, radius)

      -- Progress arc
      Theme.setColor(isLocked and Theme.colors.success or userColor)
      love.graphics.arc('line', 'open', 0, 0, radius, startAngle, endAngle, segments)

      -- Locked indicator tick marks
      if isLocked then
        local tickLen = 4
        Theme.setColor(Theme.colors.success)
        love.graphics.line(radius + 2, 0, radius + 2 + tickLen, 0)
        love.graphics.line(-(radius + 2), 0, -(radius + 2 + tickLen), 0)
        love.graphics.line(0, radius + 2, 0, radius + 2 + tickLen)
        love.graphics.line(0, -(radius + 2), 0, -(radius + 2 + tickLen))
      end
    end
  end
  
  love.graphics.pop()
end

return Crosshair