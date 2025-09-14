local QuestLog = {}
local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")

function QuestLog:new()
  local o = {}
  setmetatable(o, self)
  self.__index = self
  return o
end

function QuestLog:draw(player)
  if not player.active_quests or #player.active_quests == 0 then
    return
  end

  local sw, sh = Viewport.getDimensions()
  local minimapW = 200
  local x = sw - minimapW - 10
  local y = 220 -- Positioned below the minimap
  local w = minimapW
  
  love.graphics.setFont(Theme.fonts.small)
  love.graphics.setColor(Theme.colors.text)
  love.graphics.print("Quest Log", x, y)
  y = y + 20

  for i, quest in ipairs(player.active_quests) do
    local progress = player.quest_progress[quest.id] or 0
    local ready = (player.quest_ready_turnin and player.quest_ready_turnin[quest.id]) or false
    local progress_text = ready and " (Turn in at station)" or string.format(" (%d/%d)", progress, quest.objective.count)
    love.graphics.print("- " .. quest.title .. progress_text, x, y)
    y = y + 15
  end
end

return QuestLog
