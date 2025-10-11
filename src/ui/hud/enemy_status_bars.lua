local Theme = require("src.core.theme")
local Constants = require("src.core.constants")
local Config = require("src.content.config")

local combatOverrides = Config.COMBAT or {}
local combatConstants = Constants.COMBAT

local function getCombatValue(key)
  local value = combatOverrides[key]
  if value ~= nil then return value end
  return combatConstants[key]
end
local EnemyStatusBars = {}


local function drawOverheadBar(x, y, w, h, hullPct, shieldPct)
  hullPct = math.max(0, math.min(1, hullPct or 0))
  shieldPct = math.max(0, math.min(1, shieldPct or 0))

  -- Sleeker design inspired by player HUD
  local innerPad = 1
  local innerX = x + innerPad
  local innerY = y + innerPad
  local innerW = w - innerPad * 2
  local innerH = h - innerPad * 2

  -- Subtle drop shadow with slight glow
  love.graphics.setColor(0, 0, 0, 0.3)
  love.graphics.rectangle("fill", x - 1, y - 1, w + 2, h + 2, 2, 2)
  
  -- Very subtle outer glow for high-tech feel
  love.graphics.setColor(0.2, 0.4, 0.6, 0.1)
  love.graphics.rectangle("fill", x - 2, y - 2, w + 4, h + 4, 3, 3)

  -- Background - dark with subtle border
  Theme.setColor(Theme.withAlpha(Theme.colors.bg0, 0.85))
  love.graphics.rectangle("fill", innerX, innerY, innerW, innerH, 2, 2)
  
  -- Border - subtle cyan accent
  Theme.setColor(Theme.withAlpha(Theme.colors.border, 0.6))
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", innerX, innerY, innerW, innerH, 2, 2)

  -- Hull fill - dynamic color from green->yellow->red (like player HUD)
  if hullPct > 0 then
    local r, g, b
    if hullPct > 0.6 then
      -- Green to yellow transition
      local t = (hullPct - 0.6) / 0.4
      r, g, b = t, 1, 0.2
    else
      -- Yellow to red transition
      local t = hullPct / 0.6
      r, g, b = 1, t, 0.1
    end
    local hullColor = { r, g, b, 0.9 }
    love.graphics.setColor(hullColor)
    love.graphics.rectangle("fill", innerX, innerY, innerW * hullPct, innerH, 2, 2)
  end

  -- Shield overlay - blue overlay on top of hull (like player HUD)
  if shieldPct > 0 and innerW > 0 then
    local shieldWidth = innerW * shieldPct
    local shieldColor = Theme.semantic.statusShield
    love.graphics.setColor({shieldColor[1], shieldColor[2], shieldColor[3], 0.85})
    love.graphics.rectangle("fill", innerX, innerY, shieldWidth, innerH, 2, 2)
    
    -- Subtle highlight on shield
    love.graphics.setColor(1.0, 1.0, 1.0, 0.15)
    love.graphics.rectangle("fill", innerX, innerY, shieldWidth, 1, 2, 2)
  end

  -- Clean segment dividers for readability
  if innerW > 0 and innerW > 40 then
    love.graphics.setColor(0, 0, 0, 0.25)
    local segments = math.max(2, math.floor(innerW / 20))
    for i = 1, segments - 1 do
      local segX = innerX + innerW * (i / segments)
      love.graphics.line(segX, innerY + 1, segX, innerY + innerH - 1)
    end
  end
end

local function drawOverheadBarWithText(x, y, w, h, hullPct, shieldPct, text, enemyLevel)
  hullPct = math.max(0, math.min(1, hullPct or 0))
  shieldPct = math.max(0, math.min(1, shieldPct or 0))

  -- Sleeker design inspired by player HUD
  local innerPad = 1
  local innerX = x + innerPad
  local innerY = y + innerPad
  local innerW = w - innerPad * 2
  local innerH = h - innerPad * 2

  -- Subtle drop shadow with slight glow
  love.graphics.setColor(0, 0, 0, 0.3)
  love.graphics.rectangle("fill", x - 1, y - 1, w + 2, h + 2, 2, 2)
  
  -- Very subtle outer glow for high-tech feel
  love.graphics.setColor(0.2, 0.4, 0.6, 0.1)
  love.graphics.rectangle("fill", x - 2, y - 2, w + 4, h + 4, 3, 3)

  -- Background - dark with subtle border
  Theme.setColor(Theme.withAlpha(Theme.colors.bg0, 0.85))
  love.graphics.rectangle("fill", innerX, innerY, innerW, innerH, 2, 2)
  
  -- Border - use threat color if available, otherwise subtle cyan accent
  if enemyLevel then
    local threatColor = enemyLevel:getThreatColor()
    love.graphics.setColor(threatColor[1], threatColor[2], threatColor[3], 0.8)
  else
    Theme.setColor(Theme.withAlpha(Theme.colors.border, 0.6))
  end
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", innerX, innerY, innerW, innerH, 2, 2)

  -- Hull fill - dynamic color from green->yellow->red (like player HUD)
  if hullPct > 0 then
    local r, g, b
    if hullPct > 0.6 then
      -- Green to yellow transition
      local t = (hullPct - 0.6) / 0.4
      r, g, b = t, 1, 0.2
    else
      -- Yellow to red transition
      local t = hullPct / 0.6
      r, g, b = 1, t, 0.1
    end
    local hullColor = { r, g, b, 0.9 }
    love.graphics.setColor(hullColor)
    love.graphics.rectangle("fill", innerX, innerY, innerW * hullPct, innerH, 2, 2)
  end

  -- Shield overlay - blue overlay on top of hull (like player HUD)
  if shieldPct > 0 and innerW > 0 then
    local shieldWidth = innerW * shieldPct
    local shieldColor = Theme.semantic.statusShield
    love.graphics.setColor(shieldColor[1], shieldColor[2], shieldColor[3], 0.7)
    love.graphics.rectangle("fill", innerX, innerY, shieldWidth, innerH, 2, 2)
    
    -- Shield highlight line
    love.graphics.setColor(shieldColor[1], shieldColor[2], shieldColor[3], 0.9)
    love.graphics.rectangle("fill", innerX, innerY, shieldWidth, 1, 2, 2)
  end

  -- Clean segment dividers for readability
  if innerW > 0 and innerW > 40 then
    love.graphics.setColor(0, 0, 0, 0.25)
    local segments = math.max(2, math.floor(innerW / 20))
    for i = 1, segments - 1 do
      local segX = innerX + innerW * (i / segments)
      love.graphics.line(segX, innerY + 1, segX, innerY + innerH - 1)
    end
  end

  -- Draw text centered in the bar
  if text then
    local oldFont = love.graphics.getFont()
    if Theme.fonts and Theme.fonts.small then 
      love.graphics.setFont(Theme.fonts.small) 
    end
    local font = love.graphics.getFont()
    local textWidth = font:getWidth(text)
    local textHeight = font:getHeight()
    
    -- Center text in the bar
    local textX = x + w / 2 - textWidth / 2
    local textY = y + h / 2 - textHeight / 2
    
    -- Text shadow for readability
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.print(text, textX + 1, textY + 1)
    
    -- Main text
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(text, textX, textY)
    
    -- Restore font
    if oldFont then
      love.graphics.setFont(oldFont)
    end
  end
end

-- Draw small screen-aligned shield/health bars above any entity with health.
function EnemyStatusBars.drawMiniBars(entity)
  if not entity or not entity.components then return end
  local h = entity.components.health
  local col = entity.components.collidable
  if not h then return end

  -- Check if this is a player entity
  local isPlayer = entity.isPlayer or (entity.components and entity.components.player ~= nil) or entity.isRemotePlayer
  
  -- Check if this is a projectile
  local isProjectile = entity.components.bullet ~= nil
  
  -- For players, always show health bars
  if isPlayer then
    -- Always show for players
  elseif isProjectile then
    -- For projectiles, show if damaged OR recently created (for visibility)
    local hpPct = (h.hp or 0) / math.max(1, h.maxHP or 1)
    local showTime = 1.0 -- Show for 1 second after creation
    local last = entity._hudDamageTime or -1e9
    local timeSinceDamage = love.timer.getTime() - last
    local recentlyDamaged = timeSinceDamage <= showTime
    
    if hpPct >= 1.0 and not recentlyDamaged then
      return -- Don't show health bar for undamaged projectiles unless recently created
    end
  else
    -- For other entities (enemies, stations, etc.), show bars if recently damaged OR if low on health/shield
    local showTime = getCombatValue("ENEMY_BAR_VIS_TIME") or 2.5
    local last = entity._hudDamageTime or -1e9
    local timeSinceDamage = love.timer.getTime() - last
    
    -- Always show if recently damaged
    local recentlyDamaged = timeSinceDamage <= showTime
    
    -- Also show if entity is low on health or has shields (for better visibility)
    local hpPct = (h.hp or 0) / math.max(1, h.maxHP or 100)
    local shieldPct = (h.shield or 0) / math.max(1, h.maxShield or 1)
    local isLowHealth = hpPct < 0.8  -- Show if below 80% health
    local hasShields = (h.maxShield or 0) > 0 and (h.shield or 0) > 0  -- Show if has shields
    
    if not recentlyDamaged and not isLowHealth and not hasShields then
      return
    end
  end

  local hp = h.hp or h.current or 0
  local maxHP = h.maxHP or h.max or 100
  local shield = h.shield or 0
  local maxShield = h.maxShield or 0

  -- Calculate radius - use collidable radius if available, otherwise estimate from entity type
  local radius = 12 -- Default radius
  if col and col.radius then
    radius = col.radius
  elseif isProjectile then
    -- Projectiles are small, use a smaller radius
    radius = 4
  elseif entity.components.renderable and entity.components.renderable.props then
    -- Try to get radius from renderable props
    local props = entity.components.renderable.props
    if props.radius then
      radius = props.radius
    elseif props.size then
      radius = props.size * 10
    end
  end
  
  -- Calculate bar size based on entity type - compact but wide enough for name
  local barW, barH
  if isProjectile then
    -- Smaller bars for projectiles
    barW = math.max(24, math.min(48, radius * 3.5))
    barH = 4
  else
    -- Compact bars for other entities - just wide enough for name
    barW = math.max(100, math.min(160, radius * 3.0))
    barH = 8
  end

  -- Position above the ship: undo rotation so bars are screen-aligned
  local angle = (entity.components.position and entity.components.position.angle) or 0
  love.graphics.push()
  love.graphics.rotate(-angle)

  -- Adjust positioning based on entity type - more elegant spacing
  local baseY, x0
  if isProjectile then
    -- Closer positioning for projectiles
    baseY = -(radius + 6)
    x0 = -barW/2
  else
    -- Sleeker positioning for other entities - closer to ship
    baseY = -(radius + 16)
    x0 = -barW/2
  end

  -- Combined hull + shield bar (like player) - shield overlays hull
  local hpPct = math.max(0, math.min(1, hp / math.max(1, maxHP)))
  local shieldPct = maxShield > 0 and math.max(0, math.min(1, shield / math.max(1, maxShield))) or 0

  -- Draw health bar without text
  drawOverheadBar(x0, baseY, barW, barH, hpPct, shieldPct)
  
  -- Draw name above the health bar
  local enemyLevel = entity.components.enemy_level
  local name = entity.name or "Unknown Enemy"
  local Content = require("src.content.content")
  local shipDef = Content.getShip(entity.shipId)
  if shipDef and shipDef.name then
    name = shipDef.name
  end
  
  -- Draw name label above health bar
  local oldFont = love.graphics.getFont()
  if Theme.fonts and Theme.fonts.small then 
    love.graphics.setFont(Theme.fonts.small) 
  end
  local font = love.graphics.getFont()
  local textWidth = font:getWidth(name)
  local textHeight = font:getHeight()
  
  -- Position name above health bar
  local nameY = baseY - textHeight - 4
  local nameX = x0 + barW / 2 - textWidth / 2
  
  -- Draw simple background for better readability
  local padding = 2
  local bgWidth = textWidth + padding * 2
  local bgHeight = textHeight + padding * 2
  local bgX = nameX - padding
  local bgY = nameY - padding
  
  love.graphics.setColor(0, 0, 0, 0.5)
  love.graphics.rectangle("fill", bgX, bgY, bgWidth, bgHeight)
  
  -- Draw text in white for clean look
  love.graphics.setColor(1, 1, 1, 0.9)
  love.graphics.print(name, nameX, nameY)
  
  -- Restore font
  if oldFont then
    love.graphics.setFont(oldFont)
  end
  
  -- Draw level indicator next to the health bar
  if enemyLevel then
    local levelText = tostring(enemyLevel.level or 1)
    local threatColor = enemyLevel:getThreatColor()
    
    -- Position level indicator to the right of the health bar
    local levelX = x0 + barW + 8
    local levelY = baseY
    
    -- Get font for level indicator
    local oldFont = love.graphics.getFont()
    if Theme.fonts and Theme.fonts.small then 
      love.graphics.setFont(Theme.fonts.small) 
    end
    local font = love.graphics.getFont()
    local textWidth = font:getWidth(levelText)
    local textHeight = font:getHeight()
    
    -- Draw level badge
    local badgeW = textWidth + 8
    local badgeH = textHeight + 4
    local badgeX = levelX
    local badgeY = levelY + (barH - badgeH) / 2 -- Center vertically with health bar
    
    -- Badge background with threat color
    love.graphics.setColor(threatColor[1], threatColor[2], threatColor[3], 0.9)
    love.graphics.rectangle("fill", badgeX, badgeY, badgeW, badgeH, 3, 3)
    
    -- Badge border
    love.graphics.setColor(threatColor[1], threatColor[2], threatColor[3], 1.0)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", badgeX, badgeY, badgeW, badgeH, 3, 3)
    
    -- Level text
    local textX = badgeX + badgeW / 2 - textWidth / 2
    local textY = badgeY + badgeH / 2 - textHeight / 2
    
    -- Text shadow
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.print(levelText, textX + 1, textY + 1)
    
    -- Main text
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(levelText, textX, textY)
    
    -- Restore font
    if oldFont then
      love.graphics.setFont(oldFont)
    end
  end

  love.graphics.pop()
end


return EnemyStatusBars

