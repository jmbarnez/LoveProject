local Theme = require("src.core.theme")

local Button = {}

-- Draw a themed button and return its rect {x,y,w,h}
-- Options: { compact=true, color=Theme.colors.bg2, down=false, font=nil }
function Button.drawRect(x, y, w, h, text, hover, t, opts)
  opts = opts or {}
  local color = opts.color
  local down = opts.down or false
  local rect = { x = x, y = y, w = w, h = h }
  Theme.drawStyledButton(x, y, w, h, text, hover, t or love.timer.getTime(), color, down, { compact = opts.compact, font = opts.font })
  return rect
end

-- Utility: check if point is inside a rect
function Button.pointIn(rect, px, py)
  if not rect then return false end
  return px >= rect.x and px <= rect.x + rect.w and py >= rect.y and py <= rect.y + rect.h
end

return Button


