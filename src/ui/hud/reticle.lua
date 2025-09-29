local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local Constants = require("src.core.constants")
local Config = require("src.content.config")

local combatOverrides = Config.COMBAT or {}
local combatConstants = Constants.COMBAT

local function getCombatValue(key)
  local value = combatOverrides[key]
  if value ~= nil then return value end
  return combatConstants[key]
end
local Settings = require("src.core.settings")

local Reticle = {}

local function isAligned(player)
  if not player or not player.components or not player.components.position then return false end
  if not player.cursorWorldPos then return false end
  local pos = player.components.position
  local wx, wy = player.cursorWorldPos.x, player.cursorWorldPos.y
  -- Compare ship facing to cursor vector in world-space
  local dx, dy = wx - pos.x, wy - pos.y
  local desired = (math.atan2 and math.atan2(dy, dx)) or math.atan(dy / math.max(1e-6, dx))
  local diff = (desired - (pos.angle or 0) + math.pi) % (2 * math.pi) - math.pi
  local deg = math.deg(math.abs(diff))
  return deg <= (getCombatValue("ALIGN_LOCK_DEG") or 10)
end

function Reticle.drawPreset(style, scale, color)
  -- Derive family and variation from style 1..50
  local idx = math.max(1, math.min(50, style or 1))
  local fam = ((idx - 1) % 10) + 1
  local var = math.floor((idx - 1) / 10) -- 0..4

  local len = (8 + var * 2) * scale
  local gap = (2 + var * 0.5) * scale
  local thick = (fam == 9 and 2 or 1) * scale
  local ring = ((fam == 3 or fam == 4 or fam == 8) and (4 + var * 1.2) * scale) or 0
  local dot = ((fam == 2 or fam == 3) and (1 + 0.3 * var) * scale) or 0

  love.graphics.setLineWidth(math.max(1, thick))

  -- Families
  if fam == 1 then
    -- Simple cross
    love.graphics.line(gap, 0, gap + len, 0)
    love.graphics.line(-gap, 0, -gap - len, 0)
    love.graphics.line(0, gap, 0, gap + len)
    love.graphics.line(0, -gap, 0, -gap - len)
  elseif fam == 2 then
    -- Cross + dot
    love.graphics.line(gap, 0, gap + len, 0)
    love.graphics.line(-gap, 0, -gap - len, 0)
    love.graphics.line(0, gap, 0, gap + len)
    love.graphics.line(0, -gap, 0, -gap - len)
    if dot > 0 then love.graphics.circle('fill', 0, 0, dot) end
  elseif fam == 3 then
    -- Ring + dot
    if ring > 0 then love.graphics.circle('line', 0, 0, ring) end
    if dot > 0 then love.graphics.circle('fill', 0, 0, dot) end
  elseif fam == 4 then
    -- Ring + cross
    if ring > 0 then love.graphics.circle('line', 0, 0, ring) end
    love.graphics.line(gap, 0, gap + len, 0)
    love.graphics.line(-gap, 0, -gap - len, 0)
    love.graphics.line(0, gap, 0, gap + len)
    love.graphics.line(0, -gap, 0, -gap - len)
  elseif fam == 5 then
    -- Diagonal cross (X)
    love.graphics.line(gap * 0.7, gap * 0.7, (gap + len) * 0.7, (gap + len) * 0.7)
    love.graphics.line(-gap * 0.7, -gap * 0.7, -(gap + len) * 0.7, -(gap + len) * 0.7)
    love.graphics.line(-gap * 0.7, gap * 0.7, -(gap + len) * 0.7, (gap + len) * 0.7)
    love.graphics.line(gap * 0.7, -gap * 0.7, (gap + len) * 0.7, -(gap + len) * 0.7)
  elseif fam == 6 then
    -- Corner brackets
    local b = len * 0.5
    love.graphics.line(-b, -b, -b + len * 0.3, -b)
    love.graphics.line(-b, -b, -b, -b + len * 0.3)
    love.graphics.line(b, -b, b - len * 0.3, -b)
    love.graphics.line(b, -b, b, -b + len * 0.3)
    love.graphics.line(-b, b, -b + len * 0.3, b)
    love.graphics.line(-b, b, -b, b - len * 0.3)
    love.graphics.line(b, b, b - len * 0.3, b)
    love.graphics.line(b, b, b, b - len * 0.3)
  elseif fam == 7 then
    -- Chevrons
    local c = len * 0.6
    love.graphics.line(-c, 0, -gap, -gap)
    love.graphics.line(-c, 0, -gap, gap)
    love.graphics.line(c, 0, gap, -gap)
    love.graphics.line(c, 0, gap, gap)
  elseif fam == 8 then
    -- Diamond
    local d = (ring > 0 and ring or len * 0.6)
    love.graphics.polygon('line', 0, -d, d, 0, 0, d, -d, 0)
  elseif fam == 9 then
    -- Square box
    local b = len * 0.7
    love.graphics.rectangle('line', -b, -b, b * 2, b * 2)
  elseif fam == 10 then
    -- Star (cross + diagonals small)
    local s = len * 0.6
    love.graphics.line(gap, 0, gap + s, 0)
    love.graphics.line(-gap, 0, -gap - s, 0)
    love.graphics.line(0, gap, 0, gap + s)
    love.graphics.line(0, -gap, 0, -gap - s)
    local d = s * 0.7
    love.graphics.line(d * 0.7, d * 0.7, d, d)
    love.graphics.line(-d * 0.7, -d * 0.7, -d, -d)
    love.graphics.line(-d * 0.7, d * 0.7, -d, d)
    love.graphics.line(d * 0.7, -d * 0.7, d, -d)
  end
end

local function colorByName(name)
  local c = (name or "accent"):lower()
  local T = Theme.colors
  if c == "white" then return {1,1,1,1} end
  if c == "accent" then return T.accent end
  if c == "cyan" then return T.info end
  if c == "green" then return T.success end
  if c == "red" then return T.danger end
  if c == "yellow" then return T.warning end
  if c == "magenta" or c == "pink" then return T.accentPink end
  if c == "teal" then return T.accentTeal end
  if c == "gold" or c == "orange" then return T.accentGold end
  return T.accent
end

function Reticle.draw(player)
  local mx, my = Viewport.getMousePosition()
  local t = love.timer.getTime()

  local g = Settings.getGraphicsSettings()
  local userColor
  if g and g.reticle_color_rgb and type(g.reticle_color_rgb) == 'table' then
    userColor = { g.reticle_color_rgb[1] or 1, g.reticle_color_rgb[2] or 1, g.reticle_color_rgb[3] or 1, g.reticle_color_rgb[4] or 1 }
  else
    userColor = colorByName(g and g.reticle_color)
  end
  local aligned = isAligned(player)
  local base = userColor
  -- Preserve user's exact color choice - don't blend with theme colors
  local color = Theme.pulseColor(base, base, t, 1.0)

  -- Check for missile lock-on status
  local missileLockedOn = Reticle.checkMissileLockOn(player)

  love.graphics.push()
  -- Reticle draws in screen-space; make it crisp
  love.graphics.translate(mx, my)

  -- Read reticle settings (fixed scale)
  local style = (g and g.reticle_style) or 1
  local scale = 0.8

  Theme.setColor(Theme.withAlpha(color, 0.95))
  Reticle.drawPreset(style, scale, color)

  -- Draw lock-on indicator if missile is locked on
  if missileLockedOn then
    Reticle.drawLockOnIndicator(scale)
  end

  -- Do not alter reticle when shield ability is active (no arc/ring).
  -- No specific loot container targeting; item_pickup handled by pickups system

  love.graphics.pop()
end

-- Check if any missile turret is currently locked on
function Reticle.checkMissileLockOn(player)
  if not player or not player.components or not player.components.equipment then
    return false
  end

  -- Check all turrets in the equipment grid
  for _, gridData in ipairs(player.components.equipment.grid) do
    if gridData.type == "turret" and gridData.module then
      local turret = gridData.module
      if turret.kind == "missile" and turret.isLockedOn then
        return true
      end
    end
  end

  return false
end

-- Draw lock-on indicator around the reticle
function Reticle.drawLockOnIndicator(scale)
  local t = love.timer.getTime()
  local pulseAlpha = 0.5 + 0.5 * math.sin(t * 4) -- Pulsing effect

  -- Draw a pulsing ring around the reticle to indicate lock-on
  local ringRadius = (12 + 2 * math.sin(t * 3)) * scale -- Slightly pulsing ring
  Theme.setColor(Theme.colors.success[1], Theme.colors.success[2], Theme.colors.success[3], pulseAlpha)
  love.graphics.setLineWidth(2 * scale)
  love.graphics.circle('line', 0, 0, ringRadius)

  -- Draw corner brackets to indicate lock-on
  local bracketSize = 8 * scale
  local bracketOffset = 6 * scale

  -- Top-left bracket
  love.graphics.line(-bracketOffset, -bracketOffset, -bracketOffset + bracketSize, -bracketOffset)
  love.graphics.line(-bracketOffset, -bracketOffset, -bracketOffset, -bracketOffset + bracketSize)

  -- Top-right bracket
  love.graphics.line(bracketOffset, -bracketOffset, bracketOffset - bracketSize, -bracketOffset)
  love.graphics.line(bracketOffset, -bracketOffset, bracketOffset, -bracketOffset + bracketSize)

  -- Bottom-left bracket
  love.graphics.line(-bracketOffset, bracketOffset, -bracketOffset + bracketSize, bracketOffset)
  love.graphics.line(-bracketOffset, bracketOffset, -bracketOffset, bracketOffset - bracketSize)

  -- Bottom-right bracket
  love.graphics.line(bracketOffset, bracketOffset, bracketOffset - bracketSize, bracketOffset)
  love.graphics.line(bracketOffset, bracketOffset, bracketOffset, bracketOffset - bracketSize)
end

return Reticle
