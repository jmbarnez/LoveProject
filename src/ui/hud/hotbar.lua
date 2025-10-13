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

local function resolveAbilitySubject(module, fallback)
  if not module then return fallback end
  -- For ability modules, the module IS the item definition
  if module.id then return module.id end
  return fallback
end

-- Generic slot type handlers
local slotHandlers = {
  turret = function(gridData, player, rx, ry, size)
    local t = gridData.module
    local subject = resolveTurretSubject(t, gridData.id)
    drawIcon({ subject, (t and t.id), "basic_gun" }, rx + 4, ry + 4, size - 8)
    return true
  end,
  
  ability = function(gridData, player, rx, ry, size)
    local module = gridData.module
    local subject = resolveAbilitySubject(module, gridData.id)
    drawIcon({ subject, "basic_gun" }, rx + 4, ry + 4, size - 8)
    return true
  end,
  
  movement = function(gridData, player, rx, ry, size)
    local module = gridData.module
    local subject = resolveAbilitySubject(module, gridData.id)
    drawIcon({ subject, "basic_gun" }, rx + 4, ry + 4, size - 8)
    return true
  end,
  
  shield = function(gridData, player, rx, ry, size)
    drawShieldIcon(rx + 4, ry + 4, size - 8, player and player.shieldChannel)
    return true
  end,
  
  -- Generic fallback for any module type
  module = function(gridData, player, rx, ry, size)
    local module = gridData.module
    local subject = resolveAbilitySubject(module, gridData.id)
    drawIcon({ subject, "basic_gun" }, rx + 4, ry + 4, size - 8)
    return true
  end
}

-- Generic function to handle equipment slots
local function drawEquipmentSlot(gridData, player, rx, ry, size)
  if not gridData or not gridData.module or not gridData.type then
    return false
  end
  
  local handler = slotHandlers[gridData.type]
  if handler then
    return handler(gridData, player, rx, ry, size)
  end
  
  -- Fallback to generic module handler
  handler = slotHandlers.module
  if handler then
    return handler(gridData, player, rx, ry, size)
  end
  
  return false
end

-- Cooldown handlers for different slot types
local cooldownHandlers = {
  module = function(gridData, player, rx, ry, size)
    if gridData.module and gridData.module.module then
      local moduleData = gridData.module.module
      if moduleData.ability_type == "dash" then
        local state = player.components.player_state
        if state and state.dash_cooldown and state.dash_cooldown > 0 then
          local dashConfig = require("src.content.config").DASH or {}
          local cooldown = dashConfig.COOLDOWN or 0.9
          local cooldownPct = math.max(0, math.min(1, state.dash_cooldown / cooldown))
          if cooldownPct > 0 then
            local barHeight = math.floor(size * cooldownPct)
            -- Use orange for dash cooldown bar
            love.graphics.setColor(0.8, 0.4, 0.1, 0.8)
            love.graphics.rectangle('fill', rx, ry + size - barHeight, size, barHeight)
            love.graphics.setColor(1.0, 0.6, 0.2, 1.0)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle('line', rx, ry + size - barHeight, size, barHeight)

            -- Numeric cooldown
            local text = string.format("%.1f", state.dash_cooldown)
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
  end,
  
  movement = function(gridData, player, rx, ry, size)
    if gridData.module and gridData.module.module then
      local moduleData = gridData.module.module
      if moduleData.ability_type == "dash" then
        local state = player.components.player_state
        if state and state.dash_cooldown and state.dash_cooldown > 0 then
          local dashConfig = require("src.content.config").DASH or {}
          local cooldown = dashConfig.COOLDOWN or 0.9
          local cooldownPct = math.max(0, math.min(1, state.dash_cooldown / cooldown))
          if cooldownPct > 0 then
            local barHeight = math.floor(size * cooldownPct)
            -- Use orange for dash cooldown bar
            love.graphics.setColor(0.8, 0.4, 0.1, 0.8)
            love.graphics.rectangle('fill', rx, ry + size - barHeight, size, barHeight)
            love.graphics.setColor(1.0, 0.6, 0.2, 1.0)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle('line', rx, ry + size - barHeight, size, barHeight)

            -- Numeric cooldown
            local text = string.format("%.1f", state.dash_cooldown)
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
  end
}

-- Generic function to handle cooldowns
local function drawCooldownOverlay(gridData, player, rx, ry, size)
  if not gridData then
    return false
  end
  
  -- Try specific handler first
  local handler = cooldownHandlers[gridData.type]
  if handler then
    handler(gridData, player, rx, ry, size)
    return true
  end
  
  -- Fallback to module handler
  handler = cooldownHandlers.module
  if handler then
    handler(gridData, player, rx, ry, size)
    return true
  end
  
  return false
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


local function drawRedX(x, y, size)
  local cx, cy = x + size * 0.5, y + size * 0.5
  local lineWidth = math.max(2, size * 0.08) -- Scale line width with slot size
  local lineLength = size * 0.6 -- X lines extend 60% of slot size
  
  love.graphics.setLineWidth(lineWidth)
  love.graphics.setColor(1, 0, 0, 0.9) -- Bright red with high opacity
  
  -- Draw X lines
  love.graphics.line(
    cx - lineLength/2, cy - lineLength/2,
    cx + lineLength/2, cy + lineLength/2
  )
  love.graphics.line(
    cx + lineLength/2, cy - lineLength/2,
    cx - lineLength/2, cy + lineLength/2
  )
  
  -- Reset line width
  love.graphics.setLineWidth(1)
end

function Hotbar.draw(player)
  local sw, sh = Viewport.getDimensions()
  local size, gap = 52, 10
  local totalSlots = #HotbarSystem.slots
  local w = totalSlots * size + (totalSlots - 1) * gap
  local x = math.floor((sw - w) * 0.5)
  local y = sh - size - 8 -- Much closer to bottom, just 8px above XP bar


  -- Status bars are now handled by hud_status_bars.lua


  for i, slot in ipairs(HotbarSystem.slots) do
    local rx = x + (i - 1) * (size + gap)
    local ry = y

    -- Check if slot is enabled (has an item)
    local isEnabled = slot.item ~= nil
    
    if isEnabled then
      Theme.setColor(Theme.colors.bg2) -- Pure black background for enabled slots
    else
      Theme.setColor(Theme.withAlpha(Theme.colors.bg2, 0.5)) -- Dimmed background for empty slots
    end
    love.graphics.rectangle('fill', rx, ry, size, size)

    local drewIcon = false
    if slot.item == "turret" then
      local subject = nil
      local turret = nil
      if player and player.components and player.components.equipment and player.components.equipment.grid then
        for _, gridData in ipairs(player.components.equipment.grid) do
          if gridData.type == "turret" and gridData.module then
            subject = resolveTurretSubject(gridData.module, gridData.id)
            turret = gridData.module
            break
          end
        end
      end
      drawIcon({ subject, "basic_gun" }, rx + 4, ry + 4, size - 8)
      drewIcon = true
      
      -- Draw heat bar above the slot for the first turret
      if turret and turret.getHeatStatus then
          local heatStatus = turret:getHeatStatus()
          if heatStatus.heatPercentage > 0 then
              -- Heat bar positioned above the slot
              local heatBarHeight = 4
              local heatBarY = ry - heatBarHeight - 2 -- 2px gap above slot
              local heatBarWidth = size
              local heatBarX = rx

              -- Heat bar background
              Theme.setColor(Theme.colors.bg1)
              love.graphics.rectangle('fill', heatBarX, heatBarY, heatBarWidth, heatBarHeight)

              -- Heat fill (orange when warm, red when hot)
              local heatPercentage = heatStatus.heatPercentage / 100
              local fillWidth = heatBarWidth * heatPercentage
              local heatColor = {1.0, 0.3, 0.1, 1.0} -- Red for heat
              if heatStatus.heatPercentage < 50 then
                  heatColor = {1.0, 0.6, 0.2, 1.0} -- Orange when cooler
              end
              Theme.setColor(heatColor)
              love.graphics.rectangle('fill', heatBarX, heatBarY, fillWidth, heatBarHeight)

              -- Overheat indicator (flashing red border)
              if heatStatus.isOverheated then
                  local flashAlpha = 0.5 + 0.5 * math.sin(love.timer.getTime() * 10)
                  Theme.setColor({1.0, 0.0, 0.0, flashAlpha})
                  love.graphics.setLineWidth(2)
                  love.graphics.rectangle('line', heatBarX, heatBarY, heatBarWidth, heatBarHeight)
              else
                  -- Normal border
                  Theme.setColor(Theme.colors.border)
                  love.graphics.setLineWidth(1)
                  love.graphics.rectangle('line', heatBarX, heatBarY, heatBarWidth, heatBarHeight)
              end
          end
      end
    elseif slot.item == "shield" then
      drawShieldIcon(rx + 4, ry + 4, size - 8, player and player.shieldChannel)
      drewIcon = true
    elseif type(slot.item) == 'string' and slot.item:match('^slot_%d+$') then
      local idx = tonumber(slot.item:match('^slot_(%d+)$'))

      if player and player.components and player.components.equipment and player.components.equipment.grid and idx then
        local gridData = player.components.equipment.grid[idx]
        if gridData and gridData.module then
          local t = gridData.module
          local moduleType = gridData.type
          
          -- Check if this is a turret slot
          local isTurret = (gridData.type == "turret")
          
          if isTurret then
            -- Handle weapon
            local subject = resolveTurretSubject(t, gridData.id)
            drawIcon({ subject, (t and t.id), "basic_gun" }, rx + 4, ry + 4, size - 8)
            drewIcon = true
          else
            -- Handle other modules (shields, etc.) using the modular system
            if drawEquipmentSlot(gridData, player, rx, ry, size) then
              drewIcon = true
            end
          end

          -- Draw heat bar above the slot for weapons only
          if isTurret and t and t.getHeatStatus then
              local heatStatus = t:getHeatStatus()
              if heatStatus.heatPercentage > 0 then
                  -- Heat bar positioned above the slot
                  local heatBarHeight = 4
                  local heatBarY = ry - heatBarHeight - 2 -- 2px gap above slot
                  local heatBarWidth = size
                  local heatBarX = rx

                  -- Heat bar background
                  Theme.setColor(Theme.colors.bg1)
                  love.graphics.rectangle('fill', heatBarX, heatBarY, heatBarWidth, heatBarHeight)

                  -- Heat fill (orange when warm, red when hot)
                  local heatPercentage = heatStatus.heatPercentage / 100
                  local fillWidth = heatBarWidth * heatPercentage
                  local heatColor = {1.0, 0.3, 0.1, 1.0} -- Red for heat
                  if heatStatus.heatPercentage < 50 then
                      heatColor = {1.0, 0.6, 0.2, 1.0} -- Orange when cooler
                  end
                  Theme.setColor(heatColor)
                  love.graphics.rectangle('fill', heatBarX, heatBarY, fillWidth, heatBarHeight)

                  -- Overheat indicator (flashing red border)
                  if heatStatus.isOverheated then
                      local flashAlpha = 0.5 + 0.5 * math.sin(love.timer.getTime() * 10)
                      Theme.setColor({1.0, 0.0, 0.0, flashAlpha})
                      love.graphics.setLineWidth(2)
                      love.graphics.rectangle('line', heatBarX, heatBarY, heatBarWidth, heatBarHeight)
                  else
                      -- Normal border
                      Theme.setColor(Theme.colors.border)
                      love.graphics.setLineWidth(1)
                      love.graphics.rectangle('line', heatBarX, heatBarY, heatBarWidth, heatBarHeight)
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

    -- Draw clip status above slot for gun weapons (only when weapon is equipped and has ammo)
    if player and slot.item and type(slot.item) == 'string' and slot.item:match('^slot_%d+$') then
      local idx = tonumber(slot.item:match('^slot_(%d+)$'))
      if player.components and player.components.equipment and player.components.equipment.grid and idx then
        local gridData = player.components.equipment.grid[idx]
        if gridData and gridData.module then
          local t = gridData.module
          -- Check if this is a turret slot
          local isTurret = (gridData.type == "turret")
          
          -- Only show ammo bar for weapons that require clips
          if isTurret then
            local handler = t and t.getHandler and t:getHandler()
            local config = handler and handler.config or {}
            if t and config.requiresClip and t.clipSize and t.clipSize > 0 then
              local clipStatus = t:getClipStatus()
              if clipStatus then
                -- Only show ammo bar if:
                -- 1. Currently reloading, OR
                -- 2. Ammo is low (less than 50%), OR  
                -- 3. Recently fired (has been used recently)
                local shouldShowAmmoBar = clipStatus.isReloading or 
                                         (clipStatus.current / clipStatus.max) < 0.5 or
                                         (t.lastFireTime and (love.timer.getTime() - t.lastFireTime) < 5.0)
                
                if shouldShowAmmoBar then
                  local barHeight = 4 -- Slim bar height
                  local barY = ry - barHeight - 2 -- Above the slot
                  local barWidth = size
                  local clipPct = clipStatus.current / clipStatus.max
                  
                  -- Clip bar background (dark)
                  love.graphics.setColor(0.1, 0.1, 0.1, 0.8)
                  love.graphics.rectangle('fill', rx, barY, barWidth, barHeight)
                  
                  -- Clip bar fill (depletes from right to left)
                  local fillWidth = math.floor(barWidth * clipPct)
                  local clipColor = {0.2, 0.8, 0.2, 1.0} -- Green
                  if clipPct < 0.3 then
                    clipColor = {0.8, 0.8, 0.2, 1.0} -- Yellow
                  end
                  if clipPct <= 0 then
                    clipColor = {0.8, 0.2, 0.2, 1.0} -- Red
                  end
                  
                  love.graphics.setColor(clipColor)
                  love.graphics.rectangle('fill', rx, barY, fillWidth, barHeight)
                  
                  -- Clip bar border
                  love.graphics.setColor(0.4, 0.4, 0.4, 1.0)
                  love.graphics.setLineWidth(1)
                  love.graphics.rectangle('line', rx, barY, barWidth, barHeight)
                  
                  -- Reloading text and use ammunition bar as progress
                  if clipStatus.isReloading then
                    local textY = barY - 16 -- Above the clip bar
                    local text = "Reloading..."
                    local fOld = love.graphics.getFont()
                    if Theme.fonts and Theme.fonts.small then love.graphics.setFont(Theme.fonts.small) end
                    local font = love.graphics.getFont()
                    local metrics = UIUtils.getCachedTextMetrics(text, font)
                    local fw = metrics.width
                    local fh = metrics.height
                    local tx = rx + (barWidth - fw) * 0.5 -- Center the text
                    
                    -- Text shadow
                    Theme.setColor(Theme.withAlpha(Theme.colors.shadow, 0.8))
                    love.graphics.print(text, tx + 1, textY + 1)
                    -- Text
                    Theme.setColor(Theme.colors.text)
                    love.graphics.print(text, tx, textY)
                    
                    -- Use the ammunition bar as reload progress bar
                    local reloadPct = clipStatus.reloadProgress
                    local progressWidth = math.floor(barWidth * reloadPct)
                    
                    -- Reload progress fill (yellow) on top of the clip bar
                    love.graphics.setColor(0.8, 0.8, 0.2, 1.0) -- Yellow
                    love.graphics.rectangle('fill', rx, barY, progressWidth, barHeight)
                    
                    if fOld then love.graphics.setFont(fOld) end
                  end
                end -- Close shouldShowAmmoBar condition
              end
            end
          end
        end
      end
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
      elseif type(slot.item) == 'string' and slot.item:match('^slot_%d+$') then
        -- Individual slot cooldown
        local idx = tonumber(slot.item:match('^slot_(%d+)$'))
        if player and player.components and player.components.equipment and player.components.equipment.grid and idx then
          local gridData = player.components.equipment.grid[idx]
          if gridData and gridData.module then
            local t = gridData.module
            
            -- Check if this is a weapon/turret module
            local isWeapon = false
            if gridData.module and gridData.module.module then
              isWeapon = gridData.module.module.type == "turret"
            elseif gridData.module and gridData.module.type then
              isWeapon = gridData.module.type == "turret"
            end
            
            if isWeapon and t and t.cooldown and t.cooldown > 0 then
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
            else
              -- Use modular cooldown system for non-turret modules
              drawCooldownOverlay(gridData, player, rx, ry, size)
            end
          end
        end
      elseif slot.item == 'turret' then
        -- Aggregate primary turret cooldown (max ratio across installed weapons that are not overheated)
        local best = 0
        local bestTime = 0
        if player.components and player.components.equipment and player.components.equipment.grid then
          for _, gridData in ipairs(player.components.equipment.grid) do
            if gridData.type == "turret" and gridData.module then
              local t = gridData.module
              if t and (t.cooldown or 0) > 0 then
                  local effectiveCycle = t.cycle or 1.0
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
          -- Use blue for weapon cooldown bar
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

      end
    end

    -- Draw red X overlay when weapons are disabled and slot hosts a turret
    local playerState = player and player.components and player.components.player_state
    if playerState and playerState.weapons_disabled and slot.item and type(slot.item) == 'string' and slot.item:match('^slot_%d+$') then
      local idx = tonumber(slot.item:match('^slot_(%d+)$'))
      if player and player.components and player.components.equipment and player.components.equipment.grid and idx then
        local gridData = player.components.equipment.grid[idx]
        if gridData and gridData.module then
          -- Check if this is a turret slot
          local isTurret = (gridData.type == "turret")
          
          if isTurret then
            drawRedX(rx, ry, size)
          end
        end
      end
    end

    -- Highlight border when active for hold-type actions (draw last so it's on top)
    local borderColor = Theme.colors.border
    if not isEnabled then
      -- Dim border for empty slots
      borderColor = Theme.withAlpha(Theme.colors.border, 0.3)
    elseif slot.item == 'shield' and (player and player.shieldChannel) then
      borderColor = Theme.colors.info
    elseif slot.item == 'boost' and (HotbarSystem.isActive and HotbarSystem.isActive('boost')) then
      borderColor = Theme.colors.warning
    end
    Theme.drawEVEBorder(rx, ry, size, size, 8, borderColor, 6)

    local label = UIUtils.formatKeyLabel(HotbarSystem.getSlotKey and HotbarSystem.getSlotKey(i) or slot.key)
    local oldFont = love.graphics.getFont()
    if Theme.fonts and Theme.fonts.small then love.graphics.setFont(Theme.fonts.small) end
    
    -- Adjust label color based on enabled state
    if isEnabled then
      Theme.setColor(Theme.withAlpha(Theme.colors.text, 0.95))
    else
      Theme.setColor(Theme.withAlpha(Theme.colors.text, 0.4))
    end
    love.graphics.printf(label, rx, ry + size - 16, size, 'center')
    if Theme.fonts and Theme.fonts.small and oldFont then love.graphics.setFont(oldFont) end
  end

end

function Hotbar.mousepressed(player, mx, my, button)
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


return Hotbar
