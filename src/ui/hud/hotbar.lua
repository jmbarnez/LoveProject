local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local Content = require("src.content.content")
local HotbarSystem = require("src.systems.hotbar")
local Config = require("src.content.config")

local Hotbar = {}

local HotbarSelection = require("src.ui.hud.hotbar_selection")

local function pointInRect(px, py, r)
  return px >= r.x and py >= r.y and px <= r.x + r.w and py <= r.y + r.h
end

local function drawTurretIcon(kind, tracerColor, x, y, size)
  local turretDef = Content.getTurret(kind)
  if turretDef and turretDef.icon and type(turretDef.icon) == "userdata" then
    love.graphics.setColor(1, 1, 1, 1)
    local img = turretDef.icon
    local sx = size / img:getWidth()
    local sy = size / img:getHeight()
    love.graphics.draw(img, x, y, 0, sx, sy)
    return
  end

  local c = tracerColor or Theme.colors.accent
  local cx, cy = x + size*0.5, y + size*0.5
  if kind == 'mining_laser' then
    Theme.setColor(Theme.colors.bg3)
    love.graphics.rectangle('fill', x+8, cy-12, size-16, 24)
    Theme.setColor(c)
    love.graphics.rectangle('fill', cx-4, y+6, 8, size-12)
    Theme.setColor(Theme.withAlpha(c, 0.6))
    love.graphics.rectangle('fill', cx-5, y+5, 10, size-10)
    Theme.setColor(Theme.colors.warning)
    love.graphics.rectangle('fill', cx-4, y+6, 8, 6)
    Theme.setColor(Theme.colors.textSecondary)
    love.graphics.circle('fill', cx-6, cy+8, 2)
    love.graphics.circle('fill', cx, cy+10, 2)
    love.graphics.circle('fill', cx+6, cy+8, 2)
  elseif kind == 'laser' then
    Theme.setColor(Theme.colors.bg3)
    love.graphics.rectangle('fill', x+10, cy-10, size-20, 20)
    Theme.setColor(c)
    love.graphics.rectangle('fill', cx-3, y+8, 6, size-16)
    Theme.setColor(Theme.withAlpha(c, 0.4))
    love.graphics.rectangle('fill', cx-4, y+7, 8, size-14)
    Theme.setColor(Theme.colors.highlight)
    love.graphics.rectangle('fill', cx-3, y+8, 6, 4)
  elseif kind == 'missile' then
    Theme.setColor(Theme.colors.textSecondary)
    love.graphics.ellipse('fill', cx, cy, 10, 16)
    Theme.setColor(Theme.colors.danger)
    love.graphics.polygon('fill', cx-12, cy+6, cx-4, cy+2, cx-4, cy+10)
    love.graphics.polygon('fill', cx-12, cy-6, cx-4, cy-2, cx-4, cy-10)
    Theme.setColor(Theme.withAlpha(c, 0.8))
    love.graphics.circle('fill', cx+10, cy, 3)
    Theme.setColor(Theme.withAlpha(Theme.colors.warning, 0.6))
    love.graphics.circle('fill', cx+10, cy, 5)
  else
    Theme.setColor(Theme.colors.textSecondary)
    love.graphics.rectangle('fill', cx-12, cy-8, 18, 16)
    Theme.setColor(c)
    love.graphics.rectangle('fill', cx+6, cy-3, 12, 6)
    Theme.setColor(Theme.withAlpha(c, 0.6))
    love.graphics.rectangle('fill', cx+18, cy-2, 4, 4)
    Theme.setColor(Theme.colors.highlight)
    love.graphics.rectangle('fill', cx-10, cy-6, 10, 2)
  end
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

local function keyLabel(k)
  if not k then return "" end
  k = tostring(k)
  if k == 'lshift' or k == 'rshift' then return 'SHIFT' end
  if k == 'space' then return 'SPACE' end
  if k == 'mouse1' then return 'LMB' end
  if k == 'mouse2' then return 'RMB' end
  if #k == 1 then return k:upper() end
  return k:upper()
end

function Hotbar.draw(player)
  local sw, sh = Viewport.getDimensions()
  local size, gap = 52, 10
  local totalSlots = #HotbarSystem.slots
  local w = totalSlots * size + (totalSlots - 1) * gap
  local x = math.floor((sw - w) * 0.5)
  local y = sh - size - 42

  for i, slot in ipairs(HotbarSystem.slots) do
    local rx = x + (i - 1) * (size + gap)
    local ry = y

    Theme.setColor(Theme.colors.shadow)
    love.graphics.rectangle('fill', rx + 3, ry + 5, size, size)
    Theme.setColor(Theme.colors.bg2)
    love.graphics.rectangle('fill', rx, ry, size, size)

    local drewIcon = false
    if slot.item == "turret" then
      local primaryKind, primaryColor = 'gun', Theme.colors.accent
      if player and player.components and player.components.equipment and player.components.equipment.turrets then
        for _, turretSlot in ipairs(player.components.equipment.turrets) do
          if turretSlot and turretSlot.turret then
            primaryKind = turretSlot.turret.kind or turretSlot.turret.type or 'gun'
            primaryColor = (turretSlot.turret.tracer and turretSlot.turret.tracer.color) or Theme.colors.accent
            break
          end
        end
      end
      drawTurretIcon(primaryKind, primaryColor, rx + 4, ry + 4, size - 8)
      drewIcon = true
    elseif slot.item == "shield" then
      drawShieldIcon(rx + 4, ry + 4, size - 8, player and player.shieldChannel)
      drewIcon = true
    elseif type(slot.item) == 'string' and slot.item:match('^turret_slot_%d+$') then
      local idx = tonumber(slot.item:match('^turret_slot_(%d+)$'))
      if player and player.components and player.components.equipment and idx then
        local t
        for _, ts in ipairs(player.components.equipment.turrets) do
          if ts.slot == idx then t = ts.turret break end
        end
        if t then
          local kind = t.kind or 'gun'
          local col = (t.tracer and t.tracer.color) or Theme.colors.accent
          drawTurretIcon(kind, col, rx + 4, ry + 4, size - 8)
          drewIcon = true

          -- Draw heat bar for this turret
            if t and t.getHeatFactor then
                local heatFactor = t:getHeatFactor()
                if heatFactor > 0.01 then
                    local barY = ry - 8
                    local barWidth = size
                    local barHeight = 3
                    
                    -- Heat bar background
                    love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
                    love.graphics.rectangle('fill', rx, barY, barWidth, barHeight)
                    
                    -- Heat bar fill
                    local heatColor = {
                        1.0 - heatFactor * 0.3, -- Red increases with heat
                        0.8 - heatFactor * 0.6, -- Green decreases with heat
                        0.2, -- Blue stays low
                        0.8 -- High visibility
                    }
                    love.graphics.setColor(heatColor)
                    love.graphics.rectangle('fill', rx, barY, barWidth * heatFactor, barHeight)
                    
                    -- Overheat warning
                    if t.isOverheated then
                        local pulse = (math.sin(love.timer.getTime() * 8) + 1) / 2
                        love.graphics.setColor(1, 0.1, 0.1, 0.6 + pulse * 0.4)
                        love.graphics.rectangle('fill', rx, barY, barWidth, barHeight)
                    end
                    
                    -- Heat bar border
                    love.graphics.setColor(0.4, 0.4, 0.4, 1)
                    love.graphics.setLineWidth(1)
                    love.graphics.rectangle('line', rx, barY, barWidth, barHeight)
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
          local total = (Config.COMBAT and Config.COMBAT.SHIELD_COOLDOWN) or 5.0
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
            local fw = love.graphics.getFont():getWidth(text)
            -- shadow for readability
            love.graphics.setColor(0, 0, 0, 0.7)
            love.graphics.print(text, rx + size - fw - 5 + 1, ry + 5 + 1)
            Theme.setColor(Theme.colors.text)
            love.graphics.print(text, rx + size - fw - 5, ry + 5)
            if fOld then love.graphics.setFont(fOld) end
          end
        end
      elseif slot.item == 'turret' then
        -- Aggregate primary turret cooldown (max ratio across installed turrets)
        local best = 0
        local bestTime = 0
        if player.components and player.components.equipment and player.components.equipment.turrets then
          for _, tslot in ipairs(player.components.equipment.turrets) do
            local t = tslot and tslot.turret
            if t and (t.cooldown or 0) > 0 and (t.cycle or 0) > 0 then
              local pct = math.max(0, math.min(1, (t.cooldown or 0) / (t.cycle or 1)))
              if pct > best then best = pct end
              if (t.cooldown or 0) > bestTime then bestTime = (t.cooldown or 0) end
            end
          end
        end
        if best > 0 then
          local barHeight = math.floor(size * best)
          -- Use turret accent color if available from first turret
          local col = Theme.colors.accent
          love.graphics.setColor(col[1], col[2], col[3], 0.5)
          love.graphics.rectangle('fill', rx, ry + size - barHeight, size, barHeight)
          love.graphics.setColor(col[1], col[2], col[3], 0.85)
          love.graphics.setLineWidth(1)
          love.graphics.rectangle('line', rx, ry + size - barHeight, size, barHeight)

          -- Numeric cooldown (small text, top-right)
          if bestTime > 0 then
            local text = string.format("%.1f", bestTime)
            local fOld = love.graphics.getFont()
            if Theme.fonts and Theme.fonts.small then love.graphics.setFont(Theme.fonts.small) end
            local fw = love.graphics.getFont():getWidth(text)
            -- shadow for readability
            love.graphics.setColor(0, 0, 0, 0.7)
            love.graphics.print(text, rx + size - fw - 5 + 1, ry + 5 + 1)
            Theme.setColor(Theme.colors.text)
            love.graphics.print(text, rx + size - fw - 5, ry + 5)
            if fOld then love.graphics.setFont(fOld) end
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
    Theme.drawEVEBorder(rx, ry, size, size, 8, borderColor, 6)

    local label = keyLabel(HotbarSystem.getSlotKey and HotbarSystem.getSlotKey(i) or slot.key)
    local oldFont = love.graphics.getFont()
    if Theme.fonts and Theme.fonts.small then love.graphics.setFont(Theme.fonts.small) end
    Theme.setColor(Theme.withAlpha(Theme.colors.text, 0.95))
    love.graphics.printf(label, rx, ry + size - 12, size, 'center')
    if Theme.fonts and Theme.fonts.small and oldFont then love.graphics.setFont(oldFont) end
  end

  HotbarSelection.draw()
end

function Hotbar.mousepressed(player, mx, my, button)
  if HotbarSelection.mousepressed(mx, my, button) then return true end

  local sw, sh = Viewport.getDimensions()
  local size, gap = 52, 10
  local totalSlots = #HotbarSystem.slots
  local w = totalSlots * size + (totalSlots - 1) * gap
  local x = math.floor((sw - w) * 0.5)
  local y = sh - size - 42

  for i = 1, totalSlots do
    local rx = x + (i - 1) * (size + gap)
    local ry = y
    if pointInRect(mx, my, {x = rx, y = ry, w = size, h = size}) then
      HotbarSelection.show(i, rx + size / 2, ry, player)
      return true
    end
  end

  return false
end

Hotbar.drawTurretIcon = drawTurretIcon
Hotbar.drawBoostIcon = drawBoostIcon

function Hotbar.getRect()
  local sw, sh = Viewport.getDimensions()
  local size, gap = 52, 10
  local totalSlots = #HotbarSystem.slots
  local w = totalSlots * size + (totalSlots - 1) * gap
  local x = math.floor((sw - w) * 0.5)
  local y = sh - size - 42
  return { x = x, y = y, w = w, h = size }
end

return Hotbar
