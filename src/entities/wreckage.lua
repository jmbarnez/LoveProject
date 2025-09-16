local Position = require("src.components.position")
local Physics = require("src.components.physics")
local Renderable = require("src.components.renderable")
local TimedLife = require("src.components.timed_life")
local Collidable = require("src.components.collidable")
local WreckageComponent = require("src.components.wreckage")

local Wreckage = {}

local function buildFragments(visuals)
  local frags = {}
  visuals = visuals or {}
  local palette = {}
  -- Collect colors from ship visuals palette or shapes
  if visuals.hullColor then table.insert(palette, visuals.hullColor) end
  if visuals.panelColor then table.insert(palette, visuals.panelColor) end
  if visuals.accentColor then table.insert(palette, visuals.accentColor) end
  if visuals.shapes and #visuals.shapes > 0 then
    for _, s in ipairs(visuals.shapes) do
      if s.color then table.insert(palette, s.color) end
    end
  end
  if #palette == 0 then
    palette = {
      {0.42, 0.45, 0.50, 1.0}, {0.32, 0.35, 0.39, 1.0}, {0.20, 0.22, 0.26, 1.0}
    }
  end

  -- Create 1-3 shard polygons per piece
  local shardCount = 1 + math.random(0, 2)
  local totalR = 0
  local totalShards = 0
  for i = 1, shardCount do
    local c = palette[math.random(1, #palette)]
    local r = 4 + math.random() * 8
    totalR = totalR + r
    totalShards = totalShards + 1
    local a0 = math.random() * math.pi * 2
    local pts = {}
    local sides = 3 + math.random(0, 1) -- triangle or quad
    for k = 1, sides do
      local ang = a0 + (k - 1) * (2 * math.pi / sides) + (math.random() - 0.5) * 0.3
      local rr = r * (0.6 + math.random() * 0.5)
      table.insert(pts, math.cos(ang) * rr)
      table.insert(pts, math.sin(ang) * rr)
    end
    -- Use color table c (RGBA); adjust alpha slightly
    local rr, gg, bb, aa
    if type(c) == 'table' then
      rr, gg, bb, aa = c[1] or 1, c[2] or 1, c[3] or 1, (c[4] or 1) * 0.95
    else
      rr, gg, bb, aa = c or 0.8, c or 0.8, c or 0.8, 0.95
    end
    table.insert(frags, { type = "polygon", mode = "fill", color = { rr, gg, bb, aa }, points = pts })
    -- Outline
    table.insert(frags, { type = "polygon", mode = "line", color = {0,0,0,0.25}, points = pts })
  end
  local avgR = (totalShards > 0) and (totalR / totalShards) or 6
  return frags, avgR
end

local function newPiece(px, py, vx, vy, angle, angularVel, lifetime, visuals)
  local e = { components = {} }
  e.components.position = Position.new({ x = px, y = py, angle = angle or 0 })
  e.components.physics = Physics.new({
    x = px, y = py,
    mass = 80, -- Light enough to be pushed around
  })
  -- Very low drag so wreckage travels very far before stopping
  e.components.physics.body.dragCoefficient = 0.995
  e.components.physics.body:setVelocity(vx, vy)
  e.components.physics.body.angularVel = angularVel or 0
  local fragments, avgR = buildFragments(visuals)
  e.components.renderable = Renderable.new({
    type = "wreckage",
    props = {
      size = (visuals and visuals.size) or 1.0,
      visuals = visuals,
      fragments = fragments
    }
  })
  e.components.timed_life = TimedLife.new(lifetime or 5)
  -- Approximate size for targeting radius (Input uses size*10)
  e.size = math.max(1, (avgR or 6) / 3)
  e.radius = e.size * 10
  -- Provide ECS collidable radius to remove legacy fallbacks
  e.components.collidable = Collidable.new({ radius = e.radius })
  -- Salvage fields and methods
  local sizeHint = (avgR or 6) * ((visuals and visuals.size) or 1.0)
  e.components.wreckage = WreckageComponent.new({
      resourceType = "scraps",
      salvageAmount = math.max(1, math.floor(sizeHint / 4)),
      salvageCycleTime = 0.9 + math.random() * 0.6,
      scanned = false
  })
  -- Expose select fields + simple API on the entity itself so turret system can interact
  e.resourceType = e.components.wreckage.resourceType
  e.salvageAmount = e.components.wreckage.salvageAmount
  function e:canBeSalvaged()
    return (self.salvageAmount or 0) > 0
  end
  function e:startSalvaging()
    if self.components and self.components.wreckage then
      self.components.wreckage.isBeingSalvaged = true
    end
  end
  -- Perform a single salvage cycle; returns true if one unit was salvaged
  function e:salvageCycle()
    if (self.salvageAmount or 0) <= 0 then return false end
    -- Decrement salvage on both the entity mirror and the component
    self.salvageAmount = (self.salvageAmount or 0) - 1
    if self.components and self.components.wreckage then
      self.components.wreckage.salvageAmount = math.max(0, (self.components.wreckage.salvageAmount or 0) - 1)
      self.components.wreckage.salvageProgress = 0
    end
    if self.salvageAmount <= 0 then
      self.dead = true
    end
    return true
  end
  return e
end

-- originPos: Position component or table with x,y
function Wreckage.spawnFromEnemy(originPos, visuals, sizeScale)
  local pieces = {}
  local ox = originPos.x or 0
  local oy = originPos.y or 0
  sizeScale = sizeScale or 1.0
  -- Spawn just a few larger pieces so they’re easier to salvage
  local numPieces = 1 + math.random(0, 3) -- 1-4 pieces
  local lootPiece = math.random(1, numPieces)

  for i = 1, numPieces do
    local pieceLoot = nil
    if i == lootPiece and math.random() < 0.25 then
      pieceLoot = { { id = "scraps", qty = math.random(1, 5) } }
    end
    local ang = (i / numPieces) * math.pi * 2 + (math.random() - 0.5) * 0.6
    local speed = (150 + math.random() * 200) * sizeScale  -- Much higher speed for maximum spread
    local vx = math.cos(ang) * speed
    local vy = math.sin(ang) * speed
    local angularVel = (math.random() - 0.5) * 1  -- Reduced from ±2 to ±0.5 radians/sec
    -- Extend lifetime so wreckage persists for salvaging (10 minutes)
    local lifetime = 600 -- seconds
    local px = ox + (math.random() - 0.5) * 40
    local py = oy + (math.random() - 0.5) * 40
    table.insert(pieces, newPiece(px, py, vx, vy, math.random() * math.pi * 2, angularVel, lifetime, visuals))
    if pieceLoot then
      for _, stack in ipairs(pieceLoot) do
        local angle = math.random() * math.pi * 2
        local dist = math.random(10, 30)
        local lpx = px + math.cos(angle) * dist
        local lpy = py + math.sin(angle) * dist
        local ItemPickup = require("src.entities.item_pickup")
        local pickup = ItemPickup.new(lpx, lpy, stack.id, stack.qty)
        table.insert(pieces, pickup)
      end
    end
  end

  return pieces
end

return Wreckage
