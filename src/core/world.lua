--[[
    World module

    Owns the authoritative list of entities and is responsible for maintaining
    background visuals (starfields, nebulae) that give the game its sense of
    scale. The simulation systems mutate entities, but this module provides the
    scaffolding for queries, quadtree lookups, and utility drawing data.
]]

local Viewport = require("src.core.viewport")
local World = {}
World.__index = World

-- Generate a set of parallax stars positioned in world space.
local function genStars(w, h, count, parallax)
  local stars = {}
  for i = 1, count do
    -- Distant stars: tiny but slightly larger for visibility
    stars[i] = { x = math.random() * w, y = math.random() * h, p = parallax, s = 0.30 + math.random() * 0.40 }
  end
  return stars
end

-- Screen-space static sky stars (no parallax) to emphasize extreme distance
-- Generate screen-space "sky" stars that never parallax with the camera.
local function genSkyStars(sw, sh, count)
  local stars = {}
  for i = 1, count do
    stars[i] = {
      x = math.random() * sw,
      y = math.random() * sh,
      s = 0.14 + math.random() * 0.22,
      a = 0.06 + math.random() * 0.06,
      tw = 0.35 + math.random() * 0.55, -- twinkle speed
      ph = math.random() * math.pi * 2, -- twinkle phase
    }
  end
  return stars
end

-- Screen-space parallax stars (move with camera by a small factor)
-- Generate screen-space parallax stars that follow the camera subtly.
local function genScreenStars(sw, sh, count)
  local stars = {}
  for i = 1, count do
    stars[i] = { x = math.random() * sw, y = math.random() * sh, s = 0.28 + math.random() * 0.36 }
  end
  return stars
end



--[[
    Create a new world instance. Besides entity storage, we eagerly build the
    procedural background caches so renderers can reuse them without triggering
    extra allocations mid-frame.
]]
function World.new(width, height)
  local self = setmetatable({}, World)
  self.width = width
  self.height = height
  self.entities = {}
  self.next_id = 1
  -- Screen-space star layers + static sky stars
  self.starLayers = {
    { p = 0.040, stars = {} }, -- far
    { p = 0.015, stars = {} }, -- very far
  }
  self.skyW, self.skyH = 0, 0
  self.skyStars = {}
  self.starW, self.starH = 0, 0
  self.nebulaW, self.nebulaH = 0, 0
  self.nebulaCanvas = nil
  self.planets = {}
  self.ecs_world = nil
  -- Initial stars build
  local sw, sh = Viewport.getDimensions()
  self.starW, self.starH = sw, sh
  local scale = (sw * sh) / (1920 * 1080)
  self.starLayers[1].stars = genScreenStars(sw, sh, math.floor(120 * math.max(1, scale)))
  self.starLayers[2].stars = genScreenStars(sw, sh, math.floor(80  * math.max(1, scale)))

  -- Cache for star rendering batches
  self.starBatches = {}
  self.lastScreenSize = {w = sw, h = sh}

  -- Update frequency control for background elements
  self.backgroundUpdateCounter = 0
  return self
end
-- Attach a quadtree implementation for accelerated spatial queries.
function World:setQuadtree(quadtree)
    self.quadtree = quadtree
end

function World:setECSWorld(ecs_world)
    self.ecs_world = ecs_world
end

function World:getECSWorld()
    return self.ecs_world
end

-- A lightweight throttle for background animation work; avoids redundant math.
function World:shouldUpdateBackground(frequency)
    frequency = frequency or 5 -- Update every 5 frames by default
    self.backgroundUpdateCounter = (self.backgroundUpdateCounter + 1) % frequency
    return self.backgroundUpdateCounter == 0
end

--[[
    Retrieve all entities intersecting the provided bounds. Falls back to a
    linear scan when a quadtree has not been injected, keeping the call site
    behaviour consistent in both debug and production builds.
]]
function World:getEntitiesInRect(bounds)
    if not self.quadtree then
        -- Fallback to iterating all entities if quadtree is not available
        local allEntities = {}
        for _, entity in pairs(self:getEntities()) do
            table.insert(allEntities, entity)
        end
        return allEntities
    end

    local results = self.quadtree:query(bounds)
    local entities = {}
    for _, item in ipairs(results) do
        table.insert(entities, item.entity)
    end
    return entities
end

function World:addEntity(entity)
    if not entity.components then
        local Log = require("src.core.log")
        Log.warn("Entity added to world without a components table!")
        entity.components = {}
    end
    local id = self.next_id
    self.next_id = self.next_id + 1
    entity.id = id
    self.entities[id] = entity
    if self.ecs_world then
        self.ecs_world:addEntity(entity)
    end
    return entity
end

function World:removeEntity(entity)
    if entity and entity.id then
        self.entities[entity.id] = nil
        if self.ecs_world then
            self.ecs_world:removeEntity(entity)
        end
    end
end

function World:getEntity(id)
    return self.entities[id]
end

function World:getEntities()
    return self.entities
end

function World:get_entities_with_components(...)
    local components = {...}
    local result = {}
    for id, entity in pairs(self.entities) do
        local has_all = true
        for _, component_name in ipairs(components) do
            if not entity.components[component_name] then
                has_all = false
                break
            end
        end
        if has_all then
            table.insert(result, entity)
        end
    end
    return result
end
function World:getPlayer()
  for id, entity in pairs(self.entities) do
    if entity.isPlayer then
      return entity
    end
  end
  return nil
end

function World:resize(w, h)
    self.nebulaW, self.nebulaH = w, h
    -- Create a simple nebula canvas (placeholder for now)
    self.nebulaCanvas = love.graphics.newCanvas(w, h)
    love.graphics.setCanvas(self.nebulaCanvas)
    love.graphics.clear(0, 0, 0, 0) -- Transparent
    love.graphics.setCanvas()
end

function World:update(dt)
    -- Clean up dead entities
    for id, entity in pairs(self.entities) do
        if entity.dead then
            self:removeEntity(entity)
        end
    end
end

function World:refreshEntity(entity)
    if self.ecs_world then
        self.ecs_world:refresh(entity)
    end
end

function World:contains(x, y, r)
  -- Handle nil values gracefully
  if not x or not y or not r or r < 0 then return false end
  return x > r and y > r and x < self.width - r and y < self.height - r
end

function World:drawBackground(camera)
  -- Draw in screen space regardless of camera
  love.graphics.push('all')
  love.graphics.origin()
  love.graphics.clear(0, 0, 0) -- Pure black space background
  local w, h = Viewport.getDimensions()
  -- Regenerate static sky on resolution change
  if self.skyW ~= w or self.skyH ~= h or (#self.skyStars == 0) then
    self.skyW, self.skyH = w, h
    local scale = (w * h) / (1920 * 1080)
    -- Density tuned for 1080p base (increased for visibility)
    self.skyStars = genSkyStars(w, h, math.floor(480 * math.max(1, scale)))
  end
  -- Draw static sky (no parallax) with slow twinkle
  -- Only update twinkling every few frames for better performance
  local t = (love.timer and love.timer.getTime and love.timer.getTime()) or 0
  local shouldUpdateTwinkle = self:shouldUpdateBackground(3) -- Update twinkling every 3 frames

  for i = 1, #self.skyStars do
    local s = self.skyStars[i]
    -- Disable twinkling temporarily to test for flicker
    local alpha = s.a
    love.graphics.setColor(1, 1, 1, alpha)
    local sx = math.floor(s.x) + 0.5
    local sy = math.floor(s.y) + 0.5
    love.graphics.circle('fill', sx, sy, s.s)
  end
  -- Rebuild parallax screen-space stars on resize
  if self.starW ~= w or self.starH ~= h then
    self.starW, self.starH = w, h
    local scale = (w * h) / (1920 * 1080)
    self.starLayers[1].stars = genScreenStars(w, h, math.floor(160 * math.max(1, scale)))
    self.starLayers[2].stars = genScreenStars(w, h, math.floor(120 * math.max(1, scale)))
  end
  -- Parallax stars: move slightly with camera and wrap on screen bounds
  -- Use batched rendering for better performance
  for li = 1, #self.starLayers do
    local layer = self.starLayers[li]
    local p = layer.p or 0.02
    local ox = (-camera.x * p) % w
    local oy = (-camera.y * p) % h
    local alpha = math.min(0.35, 0.12 + 1.8 * p)
    love.graphics.setColor(1,1,1, alpha)

    -- Batch star rendering for better performance
    local batch = self.starBatches[li]
    if not batch or self.lastScreenSize.w ~= w or self.lastScreenSize.h ~= h then
      -- Create new sprite batch for this layer
      if love.graphics.newSpriteBatch then
        -- Use a simple 1x1 white pixel image for stars
        local starImage = love.graphics.newImage(love.image.newImageData(1, 1))
        batch = love.graphics.newSpriteBatch(starImage, #layer.stars)
        self.starBatches[li] = batch
      end
      self.lastScreenSize = {w = w, h = h}
    end

    if batch then
      -- Clear and repopulate batch
      batch:clear()
      for i = 1, #layer.stars do
        local s = layer.stars[i]
        local sx = s.x + ox
        local sy = s.y + oy
        if sx >= w then sx = sx - w end
        if sy >= h then sy = sy - h end
        if sx < 0 then sx = sx + w end
        if sy < 0 then sy = sy + h end
        local sxs = math.floor(sx) + 0.5
        local sys = math.floor(sy) + 0.5
        batch:add(sxs, sys, 0, s.s * 2, s.s * 2) -- Scale the 1x1 pixel to star size
      end
      love.graphics.draw(batch)
    else
      -- Fallback to individual draw calls if sprite batches not available
      for i = 1, #layer.stars do
        local s = layer.stars[i]
        local sx = s.x + ox
        local sy = s.y + oy
        if sx >= w then sx = sx - w end
        if sy >= h then sy = sy - h end
        if sx < 0 then sx = sx + w end
        if sy < 0 then sy = sy + h end
        local sxs = math.floor(sx) + 0.5
        local sys = math.floor(sy) + 0.5
        love.graphics.circle('fill', sxs, sys, s.s)
      end
    end
  end
  love.graphics.pop()
end

function World:drawBounds()
  love.graphics.setColor(0.2, 0.4, 0.8, 0.2)
  love.graphics.rectangle("line", 0, 0, self.width, self.height)
end

return World
