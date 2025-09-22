local ModelUtil = {}

function ModelUtil.calculateModelWidth(visuals)
  if not visuals or not visuals.shapes then return 30 end -- Default radius for ships without shapes

  local maxExtent = 0
  for _, shape in ipairs(visuals.shapes) do
    local extent = 0
    if shape.type == "rectangle" then
      extent = math.max(math.abs(shape.x), math.abs(shape.x + shape.w))
    elseif shape.type == "circle" then
      extent = math.abs(shape.x) + shape.r
    end
    if extent > maxExtent then
      maxExtent = extent
    end
  end

  -- If no valid extent found, use a default
  if maxExtent == 0 then
    maxExtent = 15 -- Default radius for ships
  end

  return maxExtent * (visuals.size or 1.0)
end

return ModelUtil
