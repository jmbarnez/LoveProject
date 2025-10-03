local QuestLogHUD = {}
local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local Util = require("src.core.util")

local MAX_VISIBLE_QUESTS = 3

local function getMinimapLayout()
  local sw, sh = Viewport.getDimensions()
  local scale = math.min(sw / 1920, sh / 1080)
  local width = math.floor(220 * scale)
  local height = math.floor(160 * scale)
  local padding = math.floor(16 * scale)
  local x = sw - width - padding
  local y = padding
  return x, y, width, height, scale
end

local function getOverlayOrigin()
  local minimapX, minimapY, minimapW, minimapH, scale = getMinimapLayout()
  local timeFont = (Theme.fonts and Theme.fonts.xsmall) or love.graphics.getFont()
  local timeHeight = timeFont and timeFont:getHeight() or 0
  -- Account for time display with background padding (matches minimap.lua line 219)
  local timeDisplayHeight = timeHeight + 6 -- textHeight + 4 (top/bottom padding) + 2 (y offset)
  local belowTime = minimapY + minimapH + math.floor(8 * scale) + timeDisplayHeight
  local gap = math.max(8, math.floor(12 * scale))
  local originY = belowTime + gap
  return minimapX, originY, minimapW, scale
end

local function formatProgress(quest, progress, ready)
  if ready then
    return "Ready to turn in", Theme.colors.success
  end

  local objective = quest.objective
  if objective and objective.count then
    local target = objective.count
    if target and target > 0 then
      local current = math.max(0, progress or 0)
      local clamped = math.min(current, target)
      local percent = math.floor((clamped / target) * 100 + 0.5)
      local text = string.format("%d/%d (%d%%)", clamped, target, percent)
      return text, Theme.colors.textSecondary
    end
  end

  if type(progress) == "number" and progress > 0 then
    return string.format("%d%%", math.floor(progress + 0.5)), Theme.colors.textSecondary
  end

  return "In progress", Theme.colors.textSecondary
end

local function drawQuestCard(x, y, width, quest, progress, ready, scale, fonts)
  local padding = math.max(8, math.floor(12 * scale))
  local spacing = math.max(4, math.floor(6 * scale))
  local lineSpacing = math.max(2, math.floor(3 * scale))
  local maxDescLines = 2
  local description = quest.shortDescription or quest.description or ""
  local wrapped = {}
  if description ~= "" then
    wrapped = Util.wrapText(description, width - padding * 2, fonts.body)
  end

  local visibleLines = {}
  for i = 1, math.min(#wrapped, maxDescLines) do
    visibleLines[i] = wrapped[i]
  end

  local descCount = #visibleLines
  local entryHeight = padding + fonts.title:getHeight() + spacing
  if descCount > 0 then
    entryHeight = entryHeight + (descCount * fonts.body:getHeight()) + ((descCount - 1) * lineSpacing) + spacing
  else
    entryHeight = entryHeight + spacing
  end
  entryHeight = entryHeight + fonts.meta:getHeight() + padding
  entryHeight = math.max(entryHeight, math.floor(72 * scale))

  Theme.drawGradientGlowRect(x, y, width, entryHeight, 6,
    Theme.colors.bg2, Theme.colors.bg1, Theme.colors.accent, Theme.effects.glowWeak * 0.12)
  Theme.drawEVEBorder(x, y, width, entryHeight, 6,
    Theme.colors.border, 3)

  local textX = x + padding
  local textY = y + padding
  love.graphics.setFont(fonts.title)
  Theme.setColor(ready and Theme.colors.success or Theme.colors.textHighlight)
  love.graphics.print(quest.title or quest.name or quest.id or "Quest", textX, textY)

  textY = textY + fonts.title:getHeight() + spacing
  if descCount > 0 then
    love.graphics.setFont(fonts.body)
    Theme.setColor(Theme.colors.textSecondary)
    for _, line in ipairs(visibleLines) do
      love.graphics.print(line, textX, textY)
      textY = textY + fonts.body:getHeight() + lineSpacing
    end
    textY = textY + math.max(0, spacing - lineSpacing)
  end

  local progressText, progressColor = formatProgress(quest, progress, ready)
  love.graphics.setFont(fonts.meta)
  Theme.setColor(progressColor)
  local progressY = y + entryHeight - padding - fonts.meta:getHeight()
  love.graphics.print(progressText, textX, progressY)

  return entryHeight
end

function QuestLogHUD.draw(player)
  if not player then return end

  local quests = nil
  local questLog = player.components and player.components.questLog
  if questLog and questLog.active and #questLog.active > 0 then
    quests = questLog.active
  elseif player.active_quests and #player.active_quests > 0 then
    quests = player.active_quests
  end

  if not quests or #quests == 0 then return end

  local overlayX, overlayY, overlayWidth, scale = getOverlayOrigin()
  local oldFont = love.graphics.getFont()
  local fonts = {
    header = (Theme.fonts and Theme.fonts.small) or oldFont,
    title = (Theme.fonts and Theme.fonts.small) or oldFont,
    body = (Theme.fonts and Theme.fonts.xsmall) or oldFont,
    meta = (Theme.fonts and Theme.fonts.xsmall) or oldFont,
  }

  local headerPadding = math.max(8, math.floor(12 * scale))
  local headerHeight = math.max(math.floor(32 * scale), fonts.header:getHeight() + headerPadding * 2)


  Theme.drawGradientGlowRect(overlayX, overlayY, overlayWidth, headerHeight, 6,
    Theme.colors.bg1, Theme.colors.bg0, Theme.colors.accent, Theme.effects.glowWeak * 0.18)
  Theme.drawEVEBorder(overlayX, overlayY, overlayWidth, headerHeight, 6,
    Theme.withAlpha(Theme.colors.border, 0.7), 2)

  love.graphics.setFont(fonts.header)
  Theme.setColor(Theme.colors.textHighlight)
  love.graphics.print("Active Quests", overlayX + headerPadding, overlayY + headerPadding)

  local nextY = overlayY + headerHeight + math.max(6, math.floor(10 * scale))
  local displayed = 0
  for _, quest in ipairs(quests) do
    if displayed >= MAX_VISIBLE_QUESTS then break end
    local progress = 0
    local ready = false
    if questLog then
      progress = questLog.progress[quest.id] or 0
      ready = questLog.readyTurnin[quest.id] or false
    end
    local cardHeight = drawQuestCard(overlayX, nextY, overlayWidth, quest, progress, ready, scale, fonts)
    nextY = nextY + cardHeight + math.max(6, math.floor(10 * scale))
    displayed = displayed + 1
  end

  if oldFont then love.graphics.setFont(oldFont) end
end

return QuestLogHUD
