local QuestLogHUD = {}
local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local Util = require("src.core.util")

local function drawQuestEntry(x, y, quest, progress, ready)
  Theme.setColor(ready and Theme.colors.success or Theme.colors.textHighlight)
  love.graphics.print(quest.name or quest.id, x, y)
  Theme.setColor(Theme.colors.textSecondary)
  love.graphics.print(progress .. "%", x, y + 16)
end

function QuestLogHUD.draw(player)
  if not player or not player.components or not player.components.questLog then return end
  local questLog = player.components.questLog
  if not questLog.active or #questLog.active == 0 then return end

  local w, h = Viewport.getDimensions()
  local x = 20
  local y = h * 0.6
  for _, quest in ipairs(questLog.active) do
    local progress = questLog.progress[quest.id] or 0
    local ready = questLog.readyTurnin[quest.id] or false
    drawQuestEntry(x, y, quest, progress, ready)
    y = y + 32
  end
end

return QuestLogHUD
