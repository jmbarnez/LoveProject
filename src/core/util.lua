local util = {}

function util.clamp(x, a, b)
  if x < a then return a end
  if x > b then return b end
  return x
end

function util.lerp(a, b, t)
  return a + (b - a) * t
end

function util.length(x, y)
  return math.sqrt(x * x + y * y)
end

function util.normalize(x, y)
  local l = util.length(x, y)
  if l == 0 then return 0, 0 end
  return x / l, y / l
end

function util.distance(x1, y1, x2, y2)
  local dx, dy = x2 - x1, y2 - y1
  return math.sqrt(dx * dx + dy * dy)
end

function util.angleTo(x1, y1, x2, y2)
  local dy, dx = (y2 - y1), (x2 - x1)
  if math.atan2 then
    return math.atan2(dy, dx)
  end
  if dx == 0 then
    return dy >= 0 and math.pi/2 or -math.pi/2
  end
  local a = math.atan(dy / dx)
  if dx < 0 then a = a + math.pi end
  return a
end

function util.approach(a, b, s)
  if a < b then return math.min(a + s, b) end
  return math.max(a - s, b)
end

function util.circleOverlap(x1, y1, r1, x2, y2, r2)
  local dx, dy = x2 - x1, y2 - y1
  return dx * dx + dy * dy <= (r1 + r2) * (r1 + r2)
end

function util.round(num, idp)
  local mult = 10^(idp or 0)
  return math.floor(num * mult + 0.5) / mult
end

function util.copy(obj)
  if type(obj) ~= 'table' then return obj end
  local res = {}
  for k, v in pairs(obj) do
    res[k] = v
  end
  return res
end

function util.deepCopy(obj)
    if type(obj) ~= 'table' then return obj end
    local res = {}
    for k, v in pairs(obj) do
        res[k] = util.deepCopy(v)
    end
    return res
end

function util.generateAsteroidVertices(radius)
  local vertices = {}
  local numPoints = 12
  local angleStep = (2 * math.pi) / numPoints
  
  for i = 0, numPoints - 1 do
    local angle = i * angleStep
    local r = radius * (0.8 + math.random() * 0.4) -- Add randomness
    local x = r * math.cos(angle)
    local y = r * math.sin(angle)
    table.insert(vertices, {x, y})
  end
  
  return vertices
end

-- Wrap text to fit a max width, respecting word boundaries
function util.wrapText(text, maxWidth, font)
  font = font or love.graphics.getFont()
  local lines = {}
  local currentLine = ""
  
  for word in string.gmatch(text, "%S+") do
    local testLine = currentLine == "" and word or (currentLine .. " " .. word)
    if font:getWidth(testLine) > maxWidth then
      if currentLine ~= "" then
        table.insert(lines, currentLine)
      end
      currentLine = word
    else
      currentLine = testLine
    end
  end
  
  if currentLine ~= "" then
    table.insert(lines, currentLine)
  end
  
  -- Handle cases where a single word is longer than the max width
  for i = #lines, 1, -1 do
    local line = lines[i]
    if font:getWidth(line) > maxWidth then
      -- Simple character-by-character split for oversized words
      local tempLines = {}
      local currentChunk = ""
      for j = 1, #line do
        local char = line:sub(j, j)
        if font:getWidth(currentChunk .. char) > maxWidth then
          table.insert(tempLines, currentChunk)
          currentChunk = char
        else
          currentChunk = currentChunk .. char
        end
      end
      if currentChunk ~= "" then table.insert(tempLines, currentChunk) end
      
      -- Replace the oversized line with the new chunks
      table.remove(lines, i)
      for j = #tempLines, 1, -1 do
        table.insert(lines, i, tempLines[j])
      end
    end
  end

  return lines
end

function util.formatNumber(num)
  -- Ensure we have a number to work with
  if type(num) ~= "number" then
    return tostring(num or 0)
  end
  
  if num >= 1000000 then
    return string.format("%.1fM", num / 1000000)
  elseif num >= 1000 then
    return string.format("%.1fk", num / 1000)
  else
    return tostring(num)
  end
end

function util.rectContains(x, y, rx, ry, rw, rh)
    return x >= rx and x <= rx + rw and y >= ry and y <= ry + rh
end

function util.unpack_color(color)
    if type(color) == "table" then
        local r = color[1] or color.r or color.red or 1
        local g = color[2] or color.g or color.green or 1
        local b = color[3] or color.b or color.blue or 1
        local a = color[4] or color.a or color.alpha or 1
        return r, g, b, a
    end
    return 1, 1, 1, 1 -- Default to white if color is not a table
end

return util

