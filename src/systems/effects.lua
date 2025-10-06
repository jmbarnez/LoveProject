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

  table.insert(impacts, {
    kind = kind,
    cx = cx, cy = cy, r = r,
    x = hx, y = hy, angle = angle,
    entity = entity, -- Store reference to entity for movement tracking
    t = 0, life = life,
    span = math.rad(spanDeg),
    shield = { colors = shieldColors },
    hull = hullColors,
  })
  
  -- Trigger sound effect for impact (positional) - skip if disabled
  if not disableSound then
    if kind == 'shield' then
      -- Use a distinct static sound when the source is a collision (entity bounce),
      -- keep normal shield impact for projectiles.
      if bulletKind == 'collision' then
        Sound.triggerEventAt('shield_bounce', hx, hy)
      else
        Sound.triggerEventAt('impact_shield', hx, hy)
      end
    else
      Sound.triggerEventAt('impact_hull', hx, hy)
    end
  end

  if kind == 'hull' then
    local n = 6 + math.random(4)
    for i=1,n do
      local a = angle + (math.random()*2-1) * math.pi*0.35
      local s = 180 + math.random()*120
      Effects.add({ type='spark', x=hx, y=hy, vx=math.cos(a)*s, vy=math.sin(a)*s, t=0, life=0.25+math.random()*0.25,
        color = {1.0,0.85,0.2,0.9}, size = 1.6 })
    end
    Effects.add({ type='ring', x=hx, y=hy, r0=2, r1=24, w0=3, w1=1, t=0, life=0.25, color={1,0.5,0.1,0.45} })
    if bulletKind == 'laser' then
      Effects.add({ type='ring', x=hx, y=hy, r0=1, r1=18, w0=2, w1=1, t=0, life=0.2, color={0.6,0.9,1.0,0.6} })
    elseif bulletKind == 'missile' then
      for i=1,6 do
        local a = angle + (math.random()*2-1) * math.pi
        local s = 120 + math.random()*180
        Effects.add({ type='spark', x=hx, y=hy, vx=math.cos(a)*s, vy=math.sin(a)*s, t=0, life=0.3+math.random()*0.25,
          color={1.0,0.7,0.3,0.9}, size=2 })
      end
      Effects.add({ type='smoke', x=hx, y=hy, r0=10, rg=70, t=0, life=0.9, color={0.35,0.35,0.35,0.35} })
    end
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
    if p.t >= p.life then table.remove(impacts, i) end
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
        f.vx = (f.vx or 0) * 0.90
        f.vy = (f.vy or 0) * 0.90 + 18 * dt
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
        local sc = p.hull.spark
        local rc = p.hull.ring
        love.graphics.setColor(sc[1], sc[2], sc[3], (sc[4] or 0.6) * a)
        love.graphics.circle('fill', p.x, p.y, 3)
        love.graphics.setColor(rc[1], rc[2], rc[3], (rc[4] or 0.4) * a)
        love.graphics.circle('line', p.x, p.y, 6)
      end
    end
  end
  -- Draw FX particles
  for i = #fx, 1, -1 do
    local f = fx[i]
    local a = 1 - (f.t / f.life)
    if a <= 0 then table.remove(fx, i) else
      if f.type == 'spark' then
        love.graphics.setColor(f.color[1], f.color[2], f.color[3], (f.color[4] or 1) * a)
        love.graphics.circle('fill', f.x, f.y, f.size or 2)
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
