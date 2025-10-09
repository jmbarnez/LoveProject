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
  
  -- Calculate bar size based on entity type - sleeker proportions
  local barW, barH
  if isProjectile then
    -- Smaller bars for projectiles
    barW = math.max(24, math.min(48, radius * 3.5))
    barH = 4
  else
    -- Sleeker bars for other entities - more compact and elegant
    barW = math.max(80, math.min(160, radius * 2.8))
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

  drawOverheadBar(x0, baseY, barW, barH, hpPct, shieldPct)

  love.graphics.pop()
end

return EnemyStatusBars

