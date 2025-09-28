local EnemyStatusBars = {}

-- Draw small screen-aligned shield/health bars above an enemy entity.
function EnemyStatusBars.drawMiniBars(entity)
  if not entity or not entity.components then return end
  local h = entity.components.health
  local col = entity.components.collidable
  if not (h and col) then return end

  -- Only show for a limited duration after player deals damage
  local showTime = (require("src.content.config").COMBAT.ENEMY_BAR_VIS_TIME or 2.5)
  local last = entity._hudDamageTime or -1e9
  if love.timer.getTime() - last > showTime then return end

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

  -- Health bar
  local hpPct = math.max(0, math.min(1, hp / math.max(1, maxHP)))
  local Theme = require("src.core.theme")
  Theme.setColor(Theme.withAlpha(Theme.colors.shadow, 0.6))
  love.graphics.rectangle('fill', x0, baseY, barW, barH, 2, 2)
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
  love.graphics.setColor(0.9, 0.9, 0.9, 0.6)
  love.graphics.rectangle('line', x0, baseY, barW, barH, 2, 2)

  love.graphics.pop()
end

return EnemyStatusBars

