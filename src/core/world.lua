local Viewport = require("src.core.viewport")

local World = {}
World.__index = World

local function genStars(w, h, count, parallax)
  local stars = {}
  for i = 1, count do
    -- Distant stars: tiny but slightly larger for visibility
    stars[i] = { x = math.random() * w, y = math.random() * h, p = parallax, s = 0.30 + math.random() * 0.40 }
  end
  return stars
end

-- Screen-space static sky stars (no parallax) to emphasize extreme distance
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
local function genScreenStars(sw, sh, count)
  local stars = {}
  for i = 1, count do
    stars[i] = { x = math.random() * sw, y = math.random() * sh, s = 0.28 + math.random() * 0.36 }
  end
  return stars
end

-- Enhanced sci-fi nebula canvas with better visibility
function World.buildNebulaCanvas(w, h, seed)
  if not love.graphics.newCanvas then return nil end
  local canvas = love.graphics.newCanvas(w, h)
  local oldCanvas = love.graphics.getCanvas()
  love.graphics.push('all')
  love.graphics.setCanvas(canvas)
  love.graphics.clear(0, 0, 0, 0)
  love.graphics.setBlendMode('alpha', 'alphamultiply')
  math.randomseed(seed or os.time())
  
  -- Sci-fi themed color palettes - blues, teals, purples
  local palettes = {
    { {0.14, 0.70, 1.00}, {0.06, 0.35, 0.60} }, -- Electric blue theme
    { {0.00, 1.00, 0.80}, {0.00, 0.50, 0.40} }, -- Cyan/teal theme  
    { {0.60, 0.30, 1.00}, {0.30, 0.15, 0.50} }, -- Purple theme
    { {0.20, 1.00, 0.60}, {0.10, 0.50, 0.30} }, -- Green theme
  }
  
  local blobs = math.floor(8 + (w*h)/(1920*1080) * 6) -- Fewer, larger nebula clouds
  for i = 1, blobs do
    local pal = palettes[1 + (i % #palettes)]
    local cx = math.random() * w
    local cy = math.random() * h
    local baseR = (math.min(w, h) * (0.20 + math.random() * 0.30)) -- Base size
    
    -- Create organic, irregular nebula clouds using multiple ellipses
    local numSubClouds = 8 + math.random(4) -- 8-12 sub-clouds per nebula
    for subCloud = 1, numSubClouds do
      local angle = (subCloud / numSubClouds) * math.pi * 2 + math.random() * 0.8
      local dist = baseR * (0.2 + math.random() * 0.6)
      local scx = cx + math.cos(angle) * dist * (0.5 + math.random() * 0.5)
      local scy = cy + math.sin(angle) * dist * (0.5 + math.random() * 0.5)
      local sr = baseR * (0.3 + math.random() * 0.4)
      
      -- Create layered irregular ellipses for organic look
      for k = 7, 1, -1 do
        local t = k / 7
        local rx = sr * t * (0.8 + math.random() * 0.6) -- Irregular width
        local ry = sr * t * (0.6 + math.random() * 0.8) -- Irregular height
        local rotation = math.random() * math.pi * 2
        local color1 = pal[1]
        local color2 = pal[2]
        local cr = color1[1] * t + color2[1] * (1 - t)
        local cg = color1[2] * t + color2[2] * (1 - t)
        local cb = color1[3] * t + color2[3] * (1 - t)
        local a = 0.018 * t * (0.4 + 0.3 * math.sin(subCloud * 1.7))
        love.graphics.setColor(cr, cg, cb, a)
        
        -- Draw irregular ellipse
        love.graphics.push()
        love.graphics.translate(scx, scy)
        love.graphics.rotate(rotation)
        love.graphics.ellipse('fill', 0, 0, rx, ry)
        love.graphics.pop()
      end
    end
    
    -- Add flowing wisps and streamers for more realistic nebula structure
    local numWisps = 4 + math.random(3) -- 4-6 wisps per nebula
    for wisp = 1, numWisps do
      local startAngle = math.random() * math.pi * 2
      local wispLength = baseR * (1.2 + math.random() * 0.8)
      local segments = 12 + math.random(8) -- 12-20 segments per wisp
      
      for seg = 1, segments do
        local t = seg / segments
        local curve = math.sin(t * math.pi * 2 + wisp) * baseR * 0.15 -- Wavy curve
        local dist = t * wispLength
        local wx = cx + math.cos(startAngle) * dist + math.cos(startAngle + math.pi/2) * curve
        local wy = cy + math.sin(startAngle) * dist + math.sin(startAngle + math.pi/2) * curve
        local wr = baseR * (0.08 + 0.12 * (1 - t)) -- Tapers toward end
        
        -- Layered wisp segments
        for k = 4, 1, -1 do
          local kt = k / 4
          local rr = wr * kt
          local intensity = (1 - t) * kt -- Fade toward wisp end
          local color1 = pal[1]
          local color2 = pal[2]
          local cr = color1[1] * intensity + color2[1] * (1 - intensity)
          local cg = color1[2] * intensity + color2[2] * (1 - intensity)
          local cb = color1[3] * intensity + color2[3] * (1 - intensity)
          local a = 0.012 * kt * (1 - t * 0.7)
          love.graphics.setColor(cr, cg, cb, a)
          love.graphics.circle('fill', wx, wy, rr)
        end
      end
    end
  end
  love.graphics.setCanvas(oldCanvas)
  love.graphics.pop()
  return canvas
end


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
  -- No planets - removed completely
  self.planets = {}
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
function World:setQuadtree(quadtree)
    self.quadtree = quadtree
end

function World:shouldUpdateBackground(frequency)
    frequency = frequency or 5 -- Update every 5 frames by default
    self.backgroundUpdateCounter = (self.backgroundUpdateCounter + 1) % frequency
    return self.backgroundUpdateCounter == 0
end

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
    return entity
end

function World:removeEntity(entity)
    if entity and entity.id then
        self.entities[entity.id] = nil
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
    self.nebulaCanvas = World.buildNebulaCanvas(w, h, 12345)
end

function World:update(dt)
    -- Update timed lifetimes and clean up dead entities
    for id, entity in pairs(self.entities) do
        if entity.components and entity.components.timed_life then
            local tl = entity.components.timed_life
            if tl.timer and tl.timer > 0 then
                tl.timer = tl.timer - dt
                if tl.timer <= 0 then
                    entity.dead = true
                end
            end
        end
        
        -- Update max range for projectiles
        if entity.components and entity.components.max_range and entity.components.position then
            local mr = entity.components.max_range
            local pos = entity.components.position
            
            -- Calculate distance traveled
            local dx = pos.x - mr.startX
            local dy = pos.y - mr.startY
            local distTraveled = math.sqrt(dx * dx + dy * dy)
            mr.traveledDistance = distTraveled
            
            -- Check if max range exceeded
            if distTraveled >= mr.maxDistance then
                if mr.kind == 'missile' or mr.kind == 'rocket' then
                    -- Explode missiles/rockets at max range
                    if entity.components.damage then
                        -- Create explosion effect at current position
                        local Effects = require("src.systems.effects")
                        if Effects and Effects.createExplosion then
                            Effects.createExplosion(pos.x, pos.y, entity.components.damage.value * 0.8, false)
                        end
                    end
                end
                -- Mark for removal (both bullets and missiles)
                entity.dead = true
            end
        end
    end
    -- Clean up dead entities
    for id, entity in pairs(self.entities) do
        if entity.dead then
            self:removeEntity(entity)
        end
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
  love.graphics.clear(2/255, 3/255, 6/255)
  local w, h = Viewport.getDimensions()

  -- Cache nebula canvas - only rebuild on actual resolution change
  if (not self.nebulaCanvas) or self.nebulaW ~= w or self.nebulaH ~= h then
    self.nebulaW, self.nebulaH = w, h
    self.nebulaCanvas = World.buildNebulaCanvas(w, h, 12345)
  end
  if self.nebulaCanvas then
    love.graphics.setColor(1,1,1,0.9)
    love.graphics.draw(self.nebulaCanvas, 0, 0)
  end
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
    local alpha
    if shouldUpdateTwinkle then
      -- Calculate new alpha and cache it
      alpha = s.a + 0.05 * math.sin(t * s.tw + s.ph)
      s._cachedAlpha = alpha -- Cache for next frames
    else
      -- Use cached alpha
      alpha = s._cachedAlpha or s.a
    end
    love.graphics.setColor(1, 1, 1, math.max(0, alpha))
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
  -- Planets removed - clean space background only
  love.graphics.pop()
end

function World:drawBounds()
  love.graphics.setColor(0.2, 0.4, 0.8, 0.2)
  love.graphics.rectangle("line", 0, 0, self.width, self.height)
end

return World
