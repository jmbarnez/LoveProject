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

function Reticle.draw(player, world, camera)
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

  -- Gather missile lock-on status/progress
  local lockInfo = Reticle.getMissileLockInfo(player)
  local incomingLockInfo = Reticle.getIncomingLockInfo(player, world)
  local activeMissiles = Reticle.getActiveMissilesTargetingPlayer(player, world)

  love.graphics.push()
  -- Reticle draws in screen-space; make it crisp
  love.graphics.translate(mx, my)

  -- Read reticle settings (fixed scale)
  local style = (g and g.reticle_style) or 1
  local scale = 0.8

  Theme.setColor(Theme.withAlpha(color, 0.95))
  Reticle.drawPreset(style, scale, color)

  -- Draw lock-on indicator when we're tracking a target
  if lockInfo.progress > 0 or lockInfo.isLocked then
    Reticle.drawLockOnIndicator(scale, lockInfo.progress, lockInfo.isLocked)
  end

  -- Do not alter reticle when shield ability is active (no arc/ring).
  -- No specific loot container targeting; item_pickup handled by pickups system

  love.graphics.pop()

  -- Draw target marker in world space to show which enemy is being tracked
  if lockInfo.target and (lockInfo.progress > 0 or lockInfo.isLocked) then
    Reticle.drawTargetMarker(lockInfo, camera)
  end

  -- Only show missile lock warning if there are active missiles targeting the player
  if #activeMissiles > 0 then
    Reticle.drawActiveMissileWarning(activeMissiles, player, camera)
  end
  
  -- Show offscreen target arrows for enemies targeting the player (but not firing missiles)
  Reticle.drawOffscreenTargetArrows(incomingLockInfo, activeMissiles, player, camera)
end

-- Collect missile lock information from the player's turrets
function Reticle.getMissileLockInfo(player)
  local info = {
    progress = 0,
    isLocked = false,
    target = nil,
    turret = nil
  }

  if not player or not player.components or not player.components.equipment then
    return info
  end

  for _, gridData in ipairs(player.components.equipment.grid) do
    if gridData.type == "turret" and gridData.module then
      local turret = gridData.module
      if turret.kind == "missile" then
        local turretProgress = turret.lockOnProgress or 0
        local turretLocked = turret.isLockedOn and turret.lockOnTarget ~= nil

        if turretLocked then
          turretProgress = math.max(1.0, turretProgress)
          if not info.isLocked or turretProgress >= info.progress then
            info.isLocked = true
            info.progress = turretProgress
            info.target = turret.lockOnTarget
            info.turret = turret
          end
        elseif turret.lockOnTarget and turretProgress > 0 then
          if not info.isLocked and turretProgress > info.progress then
            info.progress = turretProgress
            info.target = turret.lockOnTarget
            info.turret = turret
          end
        end
      end
    end
  end

  return info
end

-- Detect active missiles targeting the player
function Reticle.getActiveMissilesTargetingPlayer(player, world)
  local activeMissiles = {}
  
  if not player or not world or not world.get_entities_with_components then
    return activeMissiles
  end

  local playerPos = player.components and player.components.position
  if not playerPos then
    return activeMissiles
  end

  -- Get all projectiles with homing effects
  local projectiles = world:get_entities_with_components("bullet")
  for _, projectile in ipairs(projectiles) do
    if projectile.components and projectile.components.bullet then
      local bullet = projectile.components.bullet
      local source = bullet.source
      
      -- Check if this is an enemy missile targeting the player
      if source and not source.isPlayer and bullet.additionalEffects then
        for _, effect in ipairs(bullet.additionalEffects) do
          if effect.type == "homing" and effect.target == player then
            table.insert(activeMissiles, {
              projectile = projectile,
              source = source,
              distance = math.sqrt((projectile.components.position.x - playerPos.x)^2 + 
                                 (projectile.components.position.y - playerPos.y)^2)
            })
            break
          end
        end
      end
    end
  end

  return activeMissiles
end

-- Draw lock-on indicator around the reticle
function Reticle.drawLockOnIndicator(scale, progress, isLocked)
  local t = love.timer.getTime()
  local baseRadius = 12 * scale

  love.graphics.setLineWidth(2 * scale)

  -- Base ring showing the overall lock arc
  Theme.setColor(Theme.withAlpha(Theme.colors.success, 0.25))
  love.graphics.circle('line', 0, 0, baseRadius)

  -- Progress arc fills clockwise as lock builds
  if progress and progress > 0 then
    local cappedProgress = math.min(1.0, progress)
    local startAngle = -math.pi * 0.5
    local endAngle = startAngle + cappedProgress * (math.pi * 2)
    local arcColor = isLocked and Theme.colors.success or Theme.colors.warning
    Theme.setColor(Theme.withAlpha(arcColor, isLocked and 0.9 or 0.8))
    love.graphics.arc('line', 0, 0, baseRadius, startAngle, endAngle)
  end

  if not isLocked then
    local prevFont = love.graphics.getFont()
    if Theme.fonts and Theme.fonts.small then love.graphics.setFont(Theme.fonts.small) end
    local font = love.graphics.getFont()
    local label = "LOCKING"
    Theme.setColor(Theme.withAlpha(Theme.colors.warning, 0.95))
    local textW = font:getWidth(label)
    love.graphics.print(label, -textW * 0.5, baseRadius + 6 * scale)
    if prevFont then love.graphics.setFont(prevFont) end
    return
  end

  -- Locked: draw pulsing ring and brackets for strong feedback
  local pulseAlpha = 0.5 + 0.5 * math.sin(t * 4)
  local ringRadius = (12 + 2 * math.sin(t * 3)) * scale
  Theme.setColor(Theme.colors.success[1], Theme.colors.success[2], Theme.colors.success[3], pulseAlpha)
  love.graphics.circle('line', 0, 0, ringRadius)

  local bracketSize = 8 * scale
  local bracketOffset = 6 * scale

  local function drawBracket(xSign, ySign)
    love.graphics.line(xSign * bracketOffset, ySign * bracketOffset,
      xSign * (bracketOffset - bracketSize), ySign * bracketOffset)
    love.graphics.line(xSign * bracketOffset, ySign * bracketOffset,
      xSign * bracketOffset, ySign * (bracketOffset - bracketSize))
  end

  drawBracket(-1, -1)
  drawBracket(1, -1)
  drawBracket(-1, 1)
  drawBracket(1, 1)

  local prevFont = love.graphics.getFont()
  if Theme.fonts and Theme.fonts.small then love.graphics.setFont(Theme.fonts.small) end
  local font = love.graphics.getFont()
  local label = "LOCKED"
  Theme.setColor(Theme.withAlpha(Theme.colors.success, 0.95))
  local textW = font:getWidth(label)
  love.graphics.print(label, -textW * 0.5, baseRadius + 8 * scale)
  if prevFont then love.graphics.setFont(prevFont) end
end

-- Draw marker over the world target that we're locking onto
function Reticle.drawTargetMarker(lockInfo, camera)
  if not lockInfo or not lockInfo.target or not camera then
    return
  end

  local target = lockInfo.target
  if not target.components or not target.components.position then
    return
  end

  local pos = target.components.position
  local sw, sh = Viewport.getDimensions()
  local camScale = camera.scale or 1
  local camX = camera.x or 0
  local camY = camera.y or 0

  local screenX = (pos.x - camX) * camScale + sw * 0.5
  local screenY = (pos.y - camY) * camScale + sh * 0.5

  love.graphics.push()
  love.graphics.translate(screenX, screenY)

  local t = love.timer.getTime()
  local pulse = 1 + 0.05 * math.sin(t * 6)
  local baseRadius = 24
  local color = lockInfo.isLocked and Theme.colors.success or Theme.colors.warning
  local progress = math.max(0, math.min(1, lockInfo.progress or 0))

  -- Background ring provides the silhouette of the target indicator
  Theme.setColor(Theme.withAlpha(color, 0.25))
  love.graphics.setLineWidth(3)
  love.graphics.circle('line', 0, 0, baseRadius)

  -- Draw progress sweep around the enemy to mirror the reticle arc
  local shouldShowProgress = progress > 0 or lockInfo.isLocked
  if shouldShowProgress then
    local startAngle = -math.pi * 0.5
    local arcProgress = lockInfo.isLocked and 1 or progress
    local endAngle = startAngle + arcProgress * math.pi * 2
    Theme.setColor(Theme.withAlpha(color, lockInfo.isLocked and 0.95 or 0.85))
    love.graphics.setLineWidth(4)
    love.graphics.arc('line', 0, 0, baseRadius, startAngle, endAngle)
  end

  -- Locked: pulse an outer ring and add crosshair braces for clarity
  if lockInfo.isLocked then
    local pulseAlpha = 0.55 + 0.35 * math.sin(t * 4)
    local outerRadius = baseRadius + 6 + 2 * math.sin(t * 6)
    Theme.setColor(Theme.withAlpha(color, pulseAlpha))
    love.graphics.setLineWidth(2)
    love.graphics.circle('line', 0, 0, outerRadius)

    Theme.setColor(Theme.withAlpha(color, 0.95))
    local cross = baseRadius + 10
    love.graphics.setLineWidth(2)
    love.graphics.line(-cross, 0, cross, 0)
    love.graphics.line(0, -cross, 0, cross)
  else
    -- While locking, show sweeping chevrons for directional emphasis
    local chevronCount = 4
    local chevronLength = 10
    for i = 0, chevronCount - 1 do
      local angle = (i / chevronCount) * math.pi * 2
      local offset = baseRadius + 4
      local inner = baseRadius - 4
      local alpha = 0.3 + 0.4 * ((progress * chevronCount) - i)
      alpha = math.max(0.15, math.min(0.7, alpha))
      Theme.setColor(Theme.withAlpha(color, alpha))
      love.graphics.line(
        math.cos(angle) * inner,
        math.sin(angle) * inner,
        math.cos(angle) * (inner + chevronLength),
        math.sin(angle) * (inner + chevronLength)
      )
      Theme.setColor(Theme.withAlpha(color, alpha * 0.6))
      love.graphics.circle('fill', math.cos(angle) * offset, math.sin(angle) * offset, 2)
    end
  end

  love.graphics.pop()
end

-- Scan the world for hostile turrets that are locking onto the player
function Reticle.getIncomingLockInfo(player, world)
  local info = {
    total = 0,
    lockedCount = 0,
    highestProgress = 0,
    threats = {},
  }

  if not world or not world.entities or not player then
    return info
  end

  local function isHostile(entity)
    if not entity or entity == player or entity.dead then return false end
    if entity.isPlayer or entity.isFriendly then return false end
    if entity.isEnemy or entity.isEnemyShip then return true end
    local ai = entity.components and entity.components.ai
    if ai then
      if ai.aggressiveType and ai.aggressiveType == "neutral" then
        return false
      end
      return true
    end
    return false
  end

  for _, entity in pairs(world.entities) do
    if isHostile(entity) and entity.components and entity.components.equipment then
      local grid = entity.components.equipment.grid
      if grid then
        for _, slot in ipairs(grid) do
          if slot and slot.type == "turret" and slot.module then
            local turret = slot.module
            if turret.kind == "missile" and turret.lockOnTarget == player then
              local progress = turret.lockOnProgress or 0
              local locked = turret.isLockedOn or false
              if locked then
                progress = math.max(1.0, progress)
                info.lockedCount = info.lockedCount + 1
              end
              info.total = info.total + 1
              info.highestProgress = math.max(info.highestProgress, progress)
              local threatPos
              if entity.components and entity.components.position then
                threatPos = {
                  x = entity.components.position.x,
                  y = entity.components.position.y,
                }
              end
              table.insert(info.threats, {
                entity = entity,
                turret = turret,
                progress = progress,
                isLocked = locked,
                position = threatPos,
              })
            end
          end
        end
      end
    end
  end

  return info
end

local function drawDirectionIndicator(cx, cy, angle, color, locked, radius)
  radius = radius or 200
  local x = cx + math.cos(angle) * radius
  local y = cy + math.sin(angle) * radius
  local size = locked and 14 or 10

  Theme.setColor(Theme.withAlpha(color, locked and 0.95 or 0.75))
  love.graphics.push()
  love.graphics.translate(x, y)
  love.graphics.rotate(angle)
  love.graphics.polygon('fill', 0, -size * 0.5, size, 0, 0, size * 0.5)
  love.graphics.setLineWidth(2)
  love.graphics.polygon('line', 0, -size * 0.5, size, 0, 0, size * 0.5)
  love.graphics.pop()
end

-- Draw warning for active missiles targeting the player
function Reticle.drawActiveMissileWarning(activeMissiles, player, camera)
  if not activeMissiles or #activeMissiles == 0 or not player or not player.components then
    return
  end

  local playerPos = player.components.position
  if not playerPos then return end

  local sw, sh = Viewport.getDimensions()
  local camScale = (camera and camera.scale) or 1
  local camX = (camera and camera.x) or 0
  local camY = (camera and camera.y) or 0

  local playerScreenX = (playerPos.x - camX) * camScale + sw * 0.5
  local playerScreenY = (playerPos.y - camY) * camScale + sh * 0.5

  local message = "MISSILE INCOMING"
  local color = Theme.colors.danger
  local pulse = 0.65 + 0.35 * math.sin(love.timer.getTime() * 8)

  local bannerWidth = 240
  local bannerHeight = 34
  local bannerX = math.floor(sw * 0.5 - bannerWidth * 0.5)
  local bannerY = math.floor(sh * 0.12 - bannerHeight * 0.5)

  Theme.setColor(Theme.withAlpha(color, pulse * 0.6))
  love.graphics.rectangle('fill', bannerX, bannerY, bannerWidth, bannerHeight, 6, 6)
  Theme.setColor(Theme.withAlpha(color, 0.95))
  love.graphics.setLineWidth(2)
  love.graphics.rectangle('line', bannerX, bannerY, bannerWidth, bannerHeight, 6, 6)
  love.graphics.setLineWidth(1)

  local prevFont = love.graphics.getFont()
  if Theme.fonts and Theme.fonts.medium then love.graphics.setFont(Theme.fonts.medium) end
  local font = love.graphics.getFont()
  local textW = font:getWidth(message)
  Theme.setColor({1, 1, 1, 0.95})
  love.graphics.print(message, bannerX + (bannerWidth - textW) * 0.5, bannerY + 4)

  -- Show missile count
  local countText = tostring(#activeMissiles) .. " MISSILE" .. (#activeMissiles > 1 and "S" or "")
  local countW = font:getWidth(countText)
  Theme.setColor({1, 0.8, 0.8, 0.9})
  love.graphics.print(countText, bannerX + (bannerWidth - countW) * 0.5, bannerY + 18)

  if prevFont then love.graphics.setFont(prevFont) end
end

-- Draw offscreen target arrows for enemies targeting the player
function Reticle.drawOffscreenTargetArrows(incomingLockInfo, activeMissiles, player, camera)
  if not incomingLockInfo or incomingLockInfo.total <= 0 or not player or not player.components then
    return
  end

  local playerPos = player.components.position
  if not playerPos then return end

  local sw, sh = Viewport.getDimensions()
  local camScale = (camera and camera.scale) or 1
  local camX = (camera and camera.x) or 0
  local camY = (camera and camera.y) or 0

  local playerScreenX = (playerPos.x - camX) * camScale + sw * 0.5
  local playerScreenY = (playerPos.y - camY) * camScale + sh * 0.5

  -- Create a set of active missile sources to exclude from arrows
  local activeMissileSources = {}
  for _, missile in ipairs(activeMissiles) do
    if missile.source then
      activeMissileSources[missile.source] = true
    end
  end

  -- Draw arrows for threats that are not currently firing missiles
  for _, threat in ipairs(incomingLockInfo.threats) do
    if threat.position and not activeMissileSources[threat.entity] then
      local threatScreenX = (threat.position.x - camX) * camScale + sw * 0.5
      local threatScreenY = (threat.position.y - camY) * camScale + sh * 0.5
      
      -- Check if threat is offscreen
      local margin = 50
      local isOffscreen = threatScreenX < -margin or threatScreenX > sw + margin or 
                         threatScreenY < -margin or threatScreenY > sh + margin
      
      if isOffscreen then
        -- Calculate direction from player to threat
        local dx = threatScreenX - playerScreenX
        local dy = threatScreenY - playerScreenY
        local angle = math.atan2(dy, dx)
        
        -- Clamp arrow position to screen edge
        local arrowX = math.max(margin, math.min(sw - margin, threatScreenX))
        local arrowY = math.max(margin, math.min(sh - margin, threatScreenY))
        
        -- Draw arrow
        local color = threat.isLocked and Theme.colors.danger or Theme.colors.warning
        local alpha = threat.isLocked and 0.9 or 0.6
        local size = threat.isLocked and 12 or 8
        
        Theme.setColor(Theme.withAlpha(color, alpha))
        love.graphics.push()
        love.graphics.translate(arrowX, arrowY)
        love.graphics.rotate(angle)
        love.graphics.polygon('fill', 0, -size * 0.5, size, 0, 0, size * 0.5)
        love.graphics.setLineWidth(2)
        love.graphics.polygon('line', 0, -size * 0.5, size, 0, 0, size * 0.5)
        love.graphics.pop()
      end
    end
  end
end

function Reticle.drawIncomingLockWarning(info, player, camera)
  if not info or info.total <= 0 or not player or not player.components then
    return
  end

  local playerPos = player.components.position
  if not playerPos then return end

  local sw, sh = Viewport.getDimensions()
  local camScale = (camera and camera.scale) or 1
  local camX = (camera and camera.x) or 0
  local camY = (camera and camera.y) or 0

  local playerScreenX = (playerPos.x - camX) * camScale + sw * 0.5
  local playerScreenY = (playerPos.y - camY) * camScale + sh * 0.5

  local message = info.lockedCount > 0 and "MISSILE LOCKED" or "LOCK WARNING"
  local color = info.lockedCount > 0 and Theme.colors.danger or Theme.colors.warning
  local pulse = 0.65 + 0.35 * math.sin(love.timer.getTime() * 6)

  local bannerWidth = 220
  local bannerHeight = 34
  local bannerX = math.floor(sw * 0.5 - bannerWidth * 0.5)
  local bannerY = math.floor(sh * 0.12 - bannerHeight * 0.5)

  Theme.setColor(Theme.withAlpha(color, pulse * 0.5))
  love.graphics.rectangle('fill', bannerX, bannerY, bannerWidth, bannerHeight, 6, 6)
  Theme.setColor(Theme.withAlpha(color, 0.95))
  love.graphics.setLineWidth(2)
  love.graphics.rectangle('line', bannerX, bannerY, bannerWidth, bannerHeight, 6, 6)
  love.graphics.setLineWidth(1)

  local prevFont = love.graphics.getFont()
  if Theme.fonts and Theme.fonts.medium then love.graphics.setFont(Theme.fonts.medium) end
  local font = love.graphics.getFont()
  local textW = font:getWidth(message)
  Theme.setColor({1, 1, 1, 0.95})
  love.graphics.print(message, bannerX + (bannerWidth - textW) * 0.5, bannerY + 4)

  local progress = math.max(0, math.min(1, info.highestProgress))
  local barMargin = 12
  local barX = bannerX + barMargin
  local barY = bannerY + bannerHeight - 10
  local barW = bannerWidth - barMargin * 2
  local barH = 6

  Theme.setColor(Theme.withAlpha({0, 0, 0}, 0.35))
  love.graphics.rectangle('fill', barX, barY, barW, barH, 3, 3)
  Theme.setColor(Theme.withAlpha(color, 0.9))
  love.graphics.rectangle('fill', barX, barY, barW * progress, barH, 3, 3)

  if prevFont then love.graphics.setFont(prevFont) end

  local edgeRadius = math.min(sw, sh) * 0.35

  for _, threat in ipairs(info.threats) do
    if threat.position then
      local sx = (threat.position.x - camX) * camScale + sw * 0.5
      local sy = (threat.position.y - camY) * camScale + sh * 0.5
      local dx = sx - playerScreenX
      local dy = sy - playerScreenY
      local angle = math.atan2(dy, dx)
      local threatColor = threat.isLocked and Theme.colors.danger or Theme.colors.warning
      drawDirectionIndicator(playerScreenX, playerScreenY, angle, threatColor, threat.isLocked, edgeRadius)
    end
  end
end

return Reticle
