local Theme = require("src.core.theme")
local Content = require("src.content.content")
local Config = require("src.content.config")
local QuestSystem = require("src.systems.quest_system")
local QuestGenerator = require("src.content.quest_generator")
local Notifications = require("src.ui.notifications")
local Util = require("src.core.util")

local Quests = {}

function Quests:new()
  local o = {}
  setmetatable(o, self)
  self.__index = self
  o.buttons = {}
  o.station = nil -- assigned by DockedUI.show
  o.bountyRef = nil -- assigned by DockedUI.setBounty
  o.processingBounties = false
  o.processingStart = 0
  o.processingAmount = 0
  return o
end

local function drawRewardRow(quest, x, y)
  love.graphics.print("Reward:", x, y)
  local rewardX = x + 60
  local font = love.graphics.getFont()
  local fontHeight = font:getHeight()
  local iconSize = 12
  local textY = y + (iconSize - fontHeight) / 2
  if quest.reward.gc then
    Theme.drawCurrencyToken(rewardX, y, iconSize)
    Theme.setColor(Theme.colors.accentGold)
    love.graphics.print(quest.reward.gc, rewardX + 15, textY)
    rewardX = rewardX + 60
  end
  if quest.reward.xp then
    Theme.drawXPIcon(rewardX, y, iconSize)
    Theme.setColor(Theme.colors.success)
    love.graphics.print(quest.reward.xp, rewardX + 15, textY)
  end
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

  local startY = y + 10
  local slotH = 100
  local padding = 10
  local now = love.timer.getTime()

  love.graphics.setFont(Theme.fonts and Theme.fonts.medium or love.graphics.getFont())
  Theme.setColor(Theme.colors.textHighlight)
  love.graphics.print("Station Contracts", x + 10, startY)
  startY = startY + 20

  for i = 1, ((Config.QUESTS and Config.QUESTS.STATION_SLOTS) or 3) do
    local slot = board.slots[i]
    local cx, cy, cw, ch = x + 10, startY + (i - 1) * (slotH + padding), w - 20, slotH
    Theme.drawGradientGlowRect(cx, cy, cw, ch, 6, Theme.colors.bg2, Theme.colors.bg1, Theme.colors.border, Theme.effects.glowWeak)

    if slot.quest then
      local quest = slot.quest
      Theme.setColor(Theme.colors.text)
      love.graphics.setFont(Theme.fonts and Theme.fonts.medium or love.graphics.getFont())
      love.graphics.print(quest.title, cx + 10, cy + 8)
      Theme.setColor(Theme.colors.textSecondary)
      love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
      love.graphics.print(quest.description, cx + 10, cy + 28)
      Theme.setColor(Theme.colors.text)
      drawRewardRow(quest, cx + 10, cy + 48)

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

      local btnW, btnH = 120, 28
      local btnX, btnY = cx + cw - btnW - 10, cy + ch - btnH - 10

      if not isAccepted and not slot.taken then
        local Viewport = require("src.core.viewport")
        local mx, my = Viewport.getMousePosition()
        local hover = mx > btnX and mx < btnX + btnW and my > btnY and my < btnY + btnH
        Theme.drawGradientGlowRect(btnX, btnY, btnW, btnH, 4, hover and Theme.colors.primary or Theme.colors.bg3, Theme.colors.bg1, Theme.colors.border, Theme.effects.glowWeak)
        Theme.setColor(Theme.colors.text)
        love.graphics.printf("Accept", btnX, btnY + 6, btnW, "center")
        table.insert(self.buttons, { x = btnX, y = btnY, w = btnW, h = btnH, action = "accept", slot = i, quest = quest })
      elseif isAccepted and not readyTurnIn then
        Theme.setColor(Theme.colors.textDisabled)
        love.graphics.printf("In Progress", btnX, btnY + 6, btnW, "center")
      elseif isAccepted and readyTurnIn then
        local Viewport = require("src.core.viewport")
        local mx, my = Viewport.getMousePosition()
        local hover = mx > btnX and mx < btnX + btnW and my > btnY and my < btnY + btnH
        Theme.drawGradientGlowRect(btnX, btnY, btnW, btnH, 4, hover and Theme.colors.success or Theme.colors.bg3, Theme.colors.bg1, Theme.colors.border, Theme.effects.glowWeak)
        Theme.setColor(Theme.colors.textHighlight)
        love.graphics.printf("Turn In", btnX, btnY + 6, btnW, "center")
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

  -- Collect Bounties section (replaces active quests list)
  local buttonY = startY + ((Config.QUESTS and Config.QUESTS.STATION_SLOTS) or 3) * (slotH + padding) + 10
  local btnW, btnH = 180, 32
  local btnX = x + 10
  local btnY = buttonY

  local uncollected = (self.bountyRef and self.bountyRef.uncollected) or 0
  local enabled = uncollected > 0 and not self.processingBounties
  local mx, my = require("src.core.viewport").getMousePosition()
  local hover = mx > btnX and mx < btnX + btnW and my > btnY and my < btnY + btnH
  local bg = enabled and (hover and Theme.colors.primary or Theme.colors.bg3) or Theme.colors.bg1
  Theme.drawGradientGlowRect(btnX, btnY, btnW, btnH, 4, bg, Theme.colors.bg0, Theme.colors.border, Theme.effects.glowWeak)
  Theme.setColor(enabled and Theme.colors.textHighlight or Theme.colors.textSecondary)
  love.graphics.printf("Collect Bounties", btnX, btnY + 8, btnW, "center")

  -- Info text next to button
  Theme.setColor(Theme.colors.text)
  love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
  local info = string.format("Uncollected: %s GC", Util.formatNumber(uncollected))
  love.graphics.print(info, btnX + btnW + 12, btnY + 8)

  -- Store hit region
  table.insert(self.buttons, { x = btnX, y = btnY, w = btnW, h = btnH, action = "collect_bounties", enabled = enabled })
end

function Quests:update(dt)
  -- Board refresh handled in draw(); manage bounty processing animation
  if self.processingBounties then
    local now = love.timer.getTime()
    if now - (self.processingStart or 0) >= 1.2 then
      -- Complete payout
      if self.processingAmount and self.processingAmount > 0 and self.bountyRef then
        if self._player then
          self._player:addGC(self.processingAmount)
        end
        self.bountyRef.uncollected = 0
        Notifications.action("Payment received: +" .. Util.formatNumber(self.processingAmount) .. " GC")
      end
      self.processingBounties = false
      self.processingAmount = 0
      self.processingStart = 0
    end
  end
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
          -- Start cooldown timer for this slot
          local cooldown = (Config.QUESTS and Config.QUESTS.REFRESH_AFTER_TURNIN_SEC) or (15 * 60)
          slot.quest = nil
          slot.taken = false
          slot.cooldownUntil = (love.timer and love.timer.getTime() or os.time()) + cooldown
        end
        return true
      elseif btn.action == "collect_bounties" then
        if btn.enabled and self.bountyRef and (self.bountyRef.uncollected or 0) > 0 and not self.processingBounties then
          self.processingAmount = self.bountyRef.uncollected or 0
          self.processingStart = love.timer.getTime()
          self.processingBounties = true
          self._player = player
          Notifications.info("Processing bounties...")
        else
          -- Optionally inform no bounties
          if not self.processingBounties then
            Notifications.debug("No bounties to collect")
          end
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
