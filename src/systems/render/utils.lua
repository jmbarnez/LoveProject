-- Rendering utility functions
local RenderUtils = {}

-- Helper: set color from table {r,g,b,a?}
function RenderUtils.setColor(c, aOverride)
  if type(c) == "table" then
    local r,g,b,a = c[1] or 1, c[2] or 1, c[3] or 1, c[4]
    love.graphics.setColor(r, g, b, aOverride or a or 1)
  else
    love.graphics.setColor(1,1,1,1)
  end
end

-- Draw primitive shape description with scaling
function RenderUtils.drawShape(shape, S)
  local t = shape.type or "polygon"
  local mode = shape.mode or "fill"
  local color = shape.color
  local width = shape.width
  
  RenderUtils.setColor(color)
  
  if width then
    love.graphics.setLineWidth(width)
  end
  
  if t == "polygon" and shape.points then
    local pts = {}
    for i = 1, #shape.points, 2 do
      table.insert(pts, S(shape.points[i]))
      table.insert(pts, S(shape.points[i+1]))
    end
    love.graphics.polygon(mode, pts)
  elseif t == "circle" then
    love.graphics.circle(mode, S(shape.x or 0), S(shape.y or 0), S(shape.r or 4))
  elseif t == "rect" or t == "rectangle" then
    love.graphics.rectangle(mode, S(shape.x or 0), S(shape.y or 0), S(shape.w or 4), S(shape.h or 4), S(shape.rx or 0), S(shape.ry or shape.rx or 0))
  elseif t == "arc" then
    -- Arcs: angle1/angle2 are radians (not scaled); segments optional
    local x = S(shape.x or 0)
    local y = S(shape.y or 0)
    local r = S(shape.r or 4)
    local a1 = shape.angle1 or 0
    local a2 = shape.angle2 or (2 * math.pi)
    local seg = shape.segments -- Love2D will pick a default if nil
    if seg then
      love.graphics.arc(mode, x, y, r, a1, a2, seg)
    else
      love.graphics.arc(mode, x, y, r, a1, a2)
    end
  elseif t == "ellipse" then
    -- Ellipse radii rx/ry (fallbacks to r); rotation is not supported in Love2D ellipse API
    local x = S(shape.x or 0)
    local y = S(shape.y or 0)
    local rx = S(shape.rx or shape.r or 4)
    local ry = S(shape.ry or shape.rx or shape.r or 4)
    love.graphics.ellipse(mode, x, y, rx, ry)
  elseif t == "line" and shape.points then
    local pts = {}
    for i = 1, #shape.points, 2 do
      table.insert(pts, S(shape.points[i]))
      table.insert(pts, S(shape.points[i+1]))
    end
    love.graphics.line(pts)
  end
  
  if width then
    love.graphics.setLineWidth(1)
  end
end

-- Create a scaling function
function RenderUtils.createScaler(size)
  return function(x) return x * size end
end

return RenderUtils