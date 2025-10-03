local Theme = require("src.core.theme")
local Content = require("src.content.content")
local Config = require("src.content.config")
local QuestSystem = require("src.systems.quest_system")
local QuestGenerator = require("src.content.quest_generator")
local Notifications = require("src.ui.notifications")
local Util = require("src.core.util")
local UIButton = require("src.ui.common.button")

local Quests = {}

function Quests:new()
  local o = {}
  setmetatable(o, self)
  self.__index = self
  o.buttons = {}
  o.station = nil -- assigned by DockedUI.show
  return o
end

local function drawRewardRow(quest, x, y, w)
  local font = love.graphics.getFont()
  local fontHeight = font:getHeight()
  local iconSize = 16
  local textY = y + (iconSize - fontHeight) / 2
  local rewardX = x
  local rewardSpacing = 8
  
  -- Draw reward label with better styling
  Theme.setColor(Theme.colors.textHighlight)
  love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
  love.graphics.print("Rewards:", x, y)
  rewardX = x + love.graphics.getFont():getWidth("Rewards:") + 12
  
  -- Draw all rewards in a clean row
  local rewards = {}
  
  -- Add GC reward if present
  if quest.reward.gc and quest.reward.gc > 0 then
    table.insert(rewards, {
      type = "gc",
      value = quest.reward.gc,
      icon = function(x, y) Theme.drawCurrencyToken(x, y, iconSize) end,
      color = Theme.colors.accentGold
    })
  end
  
  -- Add XP reward if present
  if quest.reward.xp and quest.reward.xp > 0 then
    table.insert(rewards, {
      type = "xp", 
      value = quest.reward.xp,
      icon = function(x, y) Theme.drawXPIcon(x, y, iconSize) end,
      color = Theme.colors.success
    })
  end
  
  -- Add item rewards if present
  if quest.reward.items and #quest.reward.items > 0 then
    for _, entry in ipairs(quest.reward.items) do
      local itemId = entry.id
      local qty = entry.qty or entry.count or entry.quantity or 1
      if itemId and qty > 0 then
        local itemDef = Content.getItem(itemId)
        local itemName = (itemDef and itemDef.name) or itemId
        table.insert(rewards, {
          type = "item",
          value = qty,
          name = itemName,
          icon = function(x, y) 
            -- Draw item icon if available
            local IconSystem = require("src.core.icon_system")
            IconSystem.drawIcon(itemId, x, y, iconSize, 1.0)
          end,
          color = Theme.colors.text
        })
      end
    end
  end
  
  -- Draw all rewards
  for i, reward in ipairs(rewards) do
    if rewardX + iconSize + 40 < x + w then -- Don't overflow
      -- Draw icon
      reward.icon(rewardX, y)
      
      -- Draw value
      Theme.setColor(reward.color)
      local valueText = reward.type == "item" and 
        string.format("%dx %s", reward.value, reward.name) or
        Util.formatNumber(reward.value)
      love.graphics.print(valueText, rewardX + iconSize + 4, textY)
      
      -- Move to next reward position
      rewardX = rewardX + iconSize + love.graphics.getFont():getWidth(valueText) + rewardSpacing + 8
    end
  end
  
  Theme.setColor(Theme.colors.text)
end

local function timeLeftText(seconds)
  local m = math.floor(seconds / 60)
  local s = math.floor(seconds % 60)
  return string.format("%02dm %02ds", m, s)
end

function Quests:draw(player, x, y, w, h)
  self.buttons = {}
  local station = self.station
  if not station then return end

  -- Ensure board exists and refresh timers
  local board = QuestGenerator.ensureBoard(station)
  QuestGenerator.refresh(board)
  QuestGenerator.checkQuestCompletion(board, player)

  local startY = y + 15
  local slotH = 120  -- Increased height for better layout
  local padding = 12
  local now = love.timer.getTime()

  -- Sleek header with better typography
  love.graphics.setFont(Theme.fonts and Theme.fonts.large or love.graphics.getFont())
  Theme.setColor(Theme.colors.accent)
  love.graphics.print("Station Contracts", x + 15, startY)
  startY = startY + 35

  for i = 1, ((Config.QUESTS and Config.QUESTS.STATION_SLOTS) or 3) do
    local slot = board.slots[i]
    local cx, cy, cw, ch = x + 15, startY + (i - 1) * (slotH + padding), w - 30, slotH
    
    -- Sleek transparent background with subtle glow
    local bgColor = Theme.withAlpha(Theme.colors.bg2, 0.3)
    Theme.drawGradientGlowRect(cx, cy, cw, ch, 8, bgColor, Theme.colors.bg1, Theme.colors.accent, Theme.effects.glowWeak * 0.3, false)
    
    -- Add prominent border around quest card
    Theme.drawEVEBorder(cx, cy, cw, ch, 8, Theme.colors.border, 3)

    if slot.quest then
      local quest = slot.quest
      
      -- Quest title with better typography
      Theme.setColor(Theme.colors.textHighlight)
      love.graphics.setFont(Theme.fonts and Theme.fonts.medium or love.graphics.getFont())
      love.graphics.print(quest.title, cx + 15, cy + 12)
      
      -- Quest description with better spacing
      Theme.setColor(Theme.colors.textSecondary)
      love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
      local descLines = {}
      local maxWidth = cw - 30
      local words = {}
      for word in quest.description:gmatch("%S+") do
        table.insert(words, word)
      end
      
      local currentLine = ""
      for _, word in ipairs(words) do
        local testLine = currentLine == "" and word or currentLine .. " " .. word
        if love.graphics.getFont():getWidth(testLine) <= maxWidth then
          currentLine = testLine
        else
          if currentLine ~= "" then
            table.insert(descLines, currentLine)
            currentLine = word
          else
            table.insert(descLines, word)
          end
        end
      end
      if currentLine ~= "" then
        table.insert(descLines, currentLine)
      end
      
      for j, line in ipairs(descLines) do
        if j <= 2 then -- Limit to 2 lines
          love.graphics.print(line, cx + 15, cy + 32 + (j - 1) * 16)
        end
      end
      
      -- Rewards section with better layout
      Theme.setColor(Theme.colors.text)
      drawRewardRow(quest, cx + 15, cy + 70, cw - 30)

      -- Determine slot/quest state for buttons
      local questLog = player and player.components and player.components.questLog
      local isAccepted = false
      local readyTurnIn = false
      if questLog and questLog.active then
        for _, aq in ipairs(questLog.active) do
          if aq.id == quest.id then
            isAccepted = true
            local readinessCheck = QuestSystem.isQuestReadyToTurnIn or QuestSystem.isReady
            readyTurnIn = readinessCheck and readinessCheck(player, quest) or false
            break
          end
        end
      end

      local btnW, btnH = 100, 32
      local btnX, btnY = cx + cw - btnW - 15, cy + ch - btnH - 15

      if not isAccepted and not slot.taken then
        local Viewport = require("src.core.viewport")
        local mx, my = Viewport.getMousePosition()
        local hover = mx > btnX and mx < btnX + btnW and my > btnY and my < btnY + btnH
        
        -- Use standard button definition
        UIButton.drawRect(btnX, btnY, btnW, btnH, "Accept", hover, love.timer.getTime(), { compact = true })
        table.insert(self.buttons, { x = btnX, y = btnY, w = btnW, h = btnH, action = "accept", slot = i, quest = quest })
      elseif isAccepted and not readyTurnIn then
        Theme.setColor(Theme.colors.textDisabled)
        love.graphics.printf("In Progress", btnX, btnY + 6, btnW, "center")
      elseif isAccepted and readyTurnIn then
        local Viewport = require("src.core.viewport")
        local mx, my = Viewport.getMousePosition()
        local hover = mx > btnX and mx < btnX + btnW and my > btnY and my < btnY + btnH
        
        -- Use standard button definition with success color
        UIButton.drawRect(btnX, btnY, btnW, btnH, "Turn In", hover, love.timer.getTime(), { compact = true, color = Theme.colors.success })
        table.insert(self.buttons, { x = btnX, y = btnY, w = btnW, h = btnH, action = "turnin", slot = i, quest = quest })
      else
        Theme.setColor(Theme.colors.textDisabled)
        love.graphics.printf("Unavailable", btnX, btnY + 6, btnW, "center")
      end
    else
      -- Cooldown state
      Theme.setColor(Theme.colors.textSecondary)
      love.graphics.setFont(Theme.fonts and Theme.fonts.medium or love.graphics.getFont())
      love.graphics.print("Slot Refreshing", cx + 10, cy + 8)
      if slot.cooldownUntil then
        local remaining = math.max(0, slot.cooldownUntil - now)
        Theme.setColor(Theme.colors.text)
        love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
        love.graphics.print("New contract in " .. timeLeftText(remaining), cx + 10, cy + 36)
      end
    end
  end

end

function Quests:update(dt)
  -- Board refresh handled in draw()
end

function Quests:mousepressed(player, x, y, button)
  if button ~= 1 then return false end
  if not self.station then return false end
  for _, btn in ipairs(self.buttons or {}) do
    if x > btn.x and x < btn.x + btn.w and y > btn.y and y < btn.y + btn.h then
      local board = self.station.components.station.questBoard
      local slot = board and board.slots and board.slots[btn.slot]
      if btn.action == "accept" and slot and slot.quest and not slot.taken then
        -- Tag quest with its source slot/station so UI logic can manage cooldown on turn-in
        slot.quest.source = { stationId = self.station.id, slot = btn.slot }
        if QuestSystem.startQuest(player, slot.quest) then
          slot.taken = true
        end
        return true
      elseif btn.action == "turnin" and slot and slot.quest then
        -- Only allow if truly complete
        local readinessCheck = QuestSystem.isQuestReadyToTurnIn or QuestSystem.isReady
        if readinessCheck and readinessCheck(player, slot.quest) then
          QuestSystem.completeQuest(player, slot.quest)
          -- Start 30-minute cooldown timer for this slot (auto-replacement)
          local cooldown = 30 * 60 -- 30 minutes in seconds
          slot.quest = nil
          slot.taken = false
          slot.cooldownUntil = (love.timer and love.timer.getTime() or os.time()) + cooldown
        end
        return true
      end
    end
  end
  return false
end

function Quests:mousereleased(player, x, y, button)
  return false
end

function Quests:mousemoved(player, x, y, dx, dy)
  return false
end

return Quests
