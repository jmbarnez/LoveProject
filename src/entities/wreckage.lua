local Position = require("src.components.position")
local Physics = require("src.components.physics")
local Renderable = require("src.components.renderable")
local TimedLife = require("src.components.timed_life")
local Collidable = require("src.components.collidable")
local WreckageComponent = require("src.components.wreckage")

local Wreckage = {}

local function buildFragments(visuals, sizeScale)
  local frags = {}
  visuals = visuals or {}
  sizeScale = sizeScale or 1.0
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

  -- Create 1-3 shard polygons per piece, scaled by ship size
  local shardCount = 1 + math.random(0, 2)
  local totalR = 0
  local totalShards = 0
  for i = 1, shardCount do
    local c = palette[math.random(1, #palette)]
    -- Scale fragment size based on ship size - made bigger overall
    local baseR = 8 + math.random() * 12  -- Increased from 4-12 to 8-20
    local r = baseR * sizeScale
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
  local avgR = (totalShards > 0) and (totalR / totalShards) or (6 * sizeScale)
  return frags, avgR
end

local function newPiece(px, py, vx, vy, angle, angularVel, lifetime, visuals, sizeScale)
  local e = { components = {} }
  e.components.position = Position.new({ x = px, y = py, angle = angle or 0 })
  e.components.physics = Physics.new({
    x = px, y = py,
    mass = 60, -- Light enough to be pushed around easily
  })
  -- Very low drag so wreckage travels very far before stopping
  e.components.physics.body.dragCoefficient = 0.995
  -- Add some angular damping to prevent excessive spinning
  e.components.physics.body.angularDamping = 0.98
  -- Use an impulse to start movement so it respects mass/momentum
  do
    local body = e.components.physics.body
    body:applyImpulse((vx or 0) * body.mass, (vy or 0) * body.mass)
    body.angularVel = angularVel or 0
  end
  local fragments, avgR = buildFragments(visuals, sizeScale)
  e.components.renderable = Renderable.new({
    type = "wreckage",
    props = {
      size = ((visuals and visuals.size) or 1.0) * (sizeScale or 1.0),
      visuals = visuals,
      fragments = fragments
    }
  })
  e.components.timed_life = TimedLife.new(lifetime or 5)
  -- Approximate size for targeting radius (Input uses size*10)
  e.size = math.max(1, (avgR or 6) / 3)
  e.radius = e.size * 10
  -- Keep physics collision radius aligned with visual/collidable radius
  if e.components.physics and e.components.physics.body then
    e.components.physics.body.radius = e.radius
  end
  
  -- Generate polygon collision shape from visual fragments
  local collisionVertices = {}
  local maxRadius = 0
  
  -- Combine all fragment polygons into a single collision shape
  for _, fragment in ipairs(fragments) do
    if fragment.type == "polygon" and fragment.points then
      -- Add vertices from this fragment to the collision shape
      for i = 1, #fragment.points, 2 do
        local vx = fragment.points[i] or 0
        local vy = fragment.points[i + 1] or 0
        table.insert(collisionVertices, vx)
        table.insert(collisionVertices, vy)
        
        -- Track maximum radius for fallback
        local distance = math.sqrt(vx * vx + vy * vy)
        if distance > maxRadius then
          maxRadius = distance
        end
      end
    end
  end
  
  -- If no vertices were generated, create a simple triangle as fallback
  if #collisionVertices == 0 then
    local fallbackRadius = avgR or 6
    collisionVertices = {
      fallbackRadius, 0,
      -fallbackRadius * 0.5, fallbackRadius * 0.866,
      -fallbackRadius * 0.5, -fallbackRadius * 0.866
    }
    maxRadius = fallbackRadius
  end
  
  -- Provide ECS collidable with polygon shape
  e.components.collidable = Collidable.new({ 
    shape = "polygon",
    vertices = collisionVertices,
    radius = maxRadius -- Keep radius for broad-phase collision detection
  })
  -- Delay collisions briefly so fragments emerge before pushing each other away
  e._collisionGrace = 0.25
  -- Salvage fields and methods - scale salvage amount with ship size
  local sizeHint = (avgR or 6) * ((visuals and visuals.size) or 1.0) * (sizeScale or 1.0)
  e.components.wreckage = WreckageComponent.new({
      resourceType = "scraps",
      salvageAmount = math.max(2, math.floor(sizeHint * 0.3)), -- Much less durable: reduced from 5+ to 2+ and 0.3x multiplier
      salvageCycleTime = 0.4 + math.random() * 0.3, -- Much faster salvaging: reduced from 0.9-1.5s to 0.4-0.7s
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
  -- Spawn more pieces for better visibility and easier salvaging
  local numPieces = 2 + math.random(0, 4) -- 2-6 pieces (increased from 1-4)
  local lootPiece = math.random(1, numPieces)

  for i = 1, numPieces do
    local pieceLoot = nil
    -- Reduced chance for wreckage to drop loot - only 10% chance instead of 25%
    if i == lootPiece and math.random() < 0.10 then
      pieceLoot = { { id = "scraps", qty = math.random(1, 3) } }
    end
    local ang = (i / numPieces) * math.pi * 2 + (math.random() - 0.5) * 0.6
    -- Slower, more weighty outward impulse for realism
    local speed = (60 + math.random() * 60) * sizeScale
    local vx = math.cos(ang) * speed
    local vy = math.sin(ang) * speed
    local angularVel = (math.random() - 0.5) * 1  -- Reduced from ±2 to ±0.5 radians/sec
    -- Extend lifetime so wreckage persists for salvaging (10 minutes)
    local lifetime = 600 -- seconds
    local px = ox
    local py = oy
    table.insert(pieces, newPiece(px, py, vx, vy, math.random() * math.pi * 2, angularVel, lifetime, visuals, sizeScale))
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
