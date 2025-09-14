local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local Content = require("src.content.content")
local Util = require("src.core.util")

local Tooltip = {}

-- Draw a tooltip for a shop item
function Tooltip.drawShopTooltip(item, x, y)
  if not item then return end
  local oldFont = love.graphics.getFont()

  -- Gather item details
  local name = item.name or "Unknown Item"

  -- Tooltip dimensions and layout
  local maxWidth = 240
  local padding = 8

  -- Fonts
  local nameFont = Theme.fonts and Theme.fonts.medium or love.graphics.getFont()
  local statFont = Theme.fonts and Theme.fonts.small or love.graphics.getFont()

  -- Get item stats if available
  local stats = {}
  local fullItemDef = nil

  -- Try to find the complete item definition from Content
  if item.id then
    fullItemDef = Content.getItem(item.id) or Content.getTurret(item.id)
  else
    -- Fallback to item.data if it's a nested structure (like from shop items)
    fullItemDef = item.data or item
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
    if fullItemDef.turnRate then stats[#stats + 1] = {name = "Turn Rate", value = fullItemDef.turnRate} end
    if fullItemDef.tracking then stats[#stats + 1] = {name = "Tracking", value = fullItemDef.tracking} end
    if fullItemDef.sigRes then stats[#stats + 1] = {name = "Sig Res", value = fullItemDef.sigRes} end
    if fullItemDef.baseAccuracy then stats[#stats + 1] = {name = "Accuracy", value = math.floor(fullItemDef.baseAccuracy * 100) .. "%"} end
    if fullItemDef.health then stats[#stats + 1] = {name = "Health", value = fullItemDef.health} end
    if fullItemDef.shieldCapacity then stats[#stats + 1] = {name = "Shield", value = fullItemDef.shieldCapacity} end
    if fullItemDef.energyCapacity then stats[#stats + 1] = {name = "Energy", value = fullItemDef.energyCapacity} end

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

  -- Calculate height based on content
  local nameH = nameFont:getHeight()
  local statH = statFont:getHeight()
  local h = padding * 2 + nameH + 8
  if #stats > 0 then
    h = h + (#stats * (statH + 2)) + 4
  end

  -- Calculate width based on content
  local nameW = nameFont:getWidth(name)
  local w = nameW + padding * 2

  -- Check stat widths too
  for _, stat in ipairs(stats) do
    local statText = stat.name .. ": " .. tostring(stat.value)
    local statW = statFont:getWidth(statText)
    w = math.max(w, statW + padding * 2)
  end

  w = math.min(maxWidth, w)

  -- Positioning (keep on screen)
  local sw, sh = Viewport.getDimensions()
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
  currentY = currentY + nameH + 8

  -- Item stats
  if #stats > 0 then
    love.graphics.setFont(statFont)
    for _, stat in ipairs(stats) do
      local statText = stat.name .. ": " .. tostring(stat.value)
      Theme.setColor(Theme.colors.text)
      love.graphics.print(statText, tx + padding, currentY)
      currentY = currentY + statH + 2
    end
  end
  -- Restore prior font to avoid leaking font changes to the rest of the UI
  if oldFont then love.graphics.setFont(oldFont) end
end

return Tooltip
