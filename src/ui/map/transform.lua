local Transform = {}

-- Convert world coordinates to screen coordinates within the map window.
-- Uses centerX/centerY as the world-space center of the view and a uniform scale
-- derived from fitting the world bounds into the map rect, multiplied by state.scale.
function Transform.worldToScreen(worldX, worldY, mapX, mapY, mapW, mapH, state, world)
  if not world then
    return mapX + mapW / 2, mapY + mapH / 2
  end

  local baseScale = math.min(mapW / world.width, mapH / world.height)
  if baseScale <= 0 or baseScale == math.huge then baseScale = 1 end
  local s = (state and state.scale or 1) * baseScale

  local cx = (state and state.centerX) or 0
  local cy = (state and state.centerY) or 0

  local screenX = mapX + mapW / 2 + (worldX - cx) * s
  local screenY = mapY + mapH / 2 + (worldY - cy) * s
  return screenX, screenY
end

-- Convert screen coordinates within the map window back to world coordinates.
function Transform.screenToWorld(screenX, screenY, mapX, mapY, mapW, mapH, state, world)
  if not world then return 0, 0 end

  local baseScale = math.min(mapW / world.width, mapH / world.height)
  if baseScale <= 0 or baseScale == math.huge then baseScale = 1 end
  local s = (state and state.scale or 1) * baseScale
  if s == 0 then return 0, 0 end

  local cx = (state and state.centerX) or 0
  local cy = (state and state.centerY) or 0

  local dx = screenX - (mapX + mapW / 2)
  local dy = screenY - (mapY + mapH / 2)
  local worldX = cx + dx / s
  local worldY = cy + dy / s
  return worldX, worldY
end

return Transform


