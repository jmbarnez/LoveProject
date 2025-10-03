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

-- Draw small screen-aligned shield/health bars above an enemy entity.
function EnemyStatusBars.drawMiniBars(entity)
  if not entity or not entity.components then return end
  local h = entity.components.health
  local col = entity.components.collidable
  if not (h and col) then return end

  -- Show bars if recently damaged OR if enemy is low on health/shield
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

  local hp = h.hp or h.current or 0
  local maxHP = h.maxHP or h.max or 100
  local shield = h.shield or 0
  local maxShield = h.maxShield or 0

  local radius = col.radius or 12
  local barW = math.max(36, math.min(100, radius * 2.0))
  local barH = 4
  local gap = 2

  -- Position above the ship: undo rotation so bars are screen-aligned
  local angle = (entity.components.position and entity.components.position.angle) or 0
  love.graphics.push()
  love.graphics.rotate(-angle)

  local baseY = -(radius + 12)
  local x0 = -barW/2

  -- Combined hull + shield bar (like player) - shield overlays hull
  local hpPct = math.max(0, math.min(1, hp / math.max(1, maxHP)))
  local shieldPct = maxShield > 0 and math.max(0, math.min(1, shield / math.max(1, maxShield))) or 0

  -- Bar background
  Theme.setColor(Theme.withAlpha(Theme.colors.shadow, 0.6))
  love.graphics.rectangle('fill', x0, baseY, barW, barH, 2, 2)
  
  -- Draw hull bar as base (red, actual hull percentage)
  local r, g
  if hpPct > 0.5 then
    local t = (hpPct - 0.5) / 0.5
    r, g = t, 1
  else
    local t = hpPct / 0.5
    r, g = 1, t
  end
  love.graphics.setColor(r, g, 0.1, 0.95)
  love.graphics.rectangle('fill', x0, baseY, barW * hpPct, barH, 2, 2)
  
  -- Draw shield bar overlaying hull (blue overlay, only shield portion)
  if shield > 0 then
    local shieldWidth = shieldPct * barW
    Theme.setColor(Theme.semantic.statusShield[1], Theme.semantic.statusShield[2], Theme.semantic.statusShield[3], 0.95)
    love.graphics.rectangle('fill', x0, baseY, shieldWidth, barH, 2, 2)
  end
  
  -- Bar border
  love.graphics.setColor(0.9, 0.9, 0.9, 0.6)
  love.graphics.rectangle('line', x0, baseY, barW, barH, 2, 2)

  love.graphics.pop()
end

return EnemyStatusBars

