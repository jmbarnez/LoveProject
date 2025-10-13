local Util = require("src.core.util")
local Sound = require("src.core.sound")
local Theme = require("src.core.theme")
local ShieldImpactEffects = require("src.systems.render.shield_impact_effects")

local Effects = {}

-- Internal containers
local fx = {}
local impacts = {}

-- Public accessors (if other systems need to inspect)
function Effects.getFx()
  return fx
end

function Effects.getImpacts()
  return impacts
end

-- Add a generic FX particle
function Effects.add(part)
  table.insert(fx, part)
end

-- Spawn dynamic spark effects for laser/beam impacts on hard surfaces
function Effects.spawnLaserSparks(x, y, angle, color)
  color = color or {1.0, 0.8, 0.3, 0.8}
  
  -- Calculate the surface normal (perpendicular to the impact angle)
  local normalX = math.cos(angle)
  local normalY = math.sin(angle)
  
  -- Create a cone-shaped spray pattern
  local coneAngle = math.pi * 0.4 -- 72 degree cone (36 degrees each side of normal)
  local sparkCount = 8 + math.random(6) -- 8-13 sparks for more visible effect
  
  -- Main sparks - spray in a cone pattern from the impact point
  for i = 1, sparkCount do
    -- Create cone distribution - more sparks in center, fewer at edges
    local coneOffset = (math.random() * 2 - 1) * coneAngle
    local sparkAngle = angle + coneOffset
    
    -- Speed varies based on distance from center of cone
    local centerFactor = 1 - (math.abs(coneOffset) / coneAngle)
    local speed = 60 + math.random() * 80 + centerFactor * 40 -- Faster sparks in center
    
    -- Life varies with speed - faster sparks live longer
    local life = 0.2 + math.random() * 0.3 + (speed / 200) * 0.2
    
    -- Size varies with speed - faster sparks are smaller
    local size = 1.0 + math.random() * 0.6 - (speed / 300) * 0.4
    
    Effects.add({
      type = 'spark',
      x = x,
      y = y,
      vx = math.cos(sparkAngle) * speed,
      vy = math.sin(sparkAngle) * speed,
      t = 0,
      life = life,
      color = color,
      size = math.max(0.3, size),
    })
  end
  
  -- Secondary sparks - smaller, faster, more scattered
  for i = 1, 6 do
    local coneOffset = (math.random() * 2 - 1) * coneAngle * 1.2 -- Wider cone
    local sparkAngle = angle + coneOffset
    local speed = 100 + math.random() * 120
    local life = 0.15 + math.random() * 0.15
    local size = 0.6 + math.random() * 0.4
    
    Effects.add({
      type = 'spark',
      x = x,
      y = y,
      vx = math.cos(sparkAngle) * speed,
      vy = math.sin(sparkAngle) * speed,
      t = 0,
      life = life,
      color = {color[1], color[2], color[3], color[4] * 0.7},
      size = size,
    })
  end
  
  -- Micro sparks - tiny, very fast, for detail and realism
  for i = 1, 8 do
    local coneOffset = (math.random() * 2 - 1) * coneAngle * 1.5 -- Even wider cone
    local sparkAngle = angle + coneOffset
    local speed = 150 + math.random() * 100
    local life = 0.08 + math.random() * 0.08
    local size = 0.2 + math.random() * 0.3
    
    Effects.add({
      type = 'spark',
      x = x,
      y = y,
      vx = math.cos(sparkAngle) * speed,
      vy = math.sin(sparkAngle) * speed,
      t = 0,
      life = life,
      color = {color[1], color[2], color[3], color[4] * 0.5},
      size = size,
    })
  end
end

-- Spawn healing particles for healing laser effects
function Effects.spawnHealingParticles(x, y)
  local color = {0.3, 0.95, 0.6, 0.55} -- Soft lime green
  
  -- Create gentle upward floating particles
  local particleCount = 2 + math.random(2) -- 2-4 particles
  
  for i = 1, particleCount do
    local angle = (math.random() * 2 - 1) * math.pi * 0.25 -- Gentle spread
    local speed = 12 + math.random() * 18 -- Slow, gentle movement
    local life = 0.7 + math.random() * 0.3 -- Slight variation
    local size = 0.9 + math.random() * 0.5
    
    Effects.add({
      type = 'healing_particle',
      x = x + (math.random() * 2 - 1) * 4, -- Smaller offset
      y = y + (math.random() * 2 - 1) * 4,
      vx = math.cos(angle) * speed,
      vy = math.sin(angle) * speed - 8, -- Slight upward bias
      t = 0,
      life = life,
      color = color,
      size = size,
    })
  end
  
  -- Add subtle sparkle accents
  local sparkleCount = 1 + math.random(2)
  for i = 1, sparkleCount do
    local angle = math.random() * 2 * math.pi
    local speed = 10 + math.random() * 12
    local life = 0.35 + math.random() * 0.2
    local size = 0.6 + math.random() * 0.3
    
    Effects.add({
      type = 'healing_sparkle',
      x = x,
      y = y,
      vx = math.cos(angle) * speed,
      vy = math.sin(angle) * speed,
      t = 0,
      life = life,
      color = {0.9, 1.0, 0.9, 0.7}, -- Soft white-green sparkles
      size = size,
    })
  end
end

-- Spawn healing circle around target
function Effects.spawnHealingCircle(x, y, radius)
  radius = radius or 30
  
  Effects.add({
    type = 'healing_circle',
    x = x,
    y = y,
    radius = radius,
    t = 0,
    life = 0.5, -- Slightly longer duration for persistence
    color = {0.1, 0.8, 0.3, 0.2}, -- Very faint green circle
    pulseSpeed = 0, -- No pulsing for subtlety
  })
end

-- Spawn floating healing number
function Effects.spawnHealingNumber(x, y, amount)
  local color = {0.2, 0.9, 0.4, 0.7} -- Subtle green
  
  Effects.add({
    type = 'healing_number',
    x = x,
    y = y,
    vx = (math.random() - 0.5) * 10, -- Less horizontal drift
    vy = -20 - math.random() * 10, -- Slower upward movement
    t = 0,
    life = 0.8, -- Shorter duration for subtlety
    color = color,
    text = string.format("+%.0f", amount), -- No decimal places for cleaner look
    size = 0.7, -- Smaller text
  })
end

-- Spawn bullet impact effects for projectiles hitting hull surfaces
function Effects.spawnBulletImpact(x, y, angle, bulletType, color)
  color = color or {0.8, 0.8, 0.8, 0.9}
  
  -- Create impact flash
  Effects.add({
    type = 'ring',
    x = x,
    y = y,
    r0 = 2,
    r1 = 12,
    w0 = 3,
    w1 = 1,
    t = 0,
    life = 0.15,
    color = {color[1], color[2], color[3], 0.6}
  })
  
  -- Create sparks based on bullet type
  local sparkCount = 3
  local sparkSize = 1.0
  local sparkSpeed = 60
  
  if bulletType == "cannon" then
    sparkCount = 4
    sparkSize = 1.2
    sparkSpeed = 80
  elseif bulletType == "railgun" then
    sparkCount = 6
    sparkSize = 0.8
    sparkSpeed = 120
  elseif bulletType == "missile" then
    sparkCount = 8
    sparkSize = 1.5
    sparkSpeed = 100
  end
  
  -- Main impact sparks
  for i = 1, sparkCount do
    local spread = (math.random() * 2 - 1) * 0.6
    local sparkAngle = angle + math.pi + spread
    local speed = sparkSpeed + math.random() * 40
    
    Effects.add({
      type = 'spark',
      x = x,
      y = y,
      vx = math.cos(sparkAngle) * speed,
      vy = math.sin(sparkAngle) * speed,
      t = 0,
      life = 0.2 + math.random() * 0.1,
      color = color,
      size = sparkSize + math.random() * 0.4,
    })
  end
  
  -- Add some debris particles for larger impacts
  if bulletType == "missile" or bulletType == "cannon" then
    for i = 1, 3 do
      local spread = (math.random() * 2 - 1) * 1.0
      local sparkAngle = angle + math.pi + spread
      local speed = 40 + math.random() * 30
      
      Effects.add({
        type = 'spark',
        x = x,
        y = y,
        vx = math.cos(sparkAngle) * speed,
        vy = math.sin(sparkAngle) * speed,
        t = 0,
        life = 0.3 + math.random() * 0.2,
        color = {color[1] * 0.7, color[2] * 0.7, color[3] * 0.7, 0.6},
        size = 0.6 + math.random() * 0.3,
      })
    end
  end
end

-- Spawn a detonation visual burst
function Effects.spawnDetonation(x, y, kind, color)
  -- Play explosion sound
  if kind == "asteroid" then
    Sound.triggerEventAt('asteroid_shatter', x, y)
  else
    Sound.triggerEventAt('ship_explosion', x, y)
  end
  
  
  Effects.add({ type = 'ring', x = x, y = y, r0 = 6, r1 = 90, w0 = 6, w1 = 1, t = 0, life = 0.45,
    color = color or {1.0, 0.7, 0.3, 0.5} })
  for i=1,6 do
    local a = math.random() * math.pi * 2
    local r = 8 + math.random()*14
    Effects.add({ type = 'smoke', x = x + math.cos(a)*r, y = y + math.sin(a)*r, r0 = 6, rg = 56 + math.random()*26,
      t = 0, life = 0.8 + math.random()*0.4, color = {0.4,0.4,0.4,0.35} })
  end
  for i=1,10 do
    local a = math.random() * math.pi * 2
    local s = 160 + math.random()*140
    Effects.add({ type = 'spark', x = x, y = y, vx = math.cos(a)*s, vy = math.sin(a)*s, t = 0,
      life = 0.35 + math.random()*0.25, color = {1.0,0.7,0.25,0.9}, size = 2 })
  end
end

-- Sonic-style explosion: large shock rings + sparks + smoke
function Effects.spawnSonicBoom(x, y, opts)
  opts = opts or {}
  local baseColor = opts.color or {1.0, 0.85, 0.4, 0.6}
  local ringCount = opts.rings or 1
  local sizeScale = opts.sizeScale or 1.0
  local rStart = (opts.rStart or 8) * sizeScale
  local rStep = (opts.rStep or 45) * sizeScale
  local life = opts.life or 0.6
  for i=1, ringCount do
    local r0 = rStart + (i-1) * rStep
    local r1 = r0 + (opts.rSpan or 80) * sizeScale
    local w0 = 6 - (i-1)
    local w1 = 1
    Effects.add({ type='ring', x=x, y=y, r0=r0, r1=r1, w0=w0, w1=w1, t=0, life=life + (i-1)*0.12, color=baseColor })
  end
  -- Simple smoke swell
  local smokeLife = life * 1.5
  local smokeSize = rStart * 1.5
  Effects.add({ type='smoke', x=x, y=y, vx=0, vy=0, t=0, life=smokeLife, color={0.4,0.3,0.2,0.7}, size=smokeSize })
end

-- Compatibility wrapper: createExplosion expected by some callers
-- Routes to our current sonic-boom style explosion with enhanced defaults for ship destruction.
function Effects.createExplosion(x, y, power, spawnDebris)
  local sizeScale = math.max(0.6, math.min(2.5, (power or 1) / 10))
  Effects.spawnSonicBoom(x, y, {
    rings = 1,  -- Simple single ring
    sizeScale = sizeScale,
    rStart = 10 * sizeScale,  -- Standard start size
    rSpan = 80 * sizeScale,   -- Standard ring width
    life = 0.8 + 0.1 * sizeScale,  -- Standard lifetime
    color = {1.0, 0.6, 0.2, 0.7},  -- Orange/red for ship destruction
  })
end

-- Spawn an impact (shield or hull) and optional bulletKind-specific flair
function Effects.spawnImpact(kind, cx, cy, r, hx, hy, angle, style, bulletKind, entity, disableSound)
  local life = (kind == 'shield' and 0.45) or 0.22
  local spanDeg = 60
  local shieldColors = {
    {0.26, 0.62, 1.0, 0.55},
    {0.50, 0.80, 1.0, 0.35},
  }
  if style and style.shield then
    spanDeg = style.shield.spanDeg or spanDeg
    if style.shield.color1 then shieldColors[1] = style.shield.color1 end
    if style.shield.color2 then shieldColors[2] = style.shield.color2 end
  end
  local hullColors = {
    spark = {1.0, 0.6, 0.1, 0.6},
    ring  = {1.0, 0.3, 0.0, 0.4},
  }
  if style and style.hull then
    hullColors.spark = style.hull.spark or hullColors.spark
    hullColors.ring  = style.hull.ring  or hullColors.ring
  end
  -- Deduplicate: if a very recent, same-kind impact exists at approximately the same
  -- hit point for the same entity, skip creating another one to avoid visual doubles
  for i = #impacts, 1, -1 do
    local p = impacts[i]
    if p and p.entity == entity and p.kind == kind and p.t and p.t < 0.25 then
      local dx = (p.x or 0) - (hx or 0)
      local dy = (p.y or 0) - (hy or 0)
      if (dx*dx + dy*dy) <= (16 * 16) then
        return
      end
    end
  end

  local hullStyle = 'default'
  -- Disable pulsing effects for laser weapons - they now use spark effects instead
  if kind == 'hull' and bulletKind then
    if bulletKind == 'laser' or bulletKind == 'mining_laser' or bulletKind == 'salvaging_laser' or bulletKind == 'healing_laser' then
      hullStyle = 'none' -- No pulsing effects for lasers
    end
  end

  table.insert(impacts, {
    kind = kind,
    cx = cx, cy = cy, r = r,
    x = hx, y = hy, angle = angle,
    entity = entity, -- Store reference to entity for movement tracking
    t = 0, life = life,
    span = math.rad(spanDeg),
    shield = { colors = shieldColors },
    hull = hullColors,
    hullStyle = hullStyle,
    sparkAccum = 0,
  })
  
  -- Trigger sound effect for impact (positional) - skip if disabled
  if not disableSound then
    if kind == 'shield' then
      -- Use a distinct static sound when the source is a collision (entity bounce),
      -- keep normal shield impact for projectiles.
      if bulletKind == 'collision' then
        Sound.triggerEventAt('shield_bounce', hx, hy)
      else
        -- Use damage-based shield sounds
        local damage = (damage and (damage.value or damage)) or 1
        if damage >= 20 then
          Sound.triggerEventAt('impact_shield_heavy', hx, hy)
        else
          Sound.triggerEventAt('impact_shield_light', hx, hy)
        end
      end
    else
      -- Use damage-based hull sounds
      local damage = (damage and (damage.value or damage)) or 1
      if damage >= 30 then
        Sound.triggerEventAt('impact_hull_critical', hx, hy)
      elseif damage >= 15 then
        Sound.triggerEventAt('impact_hull_heavy', hx, hy)
      else
        Sound.triggerEventAt('impact_hull_light', hx, hy)
      end
    end
  end

  if kind == 'hull' then
    -- Simple hull impact - no additional effects
  else -- shield
    -- Create enhanced shield impact animation at precise hit point (with entity reference for tracking)
    local ripple = nil
    if bulletKind ~= 'collision' and ShieldImpactEffects and ShieldImpactEffects.createImpact then
      -- protect against errors in ripple creation
      local ok, res = pcall(function()
        return ShieldImpactEffects.createImpact(hx, hy, cx, cy, r, angle, bulletKind, entity)
      end)
      if ok then ripple = res end
    end

    -- If this was a direct collision (entity bounce) or ripple couldn't be created, use a smaller, local FX
    if not ripple then
      -- Smaller ring to indicate a collision impact without filling the shield bubble
      Effects.add({ type='ring', x=hx, y=hy, r0=4, r1=22, w0=3, w1=1, t=0, life=0.22, color={0.6,0.95,1.0,0.75} })
      -- Add a few small sparks for visibility
      for i=1,4 do
        local a = angle + (math.random()*2-1) * math.pi*0.6
        local s = 80 + math.random()*60
        Effects.add({ type='spark', x=hx, y=hy, vx=math.cos(a)*s, vy=math.sin(a)*s, t=0, life=0.12+math.random()*0.08,
          color = {0.45,0.85,1.0,0.85}, size = 1.0 })
      end
    else
        -- No traditional effects; rely on ripple for subtlety
    end
  end
end

function Effects.spawnExtractionFlash(x, y, radius)
  Effects.add({
    type = 'ring',
    x = x,
    y = y,
    r0 = radius,
    r1 = radius + 15,
    w0 = 8,
    w1 = 1,
    t = 0,
    life = 0.1,
    color = {0.6, 1.0, 1.0, 1.0} -- Bright cyan, #99FFFF
  })
end

function Effects.spawnExtractionParticles(x, y, radius)
  for i = 1, 40 do
    local angle = math.random() * math.pi * 2
    local speed = 100 + math.random() * 50
    Effects.add({
      type = 'spark',
      x = x + math.cos(angle) * radius,
      y = y + math.sin(angle) * radius,
      vx = math.cos(angle) * speed,
      vy = math.sin(angle) * speed,
      t = 0,
      life = 0.2 + math.random() * 0.1,
      color = {0.0, 1.0, 1.0, 1.0}, -- Luminous cyan, #00FFFF
      size = 2
    })
  end
end

function Effects.update(dt)
  -- Update enhanced shield impact effects
  ShieldImpactEffects.update(dt)
  
  -- Update impacts lifetimes
  for i = #impacts, 1, -1 do
    local p = impacts[i]
    p.t = p.t + dt
    if p.t >= p.life then
      table.remove(impacts, i)
    else
      if p.kind == 'hull' and p.hullStyle == 'laser' then
        local spawnInterval = 0.035
        p.sparkAccum = (p.sparkAccum or 0) + dt
        while p.sparkAccum >= spawnInterval do
          p.sparkAccum = p.sparkAccum - spawnInterval
          local spread = (math.random() * 2 - 1) * 0.45
          local baseAngle = (p.angle or 0)
          local sparkAngle = baseAngle + math.pi + spread
          local speed = 70 + math.random() * 50
          Effects.add({
            type = 'spark',
            x = p.x,
            y = p.y,
            vx = math.cos(sparkAngle) * speed,
            vy = math.sin(sparkAngle) * speed,
            t = 0,
            life = 0.18 + math.random() * 0.12,
            color = {1.0, 0.7, 0.25, 0.85},
            size = 1.4,
          })
        end
      elseif p.kind == 'hull' and p.hullStyle == 'none' then
        -- No pulsing effects for laser weapons - they use spark effects instead
        -- Do nothing
      end
    end
  end
  -- Update FX particles
  for i = #fx, 1, -1 do
    local f = fx[i]
    f.t = f.t + dt
    if f.t >= f.life then
      table.remove(fx, i)
    else
      if f.type == 'spark' then
        f.x = f.x + (f.vx or 0) * dt
        f.y = f.y + (f.vy or 0) * dt
        -- More realistic spark physics with air resistance and gravity
        f.vx = (f.vx or 0) * 0.85 -- Air resistance
        f.vy = (f.vy or 0) * 0.85 + 25 * dt -- Gravity effect
        -- Add some random turbulence for more realistic movement
        f.vx = f.vx + (math.random() * 2 - 1) * 5 * dt
        f.vy = f.vy + (math.random() * 2 - 1) * 5 * dt
      elseif f.type == 'smoke' then
        f.y = f.y - 8 * dt
      end
    end
  end
end

function Effects.draw()
  -- Shield impact effects are now drawn by the render system with proper transforms

  -- Draw impacts
  for k = #impacts, 1, -1 do
    local p = impacts[k]
    local a = 1 - (p.t / p.life)
    if a <= 0 then table.remove(impacts, k) else
      if p.kind == 'shield' then
        -- Shield impact: enhanced lighting at impact point and circumference effect
        local impactProgress = p.t / p.life
        -- Use the actual shield radius passed from the impact spawn (already calculated correctly)
        local perimeterRadius = p.r
        
        -- Get current entity position for shield movement tracking
        local currentCx, currentCy = p.cx, p.cy
        if p.entity and p.entity.components and p.entity.components.position then
            currentCx = p.entity.components.position.x
            currentCy = p.entity.components.position.y
        end
        
        -- Soft fill pulse across entire shield
        love.graphics.setColor(0.2, 0.8, 1.0, 0.15 * a)
        love.graphics.circle('fill', currentCx, currentCy, perimeterRadius)
        
        -- Calculate impact position relative to current entity center
        local offsetX = p.x - p.cx
        local offsetY = p.y - p.cy
        local currentImpactX = currentCx + offsetX
        local currentImpactY = currentCy + offsetY
        
        -- Bright impact lighting at current hit point
        local impactSize = 12 * (1 - impactProgress * 0.7) -- Fades but stays visible
        love.graphics.setColor(0.9, 1.0, 1.0, 0.9 * a)
        love.graphics.circle('fill', currentImpactX, currentImpactY, impactSize)
        love.graphics.setColor(0.6, 0.9, 1.0, 0.6 * a)
        love.graphics.circle('fill', currentImpactX, currentImpactY, impactSize * 1.5)
        love.graphics.setColor(0.3, 0.7, 1.0, 0.3 * a)
        love.graphics.circle('fill', currentImpactX, currentImpactY, impactSize * 2.2)
        
        -- Calculate impact angle for circumference lighting (using current positions)
        local impactAngle = math.atan2(currentImpactY - currentCy, currentImpactX - currentCx)
        
        -- Halfway-around circumference arc lighting (180 degree arc from impact point)
        local arcSpan = math.pi -- 180 degrees
        local startAngle = impactAngle - arcSpan * 0.5
        local endAngle = impactAngle + arcSpan * 0.5
        
        -- Multiple arc layers for enhanced visibility
        love.graphics.setLineWidth(4)
        love.graphics.setColor(0.8, 0.95, 1.0, 0.7 * a)
        love.graphics.arc('line', 'open', currentCx, currentCy, perimeterRadius, startAngle, endAngle, 32)
        
        love.graphics.setLineWidth(6)
        love.graphics.setColor(0.5, 0.8, 1.0, 0.4 * a)
        love.graphics.arc('line', 'open', currentCx, currentCy, perimeterRadius + 2, startAngle, endAngle, 32)
        
        love.graphics.setLineWidth(2)
        love.graphics.setColor(0.3, 0.6, 1.0, 0.5 * a)
        love.graphics.arc('line', 'open', currentCx, currentCy, perimeterRadius + 6, startAngle, endAngle, 32)
        
        -- Energy dispersion sparks along the lit arc
        local numSparks = 8
        for i = 1, numSparks do
          local sparkAngle = startAngle + (endAngle - startAngle) * (i / numSparks)
          local sparkX = currentCx + math.cos(sparkAngle) * perimeterRadius
          local sparkY = currentCy + math.sin(sparkAngle) * perimeterRadius
          local sparkAlpha = 0.6 * a * (1 - math.abs(i - numSparks * 0.5) / (numSparks * 0.5)) -- Brighter at center
          love.graphics.setColor(0.7, 0.9, 1.0, sparkAlpha)
          love.graphics.circle('fill', sparkX, sparkY, 2 + math.sin(love.timer.getTime() * 8 + i) * 0.5)
        end
        
        -- Dispersed ripple waves from current impact point
        local waveRadius = impactProgress * perimeterRadius * 0.8
        for i = 1, 2 do
          local waveDelay = (i - 1) * 0.4
          local waveAlpha = math.max(0, math.min(1, (impactProgress - waveDelay) / (1 - waveDelay)))
          if waveAlpha > 0 then
            local currentRadius = waveAlpha * waveRadius
            love.graphics.setLineWidth(3 - i * 0.8)
            love.graphics.setColor(0.6, 0.9, 1.0, (0.5 - i * 0.2) * a * (1 - waveAlpha))
            love.graphics.circle('line', currentImpactX, currentImpactY, currentRadius)
          end
        end
        
        love.graphics.setLineWidth(1)
      else
        if p.hullStyle == 'laser' then
          -- Continuous laser impact: tight molten glow with directional streaks
          local time = love.timer.getTime()
          local pulse = 1 + 0.25 * math.sin(time * 18 + p.t * 16)
          local emberRadius = 3.2 * pulse
          love.graphics.setColor(1.0, 0.62, 0.18, 0.8 * a)
          love.graphics.circle('fill', p.x, p.y, emberRadius)
          love.graphics.setColor(1.0, 0.45, 0.1, 0.4 * a)
          love.graphics.circle('fill', p.x, p.y, emberRadius * 1.9)

          -- Draw subtle streaks in the direction opposite the incoming beam
          local baseAngle = (p.angle or 0) + math.pi
          local streakLength = 12
          love.graphics.setLineWidth(1.6)
          for s = -1, 1 do
            local streakAngle = baseAngle + s * 0.28 + math.sin(time * 7 + s) * 0.08
            love.graphics.setColor(1.0, 0.75, 0.3, 0.55 * a)
            love.graphics.line(
              p.x,
              p.y,
              p.x + math.cos(streakAngle) * streakLength,
              p.y + math.sin(streakAngle) * streakLength
            )
          end
          love.graphics.setLineWidth(1)
        elseif p.hullStyle == 'none' then
          -- No visual effects for laser weapons - they use spark effects instead
          -- Do nothing
        else
          -- Simple hull impact effect - just a circle (larger)
          local sc = p.hull.spark
          local rc = p.hull.ring
          love.graphics.setColor(sc[1], sc[2], sc[3], (sc[4] or 0.6) * a)
          love.graphics.circle('fill', p.x, p.y, 5)
          love.graphics.setColor(rc[1], rc[2], rc[3], (rc[4] or 0.4) * a)
          love.graphics.circle('line', p.x, p.y, 10)
        end
      end
    end
  end
  -- Draw FX particles
  for i = #fx, 1, -1 do
    local f = fx[i]
    local a = 1 - (f.t / f.life)
    if a <= 0 then table.remove(fx, i) else
      if f.type == 'spark' then
        -- Thin spark rendering - use lines instead of circles
        local alpha = (f.color[4] or 1) * a
        local size = f.size or 2
        
        -- Calculate spark direction from velocity
        local vx, vy = f.vx or 0, f.vy or 0
        local length = math.sqrt(vx * vx + vy * vy)
        if length > 0 then
          -- Normalize velocity to get direction
          vx, vy = vx / length, vy / length
          
          -- Draw thin spark line
          love.graphics.setColor(f.color[1], f.color[2], f.color[3], alpha)
          love.graphics.setLineWidth(1)
          love.graphics.line(
            f.x - vx * size * 0.5,
            f.y - vy * size * 0.5,
            f.x + vx * size * 0.5,
            f.y + vy * size * 0.5
          )
          
          -- Draw small bright center dot
          love.graphics.setColor(1, 1, 1, alpha * 0.9)
          love.graphics.circle('fill', f.x, f.y, 0.5)
        else
          -- Fallback: small dot if no velocity
          love.graphics.setColor(f.color[1], f.color[2], f.color[3], alpha)
          love.graphics.circle('fill', f.x, f.y, 0.5)
        end
      elseif f.type == 'healing_particle' then
        -- Gentle healing particle rendering - soft circles with glow
        local alpha = (f.color[4] or 1) * a
        local size = f.size or 2
        
        -- Draw soft glow effect
        love.graphics.setColor(f.color[1], f.color[2], f.color[3], alpha * 0.3)
        love.graphics.circle('fill', f.x, f.y, size * 1.5)
        
        -- Draw main particle
        love.graphics.setColor(f.color[1], f.color[2], f.color[3], alpha)
        love.graphics.circle('fill', f.x, f.y, size)
        
        -- Draw bright center
        love.graphics.setColor(1, 1, 1, alpha * 0.8)
        love.graphics.circle('fill', f.x, f.y, size * 0.3)
      elseif f.type == 'healing_sparkle' then
        -- Healing sparkle rendering - small bright dots
        local alpha = (f.color[4] or 1) * a
        local size = f.size or 1
        
        love.graphics.setColor(f.color[1], f.color[2], f.color[3], alpha)
        love.graphics.circle('fill', f.x, f.y, size)
      elseif f.type == 'healing_circle' then
        -- Healing circle around target - subtle green circle
        local alpha = (f.color[4] or 1) * a
        local radius = f.radius or 30
        
        love.graphics.setColor(f.color[1], f.color[2], f.color[3], alpha)
        love.graphics.setLineWidth(1) -- Thinner line for subtlety
        love.graphics.circle('line', f.x, f.y, radius)
        love.graphics.setLineWidth(1)
      elseif f.type == 'healing_number' then
        -- Floating healing number - subtle green text that fades upward
        local alpha = (f.color[4] or 1) * a
        local text = f.text or "+0"
        local size = f.size or 0.7
        
        love.graphics.setColor(f.color[1], f.color[2], f.color[3], alpha)
        local oldFont = love.graphics.getFont()
        -- Use a smaller font for subtlety
        if Theme.fonts and Theme.fonts.small then 
          love.graphics.setFont(Theme.fonts.small) 
        end
        love.graphics.print(text, f.x, f.y, 0, size, size)
        if oldFont then love.graphics.setFont(oldFont) end
      elseif f.type == 'ring' then
        local rr = Util.lerp(f.r0 or 2, f.r1 or 24, f.t / f.life)
        local lw = Util.lerp(f.w0 or 2, f.w1 or 1, f.t / f.life)
        love.graphics.setLineWidth(lw)
        local c=f.color or {1,1,1,0.4}
        love.graphics.setColor(c[1],c[2],c[3], (c[4] or 0.4) * a)
        love.graphics.circle('line', f.x, f.y, rr)
        love.graphics.setLineWidth(1)
      elseif f.type == 'smoke' then
        local rr = Util.lerp(f.r0 or 6, (f.r0 or 6) + (f.rg or 40), f.t / f.life)
        local c=f.color or {0.4,0.4,0.4,0.4}
        love.graphics.setColor(c[1],c[2],c[3], (c[4] or 0.4) * a)
        love.graphics.circle('fill', f.x, f.y, rr)
      end
    end
  end
end

return Effects
