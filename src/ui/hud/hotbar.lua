local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local Content = require("src.content.content")
local HotbarSystem = require("src.systems.hotbar")
local Config = require("src.content.config")

local Hotbar = {}

local HotbarSelection = require("src.ui.hud.hotbar_selection")

local function pointInRect(px, py, r)
  -- Handle nil values gracefully
  if px == nil or py == nil or r == nil or r.x == nil or r.y == nil or r.w == nil or r.h == nil then
    return false
  end
  return px >= r.x and py >= r.y and px <= r.x + r.w and py <= r.y + r.h
end


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
    elseif type(slot.item) == 'string' and slot.item:match('^turret_slot_%d+$') then
      local idx = tonumber(slot.item:match('^turret_slot_(%d+)$'))
      if player and player.components and player.components.equipment and player.components.equipment.grid and idx then
        local gridData = player.components.equipment.grid[idx]
        if gridData and gridData.type == "turret" and gridData.module then
          local t = gridData.module
          local subject = resolveTurretSubject(t, gridData.id)
          drawIcon({ subject, (t and t.id), "basic_gun" }, rx + 4, ry + 4, size - 8)
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

            -- Draw cooldown bar for this turret
            if t and t.cooldown and t.cooldown > 0 and t.cycle and t.cycle > 0 then
                local cooldownPct = math.max(0, math.min(1, t.cooldown / t.cycle))
                if cooldownPct > 0 then
                    local barHeight = math.floor(size * cooldownPct)
                    -- Use blue for cooldown bar
                    love.graphics.setColor(0.2, 0.6, 1.0, 0.7)
                    love.graphics.rectangle('fill', rx, ry + size - barHeight, size, barHeight)
                    love.graphics.setColor(0.4, 0.8, 1.0, 0.9)
                    love.graphics.setLineWidth(1)
                    love.graphics.rectangle('line', rx, ry + size - barHeight, size, barHeight)

                    -- Numeric cooldown
                    local text = string.format("%.1f", t.cooldown)
                    local fOld = love.graphics.getFont()
                    if Theme.fonts and Theme.fonts.small then love.graphics.setFont(Theme.fonts.small) end
                    local fw = love.graphics.getFont():getWidth(text)
                    local Theme = require("src.core.theme")
                    Theme.setColor(Theme.withAlpha(Theme.colors.shadow, 0.7))
                    love.graphics.print(text, rx + size - fw - 5 + 1, ry + 5 + 1)
                    Theme.setColor(Theme.colors.text)
                    love.graphics.print(text, rx + size - fw - 5, ry + 5)
                    if fOld then love.graphics.setFont(fOld) end
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
            local Theme = require("src.core.theme")
            Theme.setColor(Theme.withAlpha(Theme.colors.shadow, 0.7))
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
        if player.components and player.components.equipment and player.components.equipment.grid then
          for _, gridData in ipairs(player.components.equipment.grid) do
            if gridData.type == "turret" and gridData.module then
              local t = gridData.module
              if t and (t.cooldown or 0) > 0 and (t.cycle or 0) > 0 then
                local pct = math.max(0, math.min(1, (t.cooldown or 0) / (t.cycle or 1)))
                if pct > best then best = pct end
                if (t.cooldown or 0) > bestTime then bestTime = (t.cooldown or 0) end
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
            local fw = love.graphics.getFont():getWidth(text)
            -- shadow for readability
            local Theme = require("src.core.theme")
            Theme.setColor(Theme.withAlpha(Theme.colors.shadow, 0.7))
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
