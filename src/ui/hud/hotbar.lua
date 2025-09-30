local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local Content = require("src.content.content")
local HotbarSystem = require("src.systems.hotbar")
local Constants = require("src.core.constants")
local Config = require("src.content.config")
local UIUtils = require("src.ui.common.utils")

local Hotbar = {}

local combatOverrides = Config.COMBAT or {}
local combatConstants = Constants.COMBAT

local function getCombatValue(key)
  local value = combatOverrides[key]
  if value ~= nil then return value end
  return combatConstants[key]
end

-- HotbarSelection removed - slot assignment disabled

local IconSystem = require("src.core.icon_system")

local function drawIcon(subjects, x, y, size)
  IconSystem.drawIconAny(subjects, x, y, size, 1.0)
end

local function resolveTurretSubject(module, fallback)
  if not module then return fallback end
  if module._sourceData then return module._sourceData end
  if module.baseId then return module.baseId end
  if module.id then return module.id end
  return fallback
end

local function drawBoostIcon(x, y, size, active)
  local cx, cy = x + size * 0.5, y + size * 0.5
  local flame = active and Theme.colors.warning or Theme.colors.textSecondary
  local body = Theme.colors.text
  Theme.setColor(Theme.withAlpha(body, 0.9))
  -- Thruster body
  love.graphics.rectangle('fill', cx - 6, cy - 10, 12, 20)
  -- Nozzle
  love.graphics.rectangle('fill', cx + 6, cy - 6, 6, 12)
  -- Flame
  Theme.setColor(Theme.withAlpha(flame, active and 0.9 or 0.5))
  love.graphics.polygon('fill', cx + 12, cy - 8, cx + 12, cy + 8, cx + 22, cy)
end

local function drawShieldIcon(x, y, size, active)
  local cx, cy = x + size * 0.5, y + size * 0.5
  local r = size * 0.35
  local base = Theme.colors.info or {0.35, 0.65, 0.95, 1}
  Theme.setColor(Theme.withAlpha(base, active and 0.9 or 0.5))
  love.graphics.circle('fill', cx, cy, r)
  Theme.setColor(Theme.withAlpha({1,1,1,1}, active and 0.35 or 0.2))
  love.graphics.circle('line', cx, cy, r)
  Theme.setColor(Theme.withAlpha({1,1,1,1}, active and 0.6 or 0.3))
  love.graphics.circle('fill', cx + r*0.35, cy - r*0.35, 2)
end

function Hotbar.draw(player)
  local sw, sh = Viewport.getDimensions()
  local size, gap = 52, 10
  local totalSlots = #HotbarSystem.slots
  local w = totalSlots * size + (totalSlots - 1) * gap
  local x = math.floor((sw - w) * 0.5)
  local y = sh - size - 42

  -- Draw speed display above hotbar
  if player and player.components and player.components.physics and player.components.physics.body then
    local body = player.components.physics.body
    local speed = math.sqrt(body.vx * body.vx + body.vy * body.vy)
    local speedText = string.format("Speed: %.1f", speed)

    local oldFont = love.graphics.getFont()
    if Theme.fonts and Theme.fonts.small then love.graphics.setFont(Theme.fonts.small) end

    local font = love.graphics.getFont()
    local metrics = UIUtils.getCachedTextMetrics(speedText, font)
    local speedX = (sw - metrics.width) * 0.5 -- Center horizontally
    local speedY = y - 30 -- Above hotbar

    -- Draw speed background
    local bgWidth = metrics.width + 16
    local bgHeight = metrics.height + 8
    local bgX = speedX - 8
    local bgY = speedY - 4
    
    Theme.setColor(Theme.withAlpha(Theme.colors.bg2, 0.8))
    love.graphics.rectangle("fill", bgX, bgY, bgWidth, bgHeight, 4, 4)
    Theme.setColor(Theme.withAlpha(Theme.colors.borderBright, 0.6))
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", bgX, bgY, bgWidth, bgHeight, 4, 4)

    Theme.setColor(Theme.colors.text)
    love.graphics.print(speedText, speedX, speedY)

    if oldFont then love.graphics.setFont(oldFont) end
  end

  -- Mouse position tracking removed - no hover effects

  for i, slot in ipairs(HotbarSystem.slots) do
    local rx = x + (i - 1) * (size + gap)
    local ry = y

    Theme.setColor(Theme.colors.shadow)
    love.graphics.rectangle('fill', rx + 3, ry + 5, size, size)
    Theme.setColor(Theme.colors.bg2)
    love.graphics.rectangle('fill', rx, ry, size, size)

    local drewIcon = false
    if slot.item == "turret" then
      local subject = nil
      if player and player.components and player.components.equipment and player.components.equipment.grid then
        for _, gridData in ipairs(player.components.equipment.grid) do
          if gridData.type == "turret" and gridData.module then
            subject = resolveTurretSubject(gridData.module, gridData.id)
            break
          end
        end
      end
      drawIcon({ subject, "basic_gun" }, rx + 4, ry + 4, size - 8)
      drewIcon = true
    elseif slot.item == "shield" then
      drawShieldIcon(rx + 4, ry + 4, size - 8, player and player.shieldChannel)
      drewIcon = true
    elseif type(slot.item) == 'string' and (slot.item:match('^turret_slot_%d+$') or slot.item:match('^module_slot_%d+$')) then
      local isTurret = slot.item:match('^turret_slot_%d+$')
      local idx = tonumber(slot.item:match('^turret_slot_(%d+)$') or slot.item:match('^module_slot_(%d+)$'))

      if player and player.components and player.components.equipment and player.components.equipment.grid and idx then
        local gridData = player.components.equipment.grid[idx]
        if gridData and gridData.module then
          local t = gridData.module
          if isTurret then
            -- Handle turret
            local subject = resolveTurretSubject(t, gridData.id)
            drawIcon({ subject, (t and t.id), "basic_gun" }, rx + 4, ry + 4, size - 8)
            drewIcon = true
          else
            -- Handle other modules (shields, etc.)
            if gridData.type == "shield" then
              drawShieldIcon(rx + 4, ry + 4, size - 8, player and player.shieldChannel)
              drewIcon = true
            end
          end

          -- Draw heat bar for turrets only - fills entire slot like cooldown bars
          if isTurret and t and t.getHeatFactor then
              local heatFactor = t:getHeatFactor()
              if heatFactor > 0.001 then -- Lower threshold to make heat bars more visible
                  -- Heat bar fills entire slot area
                  local barX = rx
                  local barY = ry
                  local barWidth = size
                  local barHeight = size

                  -- Heat bar background (semi-transparent dark)
                  love.graphics.setColor(0.1, 0.1, 0.1, 0.6)
                  love.graphics.rectangle('fill', barX, barY, barWidth, barHeight)

                  -- Heat bar fill - red color that fills up the entire slot
                  local heatColor = {
                      0.8 + heatFactor * 0.2, -- Red increases with heat
                      0.2 - heatFactor * 0.1, -- Green decreases with heat
                      0.1 - heatFactor * 0.05, -- Blue decreases with heat
                      0.7 -- Semi-transparent so icon is still visible
                  }
                  love.graphics.setColor(heatColor)
                  love.graphics.rectangle('fill', barX, barY, barWidth * heatFactor, barHeight)

                  -- Overheat pulsing effect
                  if t.overheated then
                      local pulse = (math.sin(love.timer.getTime() * 8) + 1) / 2
                      love.graphics.setColor(1, 0.1 + pulse * 0.3, 0.1 + pulse * 0.3, 0.3 + pulse * 0.2)
                      love.graphics.rectangle('fill', barX, barY, barWidth, barHeight)
                  end
              end
          end

        end
      end
    elseif slot.item == "boost" then
      local active = HotbarSystem.isActive and HotbarSystem.isActive('boost')
      drawBoostIcon(rx + 4, ry + 4, size - 8, active)
      drewIcon = true
    end

    -- Cooldown overlay per slot (reflect module in slot)
    if player and slot.item then
      if slot.item == 'shield' then
        local ss = player._shieldState
        if ss and ss.cooldown and ss.cooldown > 0 then
          local total = getCombatValue("SHIELD_COOLDOWN") or 5.0
          if total > 0 then
            local pct = math.max(0, math.min(1, ss.cooldown / total))
            local barHeight = math.floor(size * pct)
            love.graphics.setColor(0.2, 0.6, 1.0, 0.55) -- info-ish overlay
            love.graphics.rectangle('fill', rx, ry + size - barHeight, size, barHeight)
            love.graphics.setColor(0.4, 0.8, 1.0, 0.9)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle('line', rx, ry + size - barHeight, size, barHeight)

            -- Numeric cooldown (small text, top-right)
            local remaining = math.max(0, ss.cooldown)
            local text = string.format("%.1f", remaining)
            local fOld = love.graphics.getFont()
            if Theme.fonts and Theme.fonts.small then love.graphics.setFont(Theme.fonts.small) end
            local font = love.graphics.getFont()
            local metrics = UIUtils.getCachedTextMetrics(text, font)
            local fw = metrics.width
            local fh = metrics.height
            local tx, ty = rx + (size - fw) * 0.5, ry + (size - fh) * 0.5
            -- shadow for readability
            local Theme = require("src.core.theme")
            Theme.setColor(Theme.withAlpha(Theme.colors.shadow, 0.7))
            love.graphics.print(text, tx + 1, ty + 1)
            Theme.setColor(Theme.colors.text)
            love.graphics.print(text, tx, ty)
            if fOld then love.graphics.setFont(fOld) end
          end
        end
      elseif type(slot.item) == 'string' and slot.item:match('^turret_slot_%d+$') then
        -- Individual turret slot cooldown
        local idx = tonumber(slot.item:match('^turret_slot_(%d+)$'))
        if player and player.components and player.components.equipment and player.components.equipment.grid and idx then
          local gridData = player.components.equipment.grid[idx]
          if gridData and gridData.module then
            local t = gridData.module
            -- Don't show cooldown if turret is overheated (can't fire anyway)
            if t and t.cooldown and t.cooldown > 0 and not t.overheated then
              local cycle = t.cycle or 1.0  -- Fallback to 1.0 if cycle is not available
              local cooldownPct = math.max(0, math.min(1, t.cooldown / cycle))
              if cooldownPct > 0 then
                local barHeight = math.floor(size * cooldownPct)
                -- Use more visible blue for cooldown bar
                love.graphics.setColor(0.1, 0.4, 1.0, 0.8)
                love.graphics.rectangle('fill', rx, ry + size - barHeight, size, barHeight)
                love.graphics.setColor(0.2, 0.6, 1.0, 1.0)
                love.graphics.setLineWidth(2)
                love.graphics.rectangle('line', rx, ry + size - barHeight, size, barHeight)

                -- Numeric cooldown
                local text = string.format("%.1f", t.cooldown)
                local fOld = love.graphics.getFont()
                if Theme.fonts and Theme.fonts.small then love.graphics.setFont(Theme.fonts.small) end
                local font = love.graphics.getFont()
                local metrics = UIUtils.getCachedTextMetrics(text, font)
                local fw = metrics.width
                local fh = metrics.height
                local tx, ty = rx + (size - fw) * 0.5, ry + (size - fh) * 0.5
                local Theme = require("src.core.theme")
                Theme.setColor(Theme.withAlpha(Theme.colors.shadow, 0.7))
                love.graphics.print(text, tx + 1, ty + 1)
                Theme.setColor(Theme.colors.text)
                love.graphics.print(text, tx, ty)
                if fOld then love.graphics.setFont(fOld) end
              end
            end
          end
        end
      elseif slot.item == 'turret' then
        -- Aggregate primary turret cooldown (max ratio across installed turrets that are not overheated)
        local best = 0
        local bestTime = 0
        if player.components and player.components.equipment and player.components.equipment.grid then
          for _, gridData in ipairs(player.components.equipment.grid) do
            if gridData.type == "turret" and gridData.module then
              local t = gridData.module
              -- Only consider turrets that are not overheated for cooldown display
              if t and (t.cooldown or 0) > 0 and not t.overheated then
                  local effectiveCycle = t:getHeatModifiedCycle()
                  if effectiveCycle > 0 then
                      local pct = math.max(0, math.min(1, (t.cooldown or 0) / effectiveCycle))
                      if pct > best then best = pct end
                      if (t.cooldown or 0) > bestTime then bestTime = (t.cooldown or 0) end
                  end
              end
            end
          end
        end
        if best > 0 then
          local barHeight = math.floor(size * best)
          -- Use blue for turret cooldown bar
          love.graphics.setColor(0.2, 0.6, 1.0, 0.7)
          love.graphics.rectangle('fill', rx, ry + size - barHeight, size, barHeight)
          love.graphics.setColor(0.4, 0.8, 1.0, 0.9)
          love.graphics.setLineWidth(1)
          love.graphics.rectangle('line', rx, ry + size - barHeight, size, barHeight)

          -- Numeric cooldown (small text, top-right)
          if bestTime > 0 then
            local text = string.format("%.1f", bestTime)
            local fOld = love.graphics.getFont()
            if Theme.fonts and Theme.fonts.small then love.graphics.setFont(Theme.fonts.small) end
            local font = love.graphics.getFont()
            local metrics = UIUtils.getCachedTextMetrics(text, font)
            local fw = metrics.width
            local fh = metrics.height
            local tx, ty = rx + (size - fw) * 0.5, ry + (size - fh) * 0.5
            -- shadow for readability
            local Theme = require("src.core.theme")
            Theme.setColor(Theme.withAlpha(Theme.colors.shadow, 0.7))
            love.graphics.print(text, tx + 1, ty + 1)
            Theme.setColor(Theme.colors.text)
            love.graphics.print(text, tx, ty)
            if fOld then love.graphics.setFont(fOld) end
          end
        end

        -- Draw heat bar for general turret slot (show max heat across all turrets)
        local maxHeat = 0
        local maxHeatFactor = 0
        local anyOverheated = false
        if player.components and player.components.equipment and player.components.equipment.grid then
          for _, gridData in ipairs(player.components.equipment.grid) do
            if gridData.type == "turret" and gridData.module then
              local t = gridData.module
              if t and t.getHeatFactor then
                local heatFactor = t:getHeatFactor()
                if heatFactor > maxHeatFactor then
                  maxHeatFactor = heatFactor
                end
                if t.overheated then
                  anyOverheated = true
                end
              end
            end
          end
        end
        if maxHeatFactor > 0.001 then -- Lower threshold to make heat bars more visible
          -- Heat bar fills entire slot area
          local barX = rx
          local barY = ry
          local barWidth = size
          local barHeight = size

          -- Heat bar background (semi-transparent dark)
          love.graphics.setColor(0.1, 0.1, 0.1, 0.6)
          love.graphics.rectangle('fill', barX, barY, barWidth, barHeight)

          -- Heat bar fill - red color that fills up the entire slot
          local heatColor = {
              0.8 + maxHeatFactor * 0.2, -- Red increases with heat
              0.2 - maxHeatFactor * 0.1, -- Green decreases with heat
              0.1 - maxHeatFactor * 0.05, -- Blue decreases with heat
              0.7 -- Semi-transparent so icon is still visible
          }
          love.graphics.setColor(heatColor)
          love.graphics.rectangle('fill', barX, barY, barWidth * maxHeatFactor, barHeight)

          -- Overheat pulsing effect
          if anyOverheated then
              local pulse = (math.sin(love.timer.getTime() * 8) + 1) / 2
              love.graphics.setColor(1, 0.1 + pulse * 0.3, 0.1 + pulse * 0.3, 0.3 + pulse * 0.2)
              love.graphics.rectangle('fill', barX, barY, barWidth, barHeight)
          end
        end
      end
    end

    -- Highlight border when active for hold-type actions (draw last so it's on top)
    local borderColor = Theme.colors.border
    if slot.item == 'shield' and (player and player.shieldChannel) then
      borderColor = Theme.colors.info
    elseif slot.item == 'boost' and (HotbarSystem.isActive and HotbarSystem.isActive('boost')) then
      borderColor = Theme.colors.warning
    end
    -- Hover effects removed - hotbar is display-only
    Theme.drawEVEBorder(rx, ry, size, size, 8, borderColor, 6)

    local label = UIUtils.formatKeyLabel(HotbarSystem.getSlotKey and HotbarSystem.getSlotKey(i) or slot.key)
    local oldFont = love.graphics.getFont()
    if Theme.fonts and Theme.fonts.small then love.graphics.setFont(Theme.fonts.small) end
    Theme.setColor(Theme.withAlpha(Theme.colors.text, 0.95))
    love.graphics.printf(label, rx, ry + size - 16, size, 'center')
    if Theme.fonts and Theme.fonts.small and oldFont then love.graphics.setFont(oldFont) end
  end

  -- HotbarSelection.draw() removed - slot assignment disabled
end

function Hotbar.mousepressed(player, mx, my, button)
  -- Hotbar clicking for slot assignment has been removed
  -- Only handle turret firing through the systems/hotbar.lua mousepressed function
  return false
end

Hotbar.drawIcon = drawIcon
function Hotbar.drawTurretIcon(subject, x, y, size)
  if type(subject) == "table" and subject[1] ~= nil then
    drawIcon(subject, x, y, size or 48)
  else
    drawIcon({ subject, "basic_gun" }, x, y, size or 48)
  end
end
Hotbar.drawBoostIcon = drawBoostIcon

-- getRect function removed - hotbar no longer blocks UI interactions

return Hotbar
