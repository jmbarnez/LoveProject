local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local Content = require("src.content.content")
local Util = require("src.core.util")

local Tooltip = {}

-- Draw a unified tooltip for any item, module, or turret
function Tooltip.drawItemTooltip(item, x, y)
  if not item then return end
  local oldFont = love.graphics.getFont()

  -- Gather item details
  local name = item.proceduralName or item.name or "Unknown Item"
  
  -- Add level indicator for leveled weapon modules
  if item.level and item.level > 1 then
    name = name .. " (Level " .. item.level .. ")"
  end

  -- Tooltip dimensions and layout (using theme configuration)
  local tooltipConfig = Theme.components and Theme.components.tooltip or {
    maxWidth = 500, minWidth = 150, padding = 8, screenMarginRatio = 0.8,
    nameLineSpacing = 8, statLineSpacing = 2, modifierHeaderSpacing = 8
  }
  local maxWidth = tooltipConfig.maxWidth
  local minWidth = tooltipConfig.minWidth
  local padding = tooltipConfig.padding

  -- Fonts
  local nameFont = Theme.fonts and Theme.fonts.medium or love.graphics.getFont()
  local statFont = Theme.fonts and Theme.fonts.small or love.graphics.getFont()

  -- Get item stats if available
  local stats = {}
  local fullItemDef = nil
  local description = ""
  local flavor = ""

  -- Try to find the complete item definition from Content
  if item.id then
    -- Check if this is a procedural turret (has baseId)
    if item.baseId then
      -- This is a procedural turret, use the item data directly
      fullItemDef = item
      description = item.description or ""
      flavor = item.flavor or ""
    else
      fullItemDef = Content.getItem(item.id) or Content.getTurret(item.id)
      if fullItemDef then
        description = fullItemDef.description or ""
        flavor = fullItemDef.flavor or ""
      end
    end
  else
    -- Fallback to item.data if it's a nested structure (like from shop items)
    fullItemDef = item.data or item
    if fullItemDef then
      description = fullItemDef.description or ""
      flavor = fullItemDef.flavor or ""
    end
  end

  if fullItemDef then
    -- Collect stats from the item definition
    if fullItemDef.damage then stats[#stats + 1] = {name = "Damage", value = fullItemDef.damage} end
    if fullItemDef.damageMin and fullItemDef.damageMax then
      stats[#stats + 1] = {name = "Damage", value = fullItemDef.damageMin .. "-" .. fullItemDef.damageMax}
    end
    if fullItemDef.optimal then stats[#stats + 1] = {name = "Range", value = fullItemDef.optimal .. (fullItemDef.falloff and " (" .. fullItemDef.falloff .. " falloff)" or "")} end
    if fullItemDef.cycle then stats[#stats + 1] = {name = "Cycle Time", value = fullItemDef.cycle .. "s"} end
    if fullItemDef.projectileSpeed then stats[#stats + 1] = {name = "Projectile Speed", value = fullItemDef.projectileSpeed} end
    if fullItemDef.capCost then stats[#stats + 1] = {name = "Energy Cost", value = fullItemDef.capCost} end
    if fullItemDef.baseAccuracy then stats[#stats + 1] = {name = "Accuracy", value = math.floor(fullItemDef.baseAccuracy * 100) .. "%"} end
    if fullItemDef.health then stats[#stats + 1] = {name = "Health", value = fullItemDef.health} end
    if fullItemDef.shieldCapacity then stats[#stats + 1] = {name = "Shield", value = fullItemDef.shieldCapacity} end
    if fullItemDef.energyCapacity then stats[#stats + 1] = {name = "Energy", value = fullItemDef.energyCapacity} end
    if fullItemDef.heatMax then stats[#stats + 1] = {name = "Heat Capacity", value = fullItemDef.heatMax} end
    if fullItemDef.heatPerShot then stats[#stats + 1] = {name = "Heat per Shot", value = fullItemDef.heatPerShot} end

    -- Add item properties
    if fullItemDef.rarity then stats[#stats + 1] = {name = "Rarity", value = fullItemDef.rarity} end
    if fullItemDef.tier then stats[#stats + 1] = {name = "Tier", value = fullItemDef.tier} end
    if fullItemDef.value then stats[#stats + 1] = {name = "Value", value = fullItemDef.value} end
    if fullItemDef.mass then stats[#stats + 1] = {name = "Mass", value = string.format("%.1f", fullItemDef.mass)} end
    if fullItemDef.volume then stats[#stats + 1] = {name = "Volume", value = string.format("%.1f", fullItemDef.volume)} end
    if fullItemDef.stack then stats[#stats + 1] = {name = "Stack Size", value = fullItemDef.stack} end

    -- Module-specific stats (from drawModuleTooltip)
    if fullItemDef.module and fullItemDef.module.shield_hp then
      stats[#stats+1] = { name = "Shield HP", value = fullItemDef.module.shield_hp }
    end
    if fullItemDef.module and fullItemDef.module.shield_regen then
      stats[#stats+1] = { name = "Shield Regen", value = fullItemDef.module.shield_regen .. "/s" }
    end
    if fullItemDef.module and fullItemDef.module.slot_type then
      stats[#stats+1] = { name = "Slot Type", value = fullItemDef.module.slot_type }
    end

    -- Special handling for turrets
    if fullItemDef.tracer and fullItemDef.tracer.color then
      local color = fullItemDef.tracer.color
      local colorName = "Unknown"
      if color[1] > 0.8 and color[2] > 0.8 then colorName = "Yellow"
      elseif color[1] > 0.8 then colorName = "Red"
      elseif color[2] > 0.8 then colorName = "Green"
      elseif color[3] > 0.8 then colorName = "Blue"
      end
      stats[#stats + 1] = {name = "Projectile", value = colorName}
    end
  end

  -- Get modifier information
  local modifiers = item.modifiers or {}

  -- Calculate height based on content
  local nameH = nameFont:getHeight()
  local statH = statFont:getHeight()
  local h = padding * 2 + nameH + tooltipConfig.nameLineSpacing

  -- Add description lines if present
  local descriptionLines = {}
  if description and description ~= "" then
    descriptionLines = Util.wrapText(description, maxWidth - padding * 2, statFont)
    h = h + (#descriptionLines * statH) + tooltipConfig.statLineSpacing
  end

  -- Add flavor text lines if present
  local flavorLines = {}
  if flavor and flavor ~= "" then
    flavorLines = Util.wrapText(flavor, maxWidth - padding * 2, statFont)
    h = h + (#flavorLines * statH) + tooltipConfig.statLineSpacing
  end

  -- Add stats section
  if #stats > 0 then
    h = h + (#stats * (statH + tooltipConfig.statLineSpacing)) + tooltipConfig.modifierHeaderSpacing
  end

  -- Add modifiers section
  if #modifiers > 0 then
    h = h + (#modifiers * (statH + tooltipConfig.statLineSpacing)) + tooltipConfig.modifierHeaderSpacing  -- Extra space for modifier header
  end

  -- Calculate width based on content
  local nameW = nameFont:getWidth(name)
  local w = nameW + padding * 2

  -- Check description and flavor text widths
  for _, line in ipairs(descriptionLines) do
    local lineW = statFont:getWidth(line)
    w = math.max(w, lineW + padding * 2)
  end
  for _, line in ipairs(flavorLines) do
    local lineW = statFont:getWidth(line)
    w = math.max(w, lineW + padding * 2)
  end

  -- Check stat widths too
  for _, stat in ipairs(stats) do
    local statText = stat.name .. ": " .. tostring(stat.value)
    local statW = statFont:getWidth(statText)
    w = math.max(w, statW + padding * 2)
  end

  -- Check modifier widths too
  for _, mod in ipairs(modifiers) do
    local changeText = ""
    if mod.type == "damage" then
      if mod.mult > 1 then
        changeText = "+" .. math.floor((mod.mult - 1) * 100) .. "% damage"
      else
        changeText = "-" .. math.floor((1 - mod.mult) * 100) .. "% damage"
      end
    elseif mod.type == "cooldown" then
      if mod.mult > 1 then
        changeText = "-" .. math.floor((mod.mult - 1) * 100) .. "% rate"
      else
        changeText = "+" .. math.floor((1 - mod.mult) * 100) .. "% rate"
      end
    elseif mod.type == "heat" then
      if mod.mult > 1 then
        changeText = "+" .. math.floor((mod.mult - 1) * 100) .. "% heat"
      else
        changeText = "-" .. math.floor((1 - mod.mult) * 100) .. "% heat"
      end
    end
    local modText = mod.name .. " (" .. changeText .. ")"
    local modW = statFont:getWidth(modText)
    w = math.max(w, modW + padding * 2)
  end

  -- Apply screen-aware width constraints
  local sw, sh = Viewport.getDimensions()
  local screenAwareMaxWidth = math.min(maxWidth, sw * tooltipConfig.screenMarginRatio)  -- Don't exceed configured ratio of screen width
  w = math.max(minWidth, math.min(screenAwareMaxWidth, w))

  -- Positioning (keep on screen)
  local tx = x + 20
  local ty = y
  if tx + w > sw then tx = x - w - 20 end
  if ty + h > sh then ty = sh - h end
  if ty < 0 then ty = 0 end

  tx = math.floor(tx)
  ty = math.floor(ty)

  -- Draw tooltip box
  Theme.drawGradientGlowRect(tx, ty, w, h, 8,
    Theme.colors.bg1, Theme.colors.bg0,
    Theme.colors.accent, Theme.effects.glowWeak)
  Theme.drawEVEBorder(tx, ty, w, h, 8, Theme.colors.border, 6)

  -- Current Y position for drawing text lines
  local currentY = ty + padding

  -- Item name
  love.graphics.setFont(nameFont)
  Theme.setColor(Theme.colors.textHighlight)
  love.graphics.print(name, tx + padding, currentY)
  currentY = currentY + nameH + tooltipConfig.nameLineSpacing

  -- Item description
  if #descriptionLines > 0 then
    love.graphics.setFont(statFont)
    Theme.setColor(Theme.colors.text)
    for _, line in ipairs(descriptionLines) do
      love.graphics.print(line, tx + padding, currentY)
      currentY = currentY + statH + 2
    end
    currentY = currentY + tooltipConfig.statLineSpacing
  end

  -- Item flavor text (in italics/secondary color)
  if #flavorLines > 0 then
    love.graphics.setFont(statFont)
    Theme.setColor(Theme.colors.textSecondary)
    for _, line in ipairs(flavorLines) do
      love.graphics.print(line, tx + padding, currentY)
      currentY = currentY + statH + 2
    end
    currentY = currentY + tooltipConfig.statLineSpacing
  end

  -- Item stats
  if #stats > 0 then
    love.graphics.setFont(statFont)
    for _, stat in ipairs(stats) do
      local statText = stat.name .. ": " .. tostring(stat.value)
      Theme.setColor(Theme.colors.text)
      love.graphics.print(statText, tx + padding, currentY)
      currentY = currentY + statH + tooltipConfig.statLineSpacing
    end
  end

  -- Item modifiers
  if #modifiers > 0 then
    currentY = currentY + tooltipConfig.modifierHeaderSpacing  -- Small gap before modifiers section
    love.graphics.setFont(statFont)
    Theme.setColor(Theme.colors.accent)
    love.graphics.print("Modifiers:", tx + padding, currentY)
    currentY = currentY + statH + tooltipConfig.modifierHeaderSpacing

    for _, mod in ipairs(modifiers) do
      local changeText = ""
      local modText = ""
      
      -- Handle new modifier system with rarity
      if mod.rarity then
        -- New modifier system with rarity
        modText = mod.name
        if mod.description then
          modText = modText .. " - " .. mod.description
        end
        
        -- Set color based on rarity
        if mod.rarity == "epic" then
          Theme.setColor({0.8, 0.2, 0.8, 1.0}) -- Purple
        elseif mod.rarity == "rare" then
          Theme.setColor({0.2, 0.6, 1.0, 1.0}) -- Blue
        elseif mod.rarity == "uncommon" then
          Theme.setColor({0.2, 0.8, 0.2, 1.0}) -- Green
        else
          Theme.setColor(Theme.colors.textSecondary) -- Common - default color
        end
      else
        -- Legacy modifier system
        if mod.type == "damage" then
          if mod.mult > 1 then
            changeText = "+" .. math.floor((mod.mult - 1) * 100) .. "% damage"
          else
            changeText = "-" .. math.floor((1 - mod.mult) * 100) .. "% damage"
          end
        elseif mod.type == "cooldown" then
          if mod.mult > 1 then
            changeText = "-" .. math.floor((mod.mult - 1) * 100) .. "% rate"
          else
            changeText = "+" .. math.floor((1 - mod.mult) * 100) .. "% rate"
          end
        elseif mod.type == "heat" then
          if mod.mult > 1 then
            changeText = "+" .. math.floor((mod.mult - 1) * 100) .. "% heat"
          else
            changeText = "-" .. math.floor((1 - mod.mult) * 100) .. "% heat"
          end
        end
        modText = mod.name .. " (" .. changeText .. ")"
        Theme.setColor(Theme.colors.textSecondary)
      end
      
      love.graphics.print(modText, tx + padding, currentY)
      currentY = currentY + statH + tooltipConfig.statLineSpacing
    end
  end

  -- Restore prior font to avoid leaking font changes to the rest of the UI
  if oldFont then love.graphics.setFont(oldFont) end
end

return Tooltip
