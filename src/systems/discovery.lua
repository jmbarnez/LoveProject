--[[
  Discovery System
  
  Handles fog-of-war and map exploration state.
  Self-contained module that can be used by both minimap and full map.
]]

local Sound = require("src.core.sound")
local Log = require("src.core.log")

local Discovery = {}

-- Configuration
Discovery.gridSize = 800
Discovery.revealRadius = 1400
Discovery.poiDetectionRange = 2200
Discovery.poiRevealRadius = 1600

-- Internal state
Discovery.discovered = nil
Discovery._discW = nil
Discovery._discH = nil
Discovery._gx = nil
Discovery._gy = nil
Discovery._poiRevealed = {}

-- Initialize discovery grid for a world
function Discovery.init(world)
  if not world then return end
  -- Guard against accidentally passing the module instead of the instance
  if not world.width or not world.height then return end
  if Discovery.discovered and Discovery._discW == world.width and Discovery._discH == world.height then return end
  
  local cell = Discovery.gridSize
  local gx = math.max(1, math.ceil(world.width / cell))
  local gy = math.max(1, math.ceil(world.height / cell))
  
  Discovery.discovered = {}
  for j = 1, gy do
    local row = {}
    for i = 1, gx do row[i] = false end
    Discovery.discovered[j] = row
  end
  
  Discovery._discW = world.width
  Discovery._discH = world.height
  Discovery._gx = gx
  Discovery._gy = gy
end

-- Convert world coordinates to grid cell
local function worldToCell(wx, wy)
  local cell = Discovery.gridSize
  local cx = math.floor(wx / cell) + 1
  local cy = math.floor(wy / cell) + 1
  return cx, cy
end

-- Reveal a circular area around a point
function Discovery.revealAt(wx, wy, radius)
  radius = radius or Discovery.revealRadius
  if not Discovery.discovered or not Discovery._gx or not Discovery._gy then return end
  
  local cell = Discovery.gridSize
  local minCx = math.max(1, math.floor((wx - radius) / cell) + 1)
  local maxCx = math.min(Discovery._gx, math.floor((wx + radius) / cell) + 1)
  local minCy = math.max(1, math.floor((wy - radius) / cell) + 1)
  local maxCy = math.min(Discovery._gy, math.floor((wy + radius) / cell) + 1)
  local r2 = radius * radius
  
  for cy = minCy, maxCy do
    for cx = minCx, maxCx do
      local centerX = (cx - 0.5) * cell
      local centerY = (cy - 0.5) * cell
      local dx, dy = centerX - wx, centerY - wy
      if dx*dx + dy*dy <= r2 then
        Discovery.discovered[cy][cx] = true
      end
    end
  end
end

-- Check if a world position is discovered
function Discovery.isDiscovered(wx, wy)
  if not Discovery.discovered then return true end
  local cx, cy = worldToCell(wx, wy)
  if cy < 1 or cy > (Discovery._gy or 0) or cx < 1 or cx > (Discovery._gx or 0) then return false end
  return Discovery.discovered[cy][cx] == true
end

-- Auto-reveal around major POIs when detected
local function autoRevealPOIs(player, world)
  if not player or not world then return end
  local p = player.components and player.components.position
  if not p then return end

  local function revealIfClose(entity, key)
    if not entity or not entity.components or not entity.components.position then return end
    local ex, ey = entity.components.position.x, entity.components.position.y
    local dx, dy = ex - p.x, ey - p.y
    local d2 = dx*dx + dy*dy
    local r = Discovery.poiDetectionRange
    if d2 <= r*r then
      if not Discovery._poiRevealed[key] then
        Discovery.revealAt(ex, ey, Discovery.poiRevealRadius)
        Discovery._poiRevealed[key] = true
        Sound.playSFXAt("ui_click", ex, ey, 0.9)
      end
    end
  end

  -- Stations
  local stations = world:get_entities_with_components("station") or {}
  for _, s in ipairs(stations) do
    local id = (s.components and s.components.station and s.components.station.type) or "station"
    local key = string.format("station:%s:%.0f:%.0f", id, (s.components.position.x or 0), (s.components.position.y or 0))
    revealIfClose(s, key)
  end
  
  -- Warp gates
  local warp_gates = world:get_entities_with_components("warp_gate") or {}
  for _, g in ipairs(warp_gates) do
    local key = string.format("warp:%.0f:%.0f", (g.components.position.x or 0), (g.components.position.y or 0))
    revealIfClose(g, key)
  end
end

-- Update discovery state
function Discovery.update(player, world)
  if not player then return end
  Discovery.init(world)
  
  -- Reveal around player position
  if world and player.components and player.components.position then
    local pos = player.components.position
    Discovery.revealAt(pos.x, pos.y, Discovery.revealRadius)
  end
  
  -- POI auto-reveal
  autoRevealPOIs(player, world)
end

-- Get discovery grid data for rendering
function Discovery.getGrid()
  return Discovery.discovered, Discovery.gridSize, Discovery._gx, Discovery._gy
end

-- Serialize discovery state for saving
function Discovery.serialize()
  if not Discovery.discovered or not Discovery._gx or not Discovery._gy then return nil end
  
  local cells = {}
  for cy = 1, Discovery._gy do
    for cx = 1, Discovery._gx do
      if Discovery.discovered[cy][cx] then
        table.insert(cells, (cy - 1) * Discovery._gx + cx)
      end
    end
  end
  
  return {
    gridSize = Discovery.gridSize,
    gx = Discovery._gx,
    gy = Discovery._gy,
    width = Discovery._discW,
    height = Discovery._discH,
    cells = cells,
  }
end

-- Deserialize discovery state from save
function Discovery.deserialize(data, world)
  if not data or not world then return end
  
  Discovery.gridSize = data.gridSize or Discovery.gridSize
  Discovery._gx = data.gx or Discovery._gx
  Discovery._gy = data.gy or Discovery._gy
  Discovery._discW = data.width or world.width
  Discovery._discH = data.height or world.height
  
  Discovery.discovered = {}
  for cy = 1, (Discovery._gy or 0) do
    local row = {}
    for cx = 1, (Discovery._gx or 0) do row[cx] = false end
    Discovery.discovered[cy] = row
  end
  
  if data.cells then
    for _, idx in ipairs(data.cells) do
      local cx = ((idx - 1) % Discovery._gx) + 1
      local cy = math.floor((idx - 1) / Discovery._gx) + 1
      if Discovery.discovered[cy] then
        Discovery.discovered[cy][cx] = true
      end
    end
  end
end

-- Reset discovery state
function Discovery.reset()
  Discovery.discovered = nil
  Discovery._discW = nil
  Discovery._discH = nil
  Discovery._gx = nil
  Discovery._gy = nil
  Discovery._poiRevealed = {}
end

return Discovery
