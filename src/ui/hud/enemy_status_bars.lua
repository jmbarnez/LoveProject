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

  local innerPad = 2
  local innerX = x + innerPad
  local innerY = y + innerPad
  local innerW = w - innerPad * 2
  local innerH = h - innerPad * 2

  -- Soft drop shadow similar to player's HUD style
  love.graphics.setColor(0, 0, 0, 0.4)
  love.graphics.rectangle("fill", x - 2, y - 2, w + 4, h + 6, innerH * 0.5, innerH * 0.5)

  -- Background cavity
  Theme.setColor(Theme.withAlpha(Theme.colors.bg0, 0.9))
  Theme.drawSciFiBar(innerX, innerY, innerW, innerH, 1.0, Theme.colors.bg1)

  -- Hull fill uses player's sci-fi bar shape and dynamic color from green->yellow->red
  if hullPct > 0 then
    local r, g
    if hullPct > 0.5 then
      local t = (hullPct - 0.5) / 0.5
      r, g = t, 1
    else
      local t = hullPct / 0.5
      r, g = 1, t
    end
    local hullColor = { r, g, 0.12, 0.95 }
    Theme.drawSciFiBar(innerX, innerY, innerW, innerH, hullPct, hullColor)
  end

  -- Shield overlay (right-anchored) using the same sci-fi shape with clipping
  if shieldPct > 0 and innerW > 0 then
    local overlayW = math.max(4, math.min(innerW, innerW * shieldPct))
    local overlayX = innerX + innerW - overlayW
    local shieldColor = Theme.semantic.statusShield

    -- Clip to the right-side region, then draw a full bar under that scissor
    local prevScissor = { love.graphics.getScissor() }
    love.graphics.setScissor(overlayX, innerY - 1, overlayW, innerH + 2)
    Theme.drawSciFiBar(innerX, innerY - 1, innerW, innerH + 2, 1.0, {shieldColor[1], shieldColor[2], shieldColor[3], 0.92})
    love.graphics.setScissor(prevScissor[1], prevScissor[2], prevScissor[3], prevScissor[4])

    -- Glint accent across the shield overlay
    local prevScissor2 = { love.graphics.getScissor() }
    love.graphics.setScissor(overlayX, innerY - 1, overlayW, 2)
    love.graphics.setColor(1.0, 1.0, 1.0, 0.22)
    Theme.drawSciFiBar(innerX, innerY - 1, innerW, 2, 1.0, {1,1,1,0.22})
    love.graphics.setScissor(prevScissor2[1], prevScissor2[2], prevScissor2[3], prevScissor2[4])
  end

  -- Optional segment markers for readability (retain from previous design)
  if innerW > 0 then
    love.graphics.setColor(0, 0, 0, 0.35)
    local segments = math.max(3, math.floor(innerW / 28))
    for i = 1, segments - 1 do
      local segX = innerX + innerW * (i / segments)
      love.graphics.line(segX, innerY + 1, segX, innerY + innerH - 1)
    end
  end
end

-- Draw small screen-aligned shield/health bars above an enemy entity.
function EnemyStatusBars.drawMiniBars(entity)
  if not entity or not entity.components then return end
  local h = entity.components.health
  local col = entity.components.collidable
  if not (h and col) then return end

  -- Check if this is a player entity
  local isPlayer = entity.isPlayer or (entity.components and entity.components.player ~= nil) or entity.isRemotePlayer
  
  -- For players, always show health bars
  if isPlayer then
    -- Always show for players
  else
    -- For enemies, show bars if recently damaged OR if enemy is low on health/shield
    local showTime = getCombatValue("ENEMY_BAR_VIS_TIME") or 2.5
    local last = entity._hudDamageTime or -1e9
    local timeSinceDamage = love.timer.getTime() - last
    
    -- Always show if recently damaged
    local recentlyDamaged = timeSinceDamage <= showTime
    
    -- Also show if enemy is low on health or has shields (for better visibility)
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

  local radius = col.radius or 12
  local barW = math.max(60, math.min(140, radius * 2.4))
  local barH = 12

  -- Position above the ship: undo rotation so bars are screen-aligned
  local angle = (entity.components.position and entity.components.position.angle) or 0
  love.graphics.push()
  love.graphics.rotate(-angle)

  local baseY = -(radius + 22)
  local x0 = -barW/2

  -- Combined hull + shield bar (like player) - shield overlays hull
  local hpPct = math.max(0, math.min(1, hp / math.max(1, maxHP)))
  local shieldPct = maxShield > 0 and math.max(0, math.min(1, shield / math.max(1, maxShield))) or 0

  drawOverheadBar(x0, baseY, barW, barH, hpPct, shieldPct)

  love.graphics.pop()
end

return EnemyStatusBars

