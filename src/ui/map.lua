local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local Util = require("src.core.util")
local Window = require("src.ui.common.window")
local Transform = require("src.ui.map.transform")
local Draw = require("src.ui.map.draw")

local Map = {
  visible = false,
  dragging = false,
  dragStartX = 0,
  dragStartY = 0,
  dragOffsetX = 0,
  dragOffsetY = 0,
  scale = 1.0,
  minScale = 0.1,
  maxScale = 3.0,
  centerX = 0,
  centerY = 0,
  gridSize = 1000,
  showGrid = true,
  showEntities = true,
  showTrails = false,
  filterEnemies = true,
  filterAsteroids = true,
  filterWrecks = true,
  filterStations = true,
  lastPlayerPos = {x = 0, y = 0},
  playerTrail = {},
  maxTrailLength = 100,
}

local function pointIn(px, py, r)
  -- Handle nil values gracefully
  if px == nil or py == nil or r == nil or r.x == nil or r.y == nil or r.w == nil or r.h == nil then
    return false
  end
  return px >= r.x and py >= r.y and px <= r.x + r.w and py <= r.y + r.h
end

local function getMapBounds()
  local sw, sh = Viewport.getDimensions()
  local margin = (Theme.ui and Theme.ui.contentPadding) or 40
  return margin, margin, sw - 2 * margin, sh - 2 * margin
end

local function worldToScreen(worldX, worldY, mapX, mapY, mapW, mapH, world)
  if not world then return mapX + mapW/2, mapY + mapH/2 end
  
  -- Convert world coordinates to normalized coordinates (0-1)
  local normX = worldX / world.width
  local normY = worldY / world.height
  
  -- Apply scale and centering
  local scaledW = mapW * Map.scale
  local scaledH = mapH * Map.scale
  
  -- Calculate center offset
  local centerOffsetX = Map.centerX * scaledW
  local centerOffsetY = Map.centerY * scaledH
  
  -- Convert to screen coordinates
  local screenX = mapX + (mapW - scaledW) / 2 + normX * scaledW + centerOffsetX + Map.dragOffsetX
  local screenY = mapY + (mapH - scaledH) / 2 + normY * scaledH + centerOffsetY + Map.dragOffsetY
  
  return screenX, screenY
end

local function screenToWorld(screenX, screenY, mapX, mapY, mapW, mapH, world)
  if not world then return 0, 0 end
  
  local scaledW = mapW * Map.scale
  local scaledH = mapH * Map.scale
  
  local centerOffsetX = Map.centerX * scaledW
  local centerOffsetY = Map.centerY * scaledH
  
  -- Convert screen to normalized coordinates
  local normX = ((screenX - mapX - (mapW - scaledW) / 2 - centerOffsetX - Map.dragOffsetX) / scaledW)
  local normY = ((screenY - mapY - (mapH - scaledH) / 2 - centerOffsetY - Map.dragOffsetY) / scaledH)
  
  -- Convert to world coordinates
  local worldX = normX * world.width
  local worldY = normY * world.height
  
  return worldX, worldY
end

local function drawGrid(mapX, mapY, mapW, mapH, world)
  if not Map.showGrid or not world then return end
  
  Theme.setColor(Theme.withAlpha(Theme.colors.border, 0.3))
  love.graphics.setLineWidth(1)
  
  -- Draw major grid lines every gridSize units
  for x = 0, world.width, Map.gridSize do
    local sx, sy1 = worldToScreen(x, 0, mapX, mapY, mapW, mapH, world)
    local _, sy2 = worldToScreen(x, world.height, mapX, mapY, mapW, mapH, world)
    if sx >= mapX and sx <= mapX + mapW then
      love.graphics.line(sx, math.max(mapY, sy1), sx, math.min(mapY + mapH, sy2))
    end
  end
  
  for y = 0, world.height, Map.gridSize do
    local sx1, sy = worldToScreen(0, y, mapX, mapY, mapW, mapH, world)
    local sx2, _ = worldToScreen(world.width, y, mapX, mapY, mapW, mapH, world)
    if sy >= mapY and sy <= mapY + mapH then
      love.graphics.line(math.max(mapX, sx1), sy, math.min(mapX + mapW, sx2), sy)
    end
  end
end

local function drawWorldBounds(mapX, mapY, mapW, mapH, world)
  if not world then return end
  
  Theme.setColor(Theme.colors.accent)
  love.graphics.setLineWidth(2)
  
  local x1, y1 = worldToScreen(0, 0, mapX, mapY, mapW, mapH, world)
  local x2, y2 = worldToScreen(world.width, world.height, mapX, mapY, mapW, mapH, world)
  
  -- Clamp to map bounds
  x1 = math.max(mapX, math.min(mapX + mapW, x1))
  y1 = math.max(mapY, math.min(mapY + mapH, y1))
  x2 = math.max(mapX, math.min(mapX + mapW, x2))
  y2 = math.max(mapY, math.min(mapY + mapH, y2))
  
  if x2 > x1 and y2 > y1 then
    love.graphics.rectangle("line", x1, y1, x2 - x1, y2 - y1)
  end
end

local function drawEntity(entity, mapX, mapY, mapW, mapH, world, entityType)
  if not entity.components or not entity.components.position then return end

  local pos = entity.components.position
  local sx, sy = worldToScreen(pos.x, pos.y, mapX, mapY, mapW, mapH, world)

  -- Only draw if within map bounds
  if sx < mapX - 10 or sx > mapX + mapW + 10 or sy < mapY - 10 or sy > mapY + mapH + 10 then
    return
  end

  -- Use same icons as minimap for consistency
  if entityType == "player" then
    -- Player: bright accent colored circle with glow
    Theme.setColor(Theme.withAlpha(Theme.colors.accent, 0.4))
    love.graphics.circle("fill", sx, sy, 6)
    Theme.setColor(Theme.colors.accent)
    love.graphics.circle("fill", sx, sy, 3)
  elseif entityType == "station" then
    -- Station icons - match minimap exactly
    local stationId = entity.components.station and entity.components.station.type
    if stationId == "hub_station" then
      -- Hub station: larger green circle with stronger glow
      Theme.setColor(Theme.withAlpha(Theme.colors.success, 0.4))
      love.graphics.circle("fill", sx, sy, 8)
      Theme.setColor(Theme.colors.success)
      love.graphics.circle("fill", sx, sy, 4)
    elseif stationId == "beacon_station" then
      -- Beacon station: green diamond with glow
      Theme.setColor(Theme.withAlpha(Theme.colors.success, 0.4))
      love.graphics.polygon("fill", sx, sy - 6, sx + 6, sy, sx, sy + 6, sx - 6, sy)
      Theme.setColor(Theme.colors.success)
      love.graphics.polygon("fill", sx, sy - 3, sx + 3, sy, sx, sy + 3, sx - 3, sy)
    else
      -- Generic station: standard green circle
      Theme.setColor(Theme.withAlpha(Theme.colors.success, 0.4))
      love.graphics.circle("fill", sx, sy, 6)
      Theme.setColor(Theme.colors.success)
      love.graphics.circle("fill", sx, sy, 3)
    end
  elseif entityType == "enemy" then
    -- Enemy: red square with subtle glow (match minimap)
    local isBoss = entity.isBoss or entity.shipId == 'boss_drone'
    if isBoss then
      -- Boss: bright red diamond with halo
      Theme.setColor(Theme.withAlpha(Theme.colors.danger, 0.45))
      love.graphics.circle('fill', sx, sy, 7)
      Theme.setColor(Theme.colors.danger)
      love.graphics.polygon('fill', sx, sy - 5, sx + 5, sy, sx, sy + 5, sx - 5, sy)
    else
      -- Regular enemy: red square with subtle glow
      Theme.setColor(Theme.withAlpha(Theme.colors.danger, 0.5))
      love.graphics.rectangle("fill", sx - 3, sy - 3, 6, 6)
      Theme.setColor(Theme.colors.danger)
      love.graphics.rectangle("fill", sx - 1.5, sy - 1.5, 3, 3)
    end
  elseif entityType == "asteroid" then
    -- Asteroid: small gray dots (match minimap)
    Theme.setColor(Theme.withAlpha({0.6, 0.6, 0.6}, 0.8))
    love.graphics.circle("fill", sx, sy, 1.5)
  elseif entityType == "wreck" then
    -- Wreckage: amber squares with glow (match minimap)
    Theme.setColor(Theme.withAlpha(Theme.colors.warning, 0.3))
    love.graphics.rectangle("fill", sx - 3, sy - 3, 6, 6)
    Theme.setColor(Theme.colors.warning)
    love.graphics.rectangle("fill", sx - 1.5, sy - 1.5, 3, 3)
  elseif entityType == "loot" then
    -- Loot: blue diamonds with glow (match minimap)
    Theme.setColor(Theme.withAlpha(Theme.colors.info, 0.4))
    love.graphics.polygon("fill", sx, sy - 4, sx + 3, sy, sx, sy + 4, sx - 3, sy)
    Theme.setColor(Theme.colors.info)
    love.graphics.polygon("fill", sx, sy - 2.5, sx + 2, sy, sx, sy + 2.5, sx - 2, sy)
  elseif entityType == "warp_gate" then
    -- Warp gate: hexagonal icon with blue glow
    local isActive = entity.components.warp_gate and entity.components.warp_gate.isActive
    if isActive then
      -- Active warp gate: bright blue hexagon with glow
      Theme.setColor(Theme.withAlpha({0.2, 0.6, 1.0}, 0.6))
      love.graphics.circle("fill", sx, sy, 8)
      Theme.setColor({0.4, 0.8, 1.0})
      -- Draw hexagon
      local hexRadius = 5
      local hexVertices = {}
      for i = 0, 5 do
        local angle = (i / 6) * math.pi * 2
        table.insert(hexVertices, sx + math.cos(angle) * hexRadius)
        table.insert(hexVertices, sy + math.sin(angle) * hexRadius)
      end
      love.graphics.polygon("fill", hexVertices)
    else
      -- Inactive warp gate: gray hexagon
      Theme.setColor({0.4, 0.4, 0.4})
      local hexRadius = 4
      local hexVertices = {}
      for i = 0, 5 do
        local angle = (i / 6) * math.pi * 2
        table.insert(hexVertices, sx + math.cos(angle) * hexRadius)
        table.insert(hexVertices, sy + math.sin(angle) * hexRadius)
      end
      love.graphics.polygon("fill", hexVertices)
    end
  end

  -- Draw entity name for important entities
  if entityType == "player" or entityType == "station" or entityType == "warp_gate" then
    love.graphics.setFont(Theme.fonts.small)
    Theme.setColor(Theme.colors.text)
    local name = entity.name or (entityType == "player" and "You" or (entityType == "station" and "Station" or "Warp Gate"))
    local textW = Theme.fonts.small:getWidth(name)
    love.graphics.print(name, sx - textW/2, sy - 12)
  end
end

local function drawPlayerTrail(mapX, mapY, mapW, mapH, world)
  if not Map.showTrails or #Map.playerTrail < 2 then return end
  
  Theme.setColor(Theme.withAlpha(Theme.colors.accent, 0.5))
  love.graphics.setLineWidth(2)
  
  for i = 2, #Map.playerTrail do
    local p1 = Map.playerTrail[i-1]
    local p2 = Map.playerTrail[i]
    local sx1, sy1 = worldToScreen(p1.x, p1.y, mapX, mapY, mapW, mapH, world)
    local sx2, sy2 = worldToScreen(p2.x, p2.y, mapX, mapY, mapW, mapH, world)
    
    -- Fade trail based on age
    local age = i / #Map.playerTrail
    local alpha = 0.1 + age * 0.4
    Theme.setColor(Theme.withAlpha(Theme.colors.accent, alpha))
    love.graphics.line(sx1, sy1, sx2, sy2)
  end
end

local function drawLegendIcon(x, y, iconType)
  if iconType == "player" then
    Theme.setColor(Theme.withAlpha(Theme.colors.accent, 0.4))
    love.graphics.circle("fill", x, y, 6)
    Theme.setColor(Theme.colors.accent)
    love.graphics.circle("fill", x, y, 3)
  elseif iconType == "hub_station" then
    Theme.setColor(Theme.withAlpha(Theme.colors.success, 0.4))
    love.graphics.circle("fill", x, y, 6)
    Theme.setColor(Theme.colors.success)
    love.graphics.circle("fill", x, y, 3)
  elseif iconType == "beacon_station" then
    Theme.setColor(Theme.withAlpha(Theme.colors.success, 0.4))
    love.graphics.polygon("fill", x, y - 4, x + 4, y, x, y + 4, x - 4, y)
    Theme.setColor(Theme.colors.success)
    love.graphics.polygon("fill", x, y - 2, x + 2, y, x, y + 2, x - 2, y)
  elseif iconType == "enemy" then
    Theme.setColor(Theme.withAlpha(Theme.colors.danger, 0.5))
    love.graphics.rectangle("fill", x - 2, y - 2, 4, 4)
    Theme.setColor(Theme.colors.danger)
    love.graphics.rectangle("fill", x - 1, y - 1, 2, 2)
  elseif iconType == "boss" then
    Theme.setColor(Theme.withAlpha(Theme.colors.danger, 0.45))
    love.graphics.circle('fill', x, y, 5)
    Theme.setColor(Theme.colors.danger)
    love.graphics.polygon('fill', x, y - 3, x + 3, y, x, y + 3, x - 3, y)
  elseif iconType == "asteroid" then
    Theme.setColor(Theme.withAlpha({0.6, 0.6, 0.6}, 0.8))
    love.graphics.circle("fill", x, y, 1.5)
  elseif iconType == "wreck" then
    Theme.setColor(Theme.withAlpha(Theme.colors.warning, 0.3))
    love.graphics.rectangle("fill", x - 2, y - 2, 4, 4)
    Theme.setColor(Theme.colors.warning)
    love.graphics.rectangle("fill", x - 1, y - 1, 2, 2)
  elseif iconType == "loot" then
    Theme.setColor(Theme.withAlpha(Theme.colors.info, 0.4))
    love.graphics.polygon("fill", x, y - 3, x + 2, y, x, y + 3, x - 2, y)
    Theme.setColor(Theme.colors.info)
    love.graphics.polygon("fill", x, y - 2, x + 1.5, y, x, y + 2, x - 1.5, y)
  elseif iconType == "warp_gate" then
    -- Warp gate legend icon: small blue hexagon
    Theme.setColor({0.4, 0.8, 1.0})
    local hexRadius = 3
    local hexVertices = {}
    for i = 0, 5 do
      local angle = (i / 6) * math.pi * 2
      table.insert(hexVertices, x + math.cos(angle) * hexRadius)
      table.insert(hexVertices, y + math.sin(angle) * hexRadius)
    end
    love.graphics.polygon("fill", hexVertices)
  end
end

local function drawLegend(mapX, mapY, mapW, mapH)
  -- Draw legend panel
  local pad = (Theme.ui and Theme.ui.contentPadding) or 10
  local legendW = 210
  local legendH = 200
  local legendX = mapX + mapW - (legendW + pad)
  local legendY = mapY + pad

  Theme.drawGradientGlowRect(legendX, legendY, legendW, legendH, 4,
    Theme.withAlpha(Theme.colors.bg1, 0.9), Theme.withAlpha(Theme.colors.bg0, 0.9),
    Theme.colors.border, Theme.effects.glowWeak)

  love.graphics.setFont(Theme.fonts.small)

  -- Legend title
  Theme.setColor(Theme.colors.accent)
  love.graphics.print("LEGEND:", legendX + 8, legendY + 8)

  -- Legend items
  local items = {
    {icon = "player", label = "You"},
    {icon = "hub_station", label = "Hub Station"},
    {icon = "beacon_station", label = "Beacon Station"},
    {icon = "warp_gate", label = "Warp Gate"},
    {icon = "enemy", label = "Enemy"},
    {icon = "boss", label = "Boss Enemy"},
    {icon = "asteroid", label = "Asteroid"},
    {icon = "wreck", label = "Wreckage"},
    {icon = "loot", label = "Loot Drop"}
  }

  Theme.setColor(Theme.colors.textSecondary)
  for i, item in ipairs(items) do
    local itemY = legendY + 25 + (i-1) * 16
    drawLegendIcon(legendX + 20, itemY, item.icon)
    love.graphics.print(item.label, legendX + 35, itemY - 6)
  end
end

local function drawControls(mapX, mapY, mapW, mapH)
  -- Draw control panel
  local pad = (Theme.ui and Theme.ui.contentPadding) or 10
  local controlX = mapX + pad
  local controlY = mapY + pad
  local controlW = 200
  local controlH = 70

  Theme.drawGradientGlowRect(controlX, controlY, controlW, controlH, 4,
    Theme.withAlpha(Theme.colors.bg1, 0.9), Theme.withAlpha(Theme.colors.bg0, 0.9),
    Theme.colors.border, Theme.effects.glowWeak)

  love.graphics.setFont(Theme.fonts.small)
  Theme.setColor(Theme.colors.text)

  local text = {
    "MAP CONTROLS:",
    "Mouse Wheel: Zoom",
    "Drag: Pan view",
    "M: Close map"
  }

  for i, line in ipairs(text) do
    local y = controlY + 8 + (i-1) * 12
    if i == 1 then
      Theme.setColor(Theme.colors.accent)
    else
      Theme.setColor(Theme.colors.textSecondary)
    end
    love.graphics.print(line, controlX + 8, y)
  end

  -- Draw scale indicator
  local scaleText = string.format("Scale: %.1fx", Map.scale)
  Theme.setColor(Theme.colors.textTertiary)
  love.graphics.print(scaleText, mapX + pad, mapY + mapH - 20)
end

function Map.toggle(world)
  Map.visible = not Map.visible
  if Map.visible then
    -- Reset view when opening - start at 1.0x scale
    Map.scale = 1.0
    Map.centerX = 0
    Map.centerY = 0
    Map.dragOffsetX = 0
    Map.dragOffsetY = 0
  end
end

function Map.show()
  Map.visible = true
  local ok, UIManager = pcall(require, "src.core.ui_manager")
  if ok and UIManager and UIManager.state and UIManager.state.map then
    UIManager.state.map.open = true
  end
end

function Map.hide()
  Map.visible = false
  local ok, UIManager = pcall(require, "src.core.ui_manager")
  if ok and UIManager and UIManager.state and UIManager.state.map then
    UIManager.state.map.open = false
  end
end

function Map.isVisible()
  return Map.visible
end

function Map.update(dt, player)
  if not Map.visible or not player then return end
  
  -- Update player trail
  if player.components and player.components.position then
    local pos = player.components.position
    local newPos = {x = pos.x, y = pos.y, time = love.timer.getTime()}
    
    -- Only add to trail if player has moved significantly
    if #Map.playerTrail == 0 or 
       Util.distance(Map.lastPlayerPos.x, Map.lastPlayerPos.y, pos.x, pos.y) > 50 then
      table.insert(Map.playerTrail, newPos)
      Map.lastPlayerPos = {x = pos.x, y = pos.y}
      
      -- Limit trail length
      while #Map.playerTrail > Map.maxTrailLength do
        table.remove(Map.playerTrail, 1)
      end
    end
  end
end

function Map.init()
    local sw, sh = Viewport.getDimensions()
    local margin = 40
    Map.window = Window.new({
        title = "SECTOR MAP",
        x = margin,
        y = margin,
        width = sw - 2 * margin,
        height = sh - 2 * margin,
        minWidth = 400,
        minHeight = 300,
        useLoadPanelTheme = true,
        draggable = true,
        closable = true,
        drawContent = Map.drawContent,
        onClose = function()
            Map.visible = false
        end
    })
end

function Map.draw(player, world, enemies, asteroids, wrecks, stations, lootDrops)
    if not Map.visible then return end
    if not Map.window then Map.init() end
    Map.window.visible = Map.visible
    Map.window:draw()
end

function Map.drawContent(window, mapX, mapY, mapW, mapH)
    local player = player
    local world = world
    local enemies = enemies
    local asteroids = asteroids
    local wrecks = wrecks
    local stations = stations
    local lootDrops = lootDrops

    -- Draw grid
    drawGrid(mapX, mapY, mapW, mapH, world)

    -- Draw world boundaries
    drawWorldBounds(mapX, mapY, mapW, mapH, world)

    -- Draw player trail
    drawPlayerTrail(mapX, mapY, mapW, mapH, world)

    -- Draw entities
    if Map.showEntities then
        -- Draw stations first (bottom layer)
        if Map.filterStations and stations then
            for _, station in ipairs(stations) do
                if not station.dead then
                    drawEntity(station, mapX, mapY, mapW, mapH, world, "station")
                end
            end
        end

        -- Draw warp gates
        if world then
            local warp_gates = world:get_entities_with_components("warp_gate")
            for _, warp_gate in ipairs(warp_gates) do
                if not warp_gate.dead then
                    drawEntity(warp_gate, mapX, mapY, mapW, mapH, world, "warp_gate")
                end
            end
        end

        -- Draw asteroids
        if Map.filterAsteroids and asteroids then
            for _, asteroid in ipairs(asteroids) do
                if not asteroid.dead then
                    drawEntity(asteroid, mapX, mapY, mapW, mapH, world, "asteroid")
                end
            end
        end

        -- Draw loot drops
        if lootDrops then
            for _, drop in ipairs(lootDrops) do
                local lootEntity = { components = { position = { x = drop.x, y = drop.y } } }
                drawEntity(lootEntity, mapX, mapY, mapW, mapH, world, "loot")
            end
        end

        -- Draw wrecks
        if Map.filterWrecks and wrecks then
            for _, wreck in ipairs(wrecks) do
                if not wreck.dead then
                    drawEntity(wreck, mapX, mapY, mapW, mapH, world, "wreck")
                end
            end
        end

        -- Draw enemies
        if Map.filterEnemies and enemies then
            for _, enemy in ipairs(enemies) do
                if not enemy.dead then
                    drawEntity(enemy, mapX, mapY, mapW, mapH, world, "enemy")
                end
            end
        end

        -- Draw player last (top layer)
        if player then
            drawEntity(player, mapX, mapY, mapW, mapH, world, "player")
        end
    end

    -- Draw controls and legend
    drawControls(mapX, mapY, mapW, mapH)
    drawLegend(mapX, mapY, mapW, mapH)
end

function Map.mousepressed(x, y, button)
    if not Map.visible then return false, false end
    if not Map.window then return false, false end

    if Map.window:mousepressed(x, y, button) then
        return true, false
    end

    if pointIn(x, y, {x = Map.window.x, y = Map.window.y, w = Map.window.width, h = Map.window.height}) then
        if button == 1 then
            Map.dragging = true
            Map.dragStartX = x
            Map.dragStartY = y
        end
        return true, false
    end

    return false, false
end

function Map.mousereleased(x, y, button)
    if not Map.visible then return false, false end
    if not Map.window then return false, false end

    if Map.window:mousereleased(x, y, button) then
        return true, false
    end

    if button == 1 then
        Map.dragging = false
    end

    return Map.visible, false
end

function Map.mousemoved(x, y, dx, dy, world)
    if not Map.visible then return false end
    if not Map.window then return false end

    if Map.window:mousemoved(x, y, dx, dy) then
        return true
    end

    if Map.dragging and world then
        local mapX, mapY, mapW, mapH = Map.window.x, Map.window.y, Map.window.width, Map.window.height

        -- Calculate new drag offsets
        local newDragOffsetX = Map.dragOffsetX + dx
        local newDragOffsetY = Map.dragOffsetY + dy

        -- Calculate world bounds in screen coordinates
        local scaledW = mapW * Map.scale
        local scaledH = mapH * Map.scale
        local centerOffsetX = Map.centerX * scaledW
        local centerOffsetY = Map.centerY * scaledH

        -- World bounds corners in screen space (without drag offset)
        local worldLeft = mapX + (mapW - scaledW) / 2 + centerOffsetX
        local worldTop = mapY + (mapH - scaledH) / 2 + centerOffsetY
        local worldRight = worldLeft + scaledW
        local worldBottom = worldTop + scaledH

        -- Constrain drag to keep world bounds within map area
        local minDragX = mapX - worldRight
        local maxDragX = mapX + mapW - worldLeft
        local minDragY = mapY - worldBottom
        local maxDragY = mapY + mapH - worldTop

        -- Apply constraints
        Map.dragOffsetX = math.max(minDragX, math.min(maxDragX, newDragOffsetX))
        Map.dragOffsetY = math.max(minDragY, math.min(maxDragY, newDragOffsetY))

        return true
    end

    return false
end

function Map.wheelmoved(dx, dy, world)
  if not Map.visible then return false end

  local mapX, mapY, mapW, mapH = getMapBounds()
  local mx, my = Viewport.getMousePosition()

  if pointIn(mx, my, {x = mapX, y = mapY, w = mapW, h = mapH}) then
    local oldScale = Map.scale
    local scaleFactor = (dy > 0) and 1.2 or (1/1.2)
    local newScale = Map.scale * scaleFactor

    -- Prevent zooming out beyond world bounds (minimum scale to fit world in map)
    local minScaleForBounds = Map.minScale
    if world then
      local scaleX = mapW / (world.width * 1.0) -- Scale needed to fit world width
      local scaleY = mapH / (world.height * 1.0) -- Scale needed to fit world height
      minScaleForBounds = math.max(scaleX, scaleY) -- Use the larger scale to ensure both dimensions fit
    end

    Map.scale = math.max(math.max(Map.minScale, minScaleForBounds), math.min(Map.maxScale, newScale))

    -- Adjust pan to zoom towards mouse cursor
    local scaleChange = Map.scale / oldScale - 1
    local mouseMapX = (mx - mapX - mapW/2) / mapW
    local mouseMapY = (my - mapY - mapH/2) / mapH

    Map.dragOffsetX = Map.dragOffsetX - mouseMapX * mapW * scaleChange
    Map.dragOffsetY = Map.dragOffsetY - mouseMapY * mapH * scaleChange

    -- Apply drag constraints after zoom
    if world then
      local scaledW = mapW * Map.scale
      local scaledH = mapH * Map.scale
      local centerOffsetX = Map.centerX * scaledW
      local centerOffsetY = Map.centerY * scaledH

      local worldLeft = mapX + (mapW - scaledW) / 2 + centerOffsetX
      local worldTop = mapY + (mapH - scaledH) / 2 + centerOffsetY
      local worldRight = worldLeft + scaledW
      local worldBottom = worldTop + scaledH

      local minDragX = mapX - worldRight
      local maxDragX = mapX + mapW - worldLeft
      local minDragY = mapY - worldBottom
      local maxDragY = mapY + mapH - worldTop

      Map.dragOffsetX = math.max(minDragX, math.min(maxDragX, Map.dragOffsetX))
      Map.dragOffsetY = math.max(minDragY, math.min(maxDragY, Map.dragOffsetY))
    end

    return true
  end

  return false
end

function Map.keypressed(key, world)
  if not Map.visible then return false end

  if key == "m" then
    Map.toggle(world)
    return true
  end

  return false
end

function Map.textinput(text)
  return Map.visible
end

return Map
