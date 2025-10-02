local IconRenderer = {}

-- Cache for rendered icons
local iconCache = {}

-- Render a declarative icon design into a canvas
function IconRenderer.renderIcon(iconDef, size, id)
  if not iconDef or not iconDef.shapes then
    return nil
  end

  -- Create a unique cache key using the ID if provided
  local key = id and ("declarative_" .. id .. "_" .. size) or ("declarative_" .. size .. "_" .. IconRenderer.getIconHash(iconDef))
  if iconCache[key] then
    return iconCache[key]
  end


  -- Create a canvas for the icon
  local canvas = love.graphics.newCanvas(size, size)
  love.graphics.setCanvas(canvas)
  love.graphics.clear(0, 0, 0, 0) -- Transparent background

  -- Reset graphics state
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setLineWidth(1)

  -- Set up coordinate system (icon designs are defined in 32x32 space)
  local scale = size / iconDef.size
  love.graphics.push()
  love.graphics.scale(scale, scale)

  -- Draw each shape in the design
  for _, shape in ipairs(iconDef.shapes) do
    IconRenderer.drawShape(shape)
  end

  love.graphics.pop()
  love.graphics.setCanvas()

  iconCache[key] = canvas
  return canvas
end

-- Generate a simple hash for icon caching based on shape count and first shape properties
function IconRenderer.getIconHash(iconDef)
  if not iconDef.shapes or #iconDef.shapes == 0 then
    return "empty"
  end

  local firstShape = iconDef.shapes[1]
  local hash = string.format("%s_%s_%d_%d_%d",
    firstShape.type or "unknown",
    firstShape.mode or "unknown",
    #iconDef.shapes,
    firstShape.x or 0,
    firstShape.y or 0
  )

  -- Add some color info for better uniqueness
  if firstShape.color and #firstShape.color >= 3 then
    hash = hash .. string.format("_%d%d%d",
      math.floor(firstShape.color[1] * 255),
      math.floor(firstShape.color[2] * 255),
      math.floor(firstShape.color[3] * 255)
    )
  end

  return hash
end

-- Draw a single shape based on its definition
function IconRenderer.drawShape(shape)
  love.graphics.setColor(shape.color)

  if shape.type == "rectangle" then
    if shape.mode == "fill" then
      if shape.rx then
        love.graphics.rectangle("fill", shape.x, shape.y, shape.w, shape.h, shape.rx, shape.ry)
      else
        love.graphics.rectangle("fill", shape.x, shape.y, shape.w, shape.h)
      end
    elseif shape.mode == "line" then
      if shape.rx then
        love.graphics.rectangle("line", shape.x, shape.y, shape.w, shape.h, shape.rx, shape.ry)
      else
        love.graphics.rectangle("line", shape.x, shape.y, shape.w, shape.h)
      end
    end

  elseif shape.type == "circle" then
    if shape.mode == "fill" then
      love.graphics.circle("fill", shape.x, shape.y, shape.r)
    elseif shape.mode == "line" then
      love.graphics.circle("line", shape.x, shape.y, shape.r)
    end

  elseif shape.type == "polygon" then
    if shape.mode == "fill" then
      love.graphics.polygon("fill", shape.points)
    elseif shape.mode == "line" then
      love.graphics.polygon("line", shape.points)
    end

  elseif shape.type == "line" then
    if shape.mode == "line" then
      love.graphics.line(shape.points)
    end

  elseif shape.type == "arc" then
    if shape.mode == "fill" then
      love.graphics.arc("fill", shape.x, shape.y, shape.r, shape.angle1, shape.angle2, shape.segments)
    elseif shape.mode == "line" then
      love.graphics.arc("line", shape.x, shape.y, shape.r, shape.angle1, shape.angle2, shape.segments)
    end

  elseif shape.type == "ellipse" then
    if shape.mode == "fill" then
      love.graphics.ellipse("fill", shape.x, shape.y, shape.rx, shape.ry)
    elseif shape.mode == "line" then
      love.graphics.ellipse("line", shape.x, shape.y, shape.rx, shape.ry)
    end
  end

  -- Handle width for line shapes
  if shape.width and shape.mode == "line" then
    love.graphics.setLineWidth(shape.width)
  else
    love.graphics.setLineWidth(1)
  end
end

-- Clear the icon cache (useful for memory management)
function IconRenderer.clearCache()
  iconCache = {}
end

return IconRenderer
