--[[
  Minimap UI
  
  Clean minimap implementation using shared map systems.
  Provides consistent rendering with the full map.
]]

local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
-- Discovery system removed - no fog of war
local MapEntities = require("src.systems.map_entities")
local MapRenderer = require("src.systems.map_renderer")
local Sound = require("src.core.sound")

local Minimap = {
  visible = true,
  x = 0,
  y = 0,
  w = 200,
  h = 200,
  scale = 0.02,
  followPlayer = true,
  centerX = 0,
  centerY = 0,
  showEntities = true,
  showFog = false, -- Fog of war disabled
}

local function getMinimapBounds()
  local sw, sh = Viewport.getDimensions()
  local x = sw - Minimap.w - 20
  local y = 20
  return x, y, Minimap.w, Minimap.h
end

local function getMinimapViewport(world)
  local x, y, w, h = getMinimapBounds()
  
  local centerX, centerY = Minimap.centerX, Minimap.centerY
  if Minimap.followPlayer then
    local player = require("src.core.player_ref").get()
    if player and player.components and player.components.position then
      centerX = player.components.position.x
      centerY = player.components.position.y
    end
  end

  local scale = Minimap.scale
  local ox = x + w/2 - centerX * scale
  local oy = y + h/2 - centerY * scale
  
  return {
    type = "minimap",
    x = x,
    y = y,
    w = w,
    h = h,
    ox = ox,
    oy = oy,
    sx = scale,
    sy = scale,
    centerX = centerX,
    centerY = centerY
  }
end

function Minimap.update(dt, player, world)
  if not Minimap.visible or not player then return end
  if not world then return end
  
  -- Update minimap center if following player
  if Minimap.followPlayer and player.components and player.components.position then
    Minimap.centerX = player.components.position.x
    Minimap.centerY = player.components.position.y
  end
end

function Minimap.draw(player, world, additionalEntities)
  if not Minimap.visible or not player or not world then return end
  local viewport = getMinimapViewport(world)
  
  -- Get visible entities
  local entities = MapEntities.getMinimapEntities(world, nil, additionalEntities)
  
  -- Draw the minimap
  MapRenderer.drawMinimap(player, world, entities, nil, viewport)
  
  -- Draw minimap border
  Theme.setColor(Theme.colors.border)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", viewport.x, viewport.y, viewport.w, viewport.h)
  
  -- Draw center crosshair
  Theme.setColor(Theme.colors.accent)
  love.graphics.setLineWidth(1)
  local cx, cy = viewport.x + viewport.w/2, viewport.y + viewport.h/2
  love.graphics.line(cx - 5, cy, cx + 5, cy)
  love.graphics.line(cx, cy - 5, cx, cy + 5)
  
  -- Draw speed indicator below the minimap
  if player and player.components then
    local speed = 0
    local maxSpeed = 500
    
    -- Check Windfield physics first
    if player.components.windfield_physics then
      local PhysicsSystem = require("src.systems.physics")
      local manager = PhysicsSystem.getManager()
      if manager then
        local collider = manager:getCollider(player)
        if collider then
          local vx, vy = collider:getLinearVelocity()
          speed = math.sqrt(vx * vx + vy * vy)
        end
      end
    -- Check legacy physics
    elseif player.components.physics and player.components.physics.body then
      local body = player.components.physics.body
      speed = math.sqrt((body.vx or 0)^2 + (body.vy or 0)^2)
      maxSpeed = body.maxSpeed or 500
    end
    
    local speedPct = maxSpeed > 0 and math.min(speed / maxSpeed, 1.0) or 0
    
    -- Speed indicator dimensions
    local speedBarWidth = viewport.w
    local speedBarHeight = 6
    local speedBarX = viewport.x
    local speedBarY = viewport.y + viewport.h + 4 -- 4px gap below minimap
    
    -- Speed bar background
    Theme.setColor(Theme.colors.bg1)
    love.graphics.rectangle("fill", speedBarX, speedBarY, speedBarWidth, speedBarHeight)
    
    -- Speed fill (green gradient based on speed)
    if speedPct > 0 then
      local fillWidth = speedBarWidth * speedPct
      local speedColor = {0.2, 0.8, 0.2, 1.0} -- Green for speed
      if speedPct > 0.8 then
        speedColor = {0.8, 0.8, 0.2, 1.0} -- Yellow at high speed
      elseif speedPct > 0.6 then
        speedColor = {0.6, 0.8, 0.2, 1.0} -- Yellow-green
      end
      Theme.setColor(speedColor)
      love.graphics.rectangle("fill", speedBarX, speedBarY, fillWidth, speedBarHeight)
    end
    
    -- Speed bar border
    Theme.setColor(Theme.colors.border)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", speedBarX, speedBarY, speedBarWidth, speedBarHeight)
    
    -- Speed text (optional - shows actual speed value)
    if Theme.fonts and Theme.fonts.small then
      local oldFont = love.graphics.getFont()
      love.graphics.setFont(Theme.fonts.small)
      local speedText = string.format("SPD: %.0f", speed)
      local textWidth = Theme.fonts.small:getWidth(speedText)
      local textX = speedBarX + (speedBarWidth - textWidth) / 2
      local textY = speedBarY + speedBarHeight + 2
      
      Theme.setColor(Theme.colors.text)
      love.graphics.print(speedText, textX, textY)
      
      if oldFont then love.graphics.setFont(oldFont) end
    end
  end
end

function Minimap.mousepressed(x, y, button)
  if not Minimap.visible then return false end
  
  local mx, my, mw, mh = getMinimapBounds()
  if not (x >= mx and x <= mx + mw and y >= my and y <= my + mh) then return false end
  
  if button == 1 then
    -- Toggle follow player
    Minimap.followPlayer = not Minimap.followPlayer
    Sound.playSFX("ui_click")
    return true
  elseif button == 2 then
    -- Center on clicked position
    local world = require("src.core.world")
    if world then
      local viewport = getMinimapViewport(world)
      local scale = Minimap.scale
      Minimap.centerX = (x - viewport.ox) / scale
      Minimap.centerY = (y - viewport.oy) / scale
      Minimap.followPlayer = false
      Sound.playSFX("ui_click")
    end
    return true
  end
  
  return false
end

function Minimap.wheelmoved(x, y)
  if not Minimap.visible then return false end
  
  local mx, my = love.mouse.getPosition()
  local mmx, mmy, mmw, mmh = getMinimapBounds()
  if not (mx >= mmx and mx <= mmx + mmw and my >= mmy and my <= mmy + mmh) then return false end
  
  local oldScale = Minimap.scale
  Minimap.scale = math.max(0.005, math.min(0.1, Minimap.scale * (1 + y * 0.1)))
  
  if Minimap.scale ~= oldScale then
    Sound.playSFX("ui_click")
    return true
  end
  
  return false
end

function Minimap.keypressed(key)
  if not Minimap.visible then return false end
  
  if key == "m" then
    Minimap.visible = not Minimap.visible
    Sound.playSFX("ui_click")
    return true
  elseif key == "f" then
    Minimap.followPlayer = not Minimap.followPlayer
    Sound.playSFX("ui_click")
    return true
  end
  
  return false
end

-- Discovery functions removed - no fog of war
function Minimap.ensureDiscovery(world)
  -- No-op: fog of war disabled
end

function Minimap.isDiscovered(wx, wy)
  return true -- All areas are always discovered
end

function Minimap.getDiscovery()
  return nil -- No discovery system
end

function Minimap.revealAt(wx, wy, radius)
  -- No-op: fog of war disabled
end

return Minimap