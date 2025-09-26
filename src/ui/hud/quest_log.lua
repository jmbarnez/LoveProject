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
  if not player then return end

  local quests = nil
  local questLog = player.components and player.components.questLog
  if questLog and questLog.active and #questLog.active > 0 then
    quests = questLog.active
  elseif player.active_quests and #player.active_quests > 0 then
    quests = player.active_quests
  end

  if not quests then return end

  local w, h = Viewport.getDimensions()
  local x = 20
  local y = h * 0.6
  for _, quest in ipairs(quests) do
    local progress = 0
    local ready = false
    if questLog then
      progress = questLog.progress[quest.id] or 0
      ready = questLog.readyTurnin[quest.id] or false
    end
    drawQuestEntry(x, y, quest, progress, ready)
    y = y + 32
  end
end

return QuestLogHUD
