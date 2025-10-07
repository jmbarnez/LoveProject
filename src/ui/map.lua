--[[
  Map UI
  
  Clean, self-contained map system using modular components.
  Handles both full map and minimap rendering through shared systems.
]]

local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local Util = require("src.core.util")
local Window = require("src.ui.common.window")
local Transform = require("src.ui.map.transform")
local Draw = require("src.ui.map.draw")
local Discovery = require("src.systems.discovery")
local MapEntities = require("src.systems.map_entities")
local MapRenderer = require("src.systems.map_renderer")
local Sound = require("src.core.sound")
local Sectors = require("src.content.sectors")

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

function Map.isVisible()
  return Map.visible == true
end

function Map.show()
  Map.visible = true
end

function Map.hide()
  Map.visible = false
end

local function pointIn(px, py, r)
  if px == nil or py == nil or r == nil or r.x == nil or r.y == nil or r.w == nil or r.h == nil then
    return false
  end
  return px >= r.x and py >= r.y and px <= r.x + r.w and py <= r.y + r.h
end

local function getMapBounds()
  local sw, sh = Viewport.getDimensions()
  local mapW, mapH = sw * 0.8, sh * 0.8
  local mapX, mapY = (sw - mapW) / 2, (sh - mapH) / 2
  return mapX, mapY, mapW, mapH
end

local function getMapState()
  return {
    centerX = Map.centerX,
    centerY = Map.centerY,
    scale = Map.scale,
    dragOffsetX = Map.dragOffsetX or 0,
    dragOffsetY = Map.dragOffsetY or 0,
    gridSize = Map.gridSize,
    showGrid = Map.showGrid,
    showEntities = Map.showEntities,
    showTrails = Map.showTrails,
    filterEnemies = Map.filterEnemies,
    filterAsteroids = Map.filterAsteroids,
    filterWrecks = Map.filterWrecks,
    filterStations = Map.filterStations,
  }
end

function Map.toggle()
  Map.visible = not Map.visible
  if Map.visible then
    Sound.playSFX("ui_click")
  else
    Sound.playSFX("ui_close")
  end
end

function Map.update(dt, player)
  if not player or not player.components or not player.components.position then return end
  
  local pos = player.components.position
  Map.lastPlayerPos.x = pos.x
  Map.lastPlayerPos.y = pos.y
  
  -- Update discovery system
  local State = require("src.game.state")
  local world = State.world
  Discovery.update(player, world)
  
  -- Update player trail
  if Map.showTrails then
    table.insert(Map.playerTrail, {x = pos.x, y = pos.y, time = love.timer.getTime()})
    if #Map.playerTrail > Map.maxTrailLength then
        table.remove(Map.playerTrail, 1)
    end
  end
end

function Map.draw(player, world)
  if not Map.visible or not player then return end
  local State = require("src.game.state")
  world = world or State.world
  if not world then return end
  
  local mapX, mapY, mapW, mapH = getMapBounds()
  local mapState = getMapState()
  
  -- Create viewport for renderer
  local viewport = {
    type = "full_map",
    mapX = mapX,
    mapY = mapY,
    mapW = mapW,
    mapH = mapH,
    mapState = mapState,
    showGrid = Map.showGrid,
    gridSize = Map.gridSize
  }
  
  -- Get visible entities
  local filters = {
    stations = Map.filterStations,
    enemies = Map.filterEnemies,
    asteroids = Map.filterAsteroids,
    wrecks = Map.filterWrecks,
    warp_gates = true,
    remote_players = true
  }
  
  local entities = MapEntities.getVisibleEntities(world, Discovery, filters)
  
  -- Draw the map
  MapRenderer.drawFullMap(player, world, entities, Discovery, viewport)
  
  -- Draw UI overlay
  Map.drawUI(mapX, mapY, mapW, mapH)
end

function Map.drawUI(mapX, mapY, mapW, mapH)
  -- Draw map border
  Theme.setColor(Theme.colors.border)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", mapX, mapY, mapW, mapH)
  
  -- Draw controls
  local controlY = mapY + 10
  local controlX = mapX + 10
  
  -- Scale controls
  Theme.setColor(Theme.colors.text)
  love.graphics.print(string.format("Scale: %.2fx", Map.scale), controlX, controlY)
  controlY = controlY + 20
  
  -- Filter toggles
  local filters = {
    {key = "filterStations", label = "Stations", value = Map.filterStations},
    {key = "filterEnemies", label = "Enemies", value = Map.filterEnemies},
    {key = "filterAsteroids", label = "Asteroids", value = Map.filterAsteroids},
    {key = "filterWrecks", label = "Wrecks", value = Map.filterWrecks},
  }
  
  for _, filter in ipairs(filters) do
    local color = filter.value and Theme.colors.success or Theme.colors.text
    Theme.setColor(color)
    love.graphics.print(string.format("%s: %s", filter.label, filter.value and "ON" or "OFF"), controlX, controlY)
    controlY = controlY + 15
  end
  
  -- Grid toggle
  local gridColor = Map.showGrid and Theme.colors.success or Theme.colors.text
  Theme.setColor(gridColor)
  love.graphics.print(string.format("Grid: %s", Map.showGrid and "ON" or "OFF"), controlX, controlY)
  controlY = controlY + 15
  
  -- Trails toggle
  local trailColor = Map.showTrails and Theme.colors.success or Theme.colors.text
  Theme.setColor(trailColor)
  love.graphics.print(string.format("Trails: %s", Map.showTrails and "ON" or "OFF"), controlX, controlY)
end

function Map.mousepressed(x, y, button)
  if not Map.visible then return false end

  local mapX, mapY, mapW, mapH = getMapBounds()
  if not pointIn(x, y, {x = mapX, y = mapY, w = mapW, h = mapH}) then return false end

        if button == 1 then
            Map.dragging = true
            Map.dragStartX = x
            Map.dragStartY = y
    Map.dragOffsetX = Map.centerX
    Map.dragOffsetY = Map.centerY
    return true
    end

  return false
end

function Map.mousemoved(x, y, dx, dy)
  if not Map.visible or not Map.dragging then return false end

  local mapX, mapY, mapW, mapH = getMapBounds()
  if not pointIn(x, y, {x = mapX, y = mapY, w = mapW, h = mapH}) then return false end

  local world = require("src.core.world")
  if not world then return false end

  local scale = Map.scale
  local newCenterX = Map.dragOffsetX - (x - Map.dragStartX) / scale
  local newCenterY = Map.dragOffsetY - (y - Map.dragStartY) / scale

  Map.centerX = math.max(0, math.min(world.width, newCenterX))
  Map.centerY = math.max(0, math.min(world.height, newCenterY))

        return true
    end

function Map.mousereleased(x, y, button)
  if not Map.visible then return false end
  
  if button == 1 and Map.dragging then
    Map.dragging = false
        return true
    end

    return false
end

function Map.wheelmoved(x, y)
  if not Map.visible then return false end

  local mapX, mapY, mapW, mapH = getMapBounds()
  local mx, my = love.mouse.getPosition()
  if not pointIn(mx, my, {x = mapX, y = mapY, w = mapW, h = mapH}) then return false end

    local oldScale = Map.scale
  Map.scale = math.max(Map.minScale, math.min(Map.maxScale, Map.scale * (1 + y * 0.1)))

  if Map.scale ~= oldScale then
    local world = require("src.core.world")
    if world then
      local scaleRatio = Map.scale / oldScale
      local mouseWorldX = Map.centerX + (mx - mapX - mapW/2) / oldScale
      local mouseWorldY = Map.centerY + (my - mapY - mapH/2) / oldScale
      
      Map.centerX = mouseWorldX - (mx - mapX - mapW/2) / Map.scale
      Map.centerY = mouseWorldY - (my - mapY - mapH/2) / Map.scale
      
      Map.centerX = math.max(0, math.min(world.width, Map.centerX))
      Map.centerY = math.max(0, math.min(world.height, Map.centerY))
    end
    return true
  end

  return false
end

function Map.keypressed(key)
  if not Map.visible then return false end

  if key == "g" then
    Map.showGrid = not Map.showGrid
    Sound.playSFX("ui_click")
    return true
  elseif key == "t" then
    Map.showTrails = not Map.showTrails
    Sound.playSFX("ui_click")
    return true
  elseif key == "s" then
    Map.filterStations = not Map.filterStations
    Sound.playSFX("ui_click")
    return true
  elseif key == "e" then
    Map.filterEnemies = not Map.filterEnemies
    Sound.playSFX("ui_click")
    return true
  elseif key == "a" then
    Map.filterAsteroids = not Map.filterAsteroids
    Sound.playSFX("ui_click")
    return true
  elseif key == "w" then
    Map.filterWrecks = not Map.filterWrecks
    Sound.playSFX("ui_click")
    return true
  end

  return false
end

-- Expose discovery functions for minimap
function Map.ensureDiscovery(world)
  Discovery.init(world)
end

function Map.isDiscovered(wx, wy)
  return Discovery.isDiscovered(wx, wy)
end

function Map.getDiscovery()
  return Discovery
end

function Map.revealAt(wx, wy, radius)
  Discovery.revealAt(wx, wy, radius)
end

function Map.getDiscoveryForSave()
  return Discovery.serialize()
end

function Map.setDiscoveryFromSave(data)
  local world = require("src.core.world")
  Discovery.deserialize(data, world)
end

return Map