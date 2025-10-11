--[[
  Map Renderer System
  
  Unified rendering for both minimap and full map.
  Handles all drawing logic in one place for consistency.
]]

local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local Transform = require("src.ui.map.transform")

local MapRenderer = {}


-- Draw a single entity on the map
function MapRenderer.drawEntity(entityData, viewport, world)
  local entity = entityData.entity
  local entityType = entityData.type
  
  if not entity or not entity.components or not entity.components.position then return end
  
  local pos = entity.components.position
  local sx, sy
  
  if viewport.type == "minimap" then
    sx, sy = MapRenderer._worldToMinimap(pos.x, pos.y, viewport, world)
  else
    sx, sy = Transform.worldToScreen(pos.x, pos.y, viewport.mapX, viewport.mapY, viewport.mapW, viewport.mapH, viewport.mapState, world)
  end
  
  -- Check if within view bounds (account for entity size)
  local margin = 10
  if entityType == "planet" then
    -- Planets are large, so use a bigger margin
    margin = 50
  end
  
  if viewport.type == "minimap" then
    if sx < viewport.x - margin or sx > viewport.x + viewport.w + margin or sy < viewport.y - margin or sy > viewport.y + viewport.h + margin then
      return
    end
  else
    if sx < viewport.mapX - margin or sx > viewport.mapX + viewport.mapW + margin or sy < viewport.mapY - margin or sy > viewport.mapY + viewport.mapH + margin then
      return
    end
  end
  
  -- Draw entity based on type
  if entityType == "player" then
    MapRenderer._drawPlayer(sx, sy, viewport)
  elseif entityType == "station" then
    MapRenderer._drawStation(sx, sy, entity, viewport)
  elseif entityType == "warp_gate" then
    MapRenderer._drawWarpGate(sx, sy, entity, viewport)
  elseif entityType == "enemy" then
    MapRenderer._drawEnemy(sx, sy, entity, viewport)
  elseif entityType == "asteroid" then
    MapRenderer._drawAsteroid(sx, sy, viewport)
  elseif entityType == "wreck" then
    MapRenderer._drawWreck(sx, sy, viewport)
  elseif entityType == "loot" then
    MapRenderer._drawLoot(sx, sy, viewport)
  elseif entityType == "remote_player" then
    MapRenderer._drawRemotePlayer(sx, sy, viewport)
  elseif entityType == "planet" then
    MapRenderer._drawPlanet(sx, sy, entity, viewport)
  end
end

-- Draw minimap
function MapRenderer.drawMinimap(player, world, entities, discovery, viewport)
  if not player or not world then return end
  
  -- Clip all minimap drawing to its bounds to avoid overdraw outside
  love.graphics.setScissor(viewport.x, viewport.y, viewport.w, viewport.h)
  -- Draw background
  MapRenderer._drawMinimapBackground(viewport)
  
  -- Draw entities
  for _, entityData in ipairs(entities) do
    MapRenderer.drawEntity(entityData, viewport, world)
  end
  
  -- Draw player
  if player.components and player.components.position then
    local pos = player.components.position
    local sx, sy = MapRenderer._worldToMinimap(pos.x, pos.y, viewport, world)
    MapRenderer._drawPlayer(sx, sy, viewport)
  end
  
  -- Remove clipping
  love.graphics.setScissor()
end

-- Draw full map
function MapRenderer.drawFullMap(player, world, entities, discovery, viewport)
  if not player or not world then return end
  
  -- Draw grid
  MapRenderer._drawGrid(viewport, world)
  
  -- Draw world bounds
  MapRenderer._drawWorldBounds(viewport, world)
  
  -- Draw player trail
  MapRenderer._drawPlayerTrail(viewport, world)
  
  -- Draw entities
  for _, entityData in ipairs(entities) do
    MapRenderer.drawEntity(entityData, viewport, world)
  end
  
  -- Draw player
  if player.components and player.components.position then
    local pos = player.components.position
    local sx, sy = Transform.worldToScreen(pos.x, pos.y, viewport.mapX, viewport.mapY, viewport.mapW, viewport.mapH, viewport.mapState, world)
    MapRenderer._drawPlayer(sx, sy, viewport)
  end
  
end

-- Helper: Convert world coordinates to minimap coordinates
function MapRenderer._worldToMinimap(wx, wy, viewport, world)
  local sx = viewport.ox + wx * viewport.sx
  local sy = viewport.oy + wy * viewport.sy
  return sx, sy
end

-- Helper: Draw minimap background
function MapRenderer._drawMinimapBackground(viewport)
  local x, y, w, h = viewport.x, viewport.y, viewport.w, viewport.h
  
  -- EVE-style minimap background with glow
  Theme.drawGradientGlowRect(x, y, w, h, 8,
    Theme.colors.bg1, Theme.colors.bg0,
    Theme.colors.primary, Theme.effects.glowWeak)
  
  -- Animated scan border
  local time = love.timer.getTime()
  local pulseColor = Theme.pulseColor(Theme.colors.primary, Theme.colors.accent, time)
  Theme.drawEVEBorder(x + 4, y + 4, w - 8, h - 8, 6, pulseColor, 8)
  
  -- Grid overlay
  Theme.setColor(Theme.withAlpha(Theme.colors.border, 0.2))
  local gridSize = 16
  for i = 1, math.floor((w - 8) / gridSize) do
    local gx = x + 4 + i * gridSize
    love.graphics.line(gx, y + 4, gx, y + h - 4)
  end
  for i = 1, math.floor((h - 8) / gridSize) do
    local gy = y + 4 + i * gridSize
    love.graphics.line(x + 4, gy, x + w - 4, gy)
  end
end


-- Entity drawing helpers
function MapRenderer._drawPlayer(sx, sy, viewport)
  if viewport.type == "minimap" then
    local playerColor = Theme.shimmerColor(Theme.colors.accent, love.timer.getTime(), 0.3)
    Theme.setColor(playerColor)
    love.graphics.rectangle("fill", sx - 2.5, sy - 2.5, 5, 5)
  else
    Theme.setColor(Theme.withAlpha(Theme.colors.accent, 0.4))
    love.graphics.circle("fill", sx, sy, 6)
    Theme.setColor(Theme.colors.accent)
    love.graphics.circle("fill", sx, sy, 3)
  end
end

function MapRenderer._drawStation(sx, sy, entity, viewport)
  local stationId = entity.components.station and entity.components.station.type
  
  if stationId == "hub_station" then
    Theme.setColor(Theme.withAlpha(Theme.colors.success, 0.4))
    love.graphics.circle("fill", sx, sy, viewport.type == "minimap" and 8 or 8)
    Theme.setColor(Theme.colors.success)
    love.graphics.circle("fill", sx, sy, viewport.type == "minimap" and 4 or 4)
  elseif stationId == "beacon_station" then
    Theme.setColor(Theme.withAlpha(Theme.colors.success, 0.4))
    local size = viewport.type == "minimap" and 6 or 6
    love.graphics.polygon("fill", sx, sy - size, sx + size, sy, sx, sy + size, sx - size, sy)
    Theme.setColor(Theme.colors.success)
    local innerSize = viewport.type == "minimap" and 3 or 3
    love.graphics.polygon("fill", sx, sy - innerSize, sx + innerSize, sy, sx, sy + innerSize, sx - innerSize, sy)
  else
    Theme.setColor(Theme.withAlpha(Theme.colors.success, 0.4))
    love.graphics.circle("fill", sx, sy, viewport.type == "minimap" and 6 or 6)
    Theme.setColor(Theme.colors.success)
    love.graphics.circle("fill", sx, sy, viewport.type == "minimap" and 3 or 3)
  end
end

function MapRenderer._drawWarpGate(sx, sy, entity, viewport)
  local isActive = entity.components.warp_gate and entity.components.warp_gate.isActive
  
  if isActive then
    Theme.setColor(Theme.withAlpha({0.2, 0.6, 1.0}, 0.6))
    love.graphics.circle("fill", sx, sy, viewport.type == "minimap" and 8 or 8)
    Theme.setColor({0.4, 0.8, 1.0})
  else
    Theme.setColor({0.4, 0.4, 0.4})
  end
  
  local hexRadius = viewport.type == "minimap" and 5 or 5
  local hexVertices = {}
  for i = 0, 5 do
    local angle = (i / 6) * math.pi * 2
    table.insert(hexVertices, sx + math.cos(angle) * hexRadius)
    table.insert(hexVertices, sy + math.sin(angle) * hexRadius)
  end
  love.graphics.polygon("fill", hexVertices)
end

function MapRenderer._drawEnemy(sx, sy, entity, viewport)
  local isBoss = entity.isBoss or entity.shipId == 'boss_drone'
  
  if isBoss then
    Theme.setColor(Theme.withAlpha(Theme.colors.danger, 0.45))
    love.graphics.circle('fill', sx, sy, viewport.type == "minimap" and 7 or 7)
    Theme.setColor(Theme.colors.danger)
    local size = viewport.type == "minimap" and 5 or 5
    love.graphics.polygon('fill', sx, sy - size, sx + size, sy, sx, sy + size, sx - size, sy)
  else
    Theme.setColor(Theme.withAlpha(Theme.colors.danger, 0.5))
    local size = viewport.type == "minimap" and 3 or 3
    love.graphics.rectangle("fill", sx - size, sy - size, size * 2, size * 2)
    Theme.setColor(Theme.colors.danger)
    local innerSize = viewport.type == "minimap" and 1.5 or 1.5
    love.graphics.rectangle("fill", sx - innerSize, sy - innerSize, innerSize * 2, innerSize * 2)
  end
end

function MapRenderer._drawAsteroid(sx, sy, viewport)
  Theme.setColor(Theme.withAlpha({0.6, 0.6, 0.6}, 0.8))
  love.graphics.circle("fill", sx, sy, 1.5)
end

function MapRenderer._drawWreck(sx, sy, viewport)
  Theme.setColor(Theme.withAlpha(Theme.colors.warning, 0.3))
  love.graphics.rectangle("fill", sx - 3, sy - 3, 6, 6)
  Theme.setColor(Theme.colors.warning)
  love.graphics.rectangle("fill", sx - 1.5, sy - 1.5, 3, 3)
end

function MapRenderer._drawLoot(sx, sy, viewport)
  Theme.setColor(Theme.withAlpha(Theme.colors.info, 0.4))
  love.graphics.polygon("fill", sx, sy - 4, sx + 3, sy, sx, sy + 4, sx - 3, sy)
  Theme.setColor(Theme.colors.info)
  love.graphics.polygon("fill", sx, sy - 2.5, sx + 2, sy, sx, sy + 2.5, sx - 2, sy)
end

function MapRenderer._drawRemotePlayer(sx, sy, viewport)
  Theme.setColor(Theme.withAlpha(Theme.colors.info, 0.4))
  love.graphics.circle("fill", sx, sy, 6)
  Theme.setColor(Theme.colors.info)
  love.graphics.circle("fill", sx, sy, 3)
end

function MapRenderer._drawPlanet(sx, sy, entity, viewport)
  -- Get planet radius from entity data
  local radius = 1000  -- Default planet radius
  if entity.components and entity.components.renderable and entity.components.renderable.props then
    local props = entity.components.renderable.props
    if props.visuals and props.visuals.radius then
      radius = props.visuals.radius
    end
  end
  
  -- Scale radius for map display (much smaller than actual size)
  local mapRadius = math.max(8, math.min(25, radius * 0.01))  -- Scale down significantly for map
  
  -- Draw planet as a large gray circle
  Theme.setColor(Theme.withAlpha({0.4, 0.4, 0.4}, 0.8))  -- Gray color
  love.graphics.circle("fill", sx, sy, mapRadius)
  
  -- Draw a subtle outline
  Theme.setColor(Theme.withAlpha({0.3, 0.3, 0.3}, 0.6))
  love.graphics.circle("line", sx, sy, mapRadius)
  
  -- Draw a smaller inner circle for detail
  Theme.setColor(Theme.withAlpha({0.5, 0.5, 0.5}, 0.4))
  love.graphics.circle("fill", sx, sy, mapRadius * 0.7)
end

-- Full map specific drawing helpers
function MapRenderer._drawGrid(viewport, world)
  if not viewport.showGrid or not world then return end

  Theme.setColor(Theme.withAlpha(Theme.colors.border, 0.3))
  love.graphics.setLineWidth(1)

  for x = 0, world.width, viewport.gridSize do
    local sx, sy1 = Transform.worldToScreen(x, 0, viewport.mapX, viewport.mapY, viewport.mapW, viewport.mapH, viewport.mapState, world)
    local _, sy2 = Transform.worldToScreen(x, world.height, viewport.mapX, viewport.mapY, viewport.mapW, viewport.mapH, viewport.mapState, world)
    if sx >= viewport.mapX and sx <= viewport.mapX + viewport.mapW then
      love.graphics.line(sx, math.max(viewport.mapY, sy1), sx, math.min(viewport.mapY + viewport.mapH, sy2))
    end
  end
  
  for y = 0, world.height, viewport.gridSize do
    local sx1, sy = Transform.worldToScreen(0, y, viewport.mapX, viewport.mapY, viewport.mapW, viewport.mapH, viewport.mapState, world)
    local sx2, _ = Transform.worldToScreen(world.width, y, viewport.mapX, viewport.mapY, viewport.mapW, viewport.mapH, viewport.mapState, world)
    if sy >= viewport.mapY and sy <= viewport.mapY + viewport.mapH then
      love.graphics.line(math.max(viewport.mapX, sx1), sy, math.min(viewport.mapX + viewport.mapW, sx2), sy)
    end
  end
end

function MapRenderer._drawWorldBounds(viewport, world)
  if not world then return end
  
  Theme.setColor(Theme.colors.accent)
  love.graphics.setLineWidth(2)
  
  local x1, y1 = Transform.worldToScreen(0, 0, viewport.mapX, viewport.mapY, viewport.mapW, viewport.mapH, viewport.mapState, world)
  local x2, y2 = Transform.worldToScreen(world.width, world.height, viewport.mapX, viewport.mapY, viewport.mapW, viewport.mapH, viewport.mapState, world)
  
  x1 = math.max(viewport.mapX, math.min(viewport.mapX + viewport.mapW, x1))
  y1 = math.max(viewport.mapY, math.min(viewport.mapY + viewport.mapH, y1))
  x2 = math.max(viewport.mapX, math.min(viewport.mapX + viewport.mapW, x2))
  y2 = math.max(viewport.mapY, math.min(viewport.mapY + viewport.mapH, y2))
  
  if x2 > x1 and y2 > y1 then
    love.graphics.rectangle("line", x1, y1, x2 - x1, y2 - y1)
  end
end

function MapRenderer._drawPlayerTrail(viewport, world)
  -- TODO: Implement player trail drawing
  -- This would need access to the player trail data
end

return MapRenderer
