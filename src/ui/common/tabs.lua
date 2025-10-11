local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")

local Tabs = {}

-- Draw a horizontal tabs strip.
-- tabs = {"A","B",...}, selected (string), returns {rects={ {x,y,w,h,name}... }, hoveredName}
function Tabs.draw(x, y, w, h, tabs, selected)
  local mx, my = Viewport.getMousePosition()
  local spacing = (Theme.ui and Theme.ui.buttonSpacing) or 4
  local perTab = math.floor((w - spacing * (#tabs - 1)) / #tabs)
  local rects = {}
  local hoveredName = nil
  for i, name in ipairs(tabs) do
    local tabX = x + (i - 1) * (perTab + spacing)
    local isSelected = selected == name
    local hover = mx >= tabX and mx <= tabX + perTab and my >= y and my <= y + h
    
    -- Use main button theme for consistent styling
    Theme.drawStyledButton(tabX, y, perTab, h, name, hover, 1.0, nil, isSelected)
    
    table.insert(rects, { x = tabX, y = y, w = perTab, h = h, name = name })
    if hover then hoveredName = name end
  end
  return { rects = rects, hoveredName = hoveredName }
end

-- Utility to hit-test a name by point
function Tabs.hit(tabsRects, px, py)
  for _, r in ipairs(tabsRects or {}) do
    if px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h then
      return r.name
    end
  end
  return nil
end

return Tabs


