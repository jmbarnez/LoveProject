local Transform = {}

function Transform.worldToScreen(worldX, worldY, mapX, mapY, mapW, mapH, state, world)
  if not world then return mapX + mapW/2, mapY + mapH/2 end
  local normX = worldX / world.width
  local normY = worldY / world.height
  local scaledW = mapW * state.scale
  local scaledH = mapH * state.scale
  local centerOffsetX = state.centerX * scaledW
  local centerOffsetY = state.centerY * scaledH
  local screenX = mapX + (mapW - scaledW) / 2 + normX * scaledW + centerOffsetX + state.dragOffsetX
  local screenY = mapY + (mapH - scaledH) / 2 + normY * scaledH + centerOffsetY + state.dragOffsetY
  return screenX, screenY
end

function Transform.screenToWorld(screenX, screenY, mapX, mapY, mapW, mapH, state, world)
  if not world then return 0, 0 end
  local scaledW = mapW * state.scale
  local scaledH = mapH * state.scale
  local centerOffsetX = state.centerX * scaledW
  local centerOffsetY = state.centerY * scaledH
  local normX = ((screenX - mapX - (mapW - scaledW) / 2 - centerOffsetX - state.dragOffsetX) / scaledW)
  local normY = ((screenY - mapY - (mapH - scaledH) / 2 - centerOffsetY - state.dragOffsetY) / scaledH)
  local worldX = normX * world.width
  local worldY = normY * world.height
  return worldX, worldY
end

return Transform


