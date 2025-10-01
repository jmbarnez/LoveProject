local Content = require("src.content.content")
local Config = require("src.content.config")

local QuestGenerator = {}

local function randRange(a, b)
  return a + math.random(0, b - a)
end

local function makeId(prefix)
  return string.format("%s_%d_%d", prefix, os.time(), math.random(1000, 9999))
end

local function pluralize(name)
  if not name then return "" end
  if name:match("[sS]$") then return name end
  return name .. "s"
end

local function buildKillQuest(opts)
  local target = opts.target or "basic_drone"
  local ship = Content.getShip(target)
  local label = ship and ship.name or target
  local count = opts.count or randRange(6, 14)
  local rewardXP = opts.rewardXP or (15 * count)
  local title = string.format("Destroy %d %s", count, pluralize(label))
  local desc = string.format("Eliminate %d hostile %s patrolling nearby lanes.", count, pluralize(label):lower())

  return {
    id = makeId("pq_kill_" .. target .. "_" .. count),
    title = title,
    description = desc,
    objective = { type = "kill", target = target, count = count },
    reward = {
      gc = math.floor(count * 15 + math.random(50, 150)), -- GC reward based on difficulty
      xp = rewardXP,
      items = {
        { id = "reward_crate_key", qty = 1 }
      }
    }
  }
end

local function buildMineQuest(opts)
  local target = opts.target or "ore_tritanium"
  local item = Content.getItem(target)
  local itemName = (item and item.name) or target
  local count = opts.count or randRange(12, 28)
  local rewardXP = opts.rewardXP or (12 * count)
  local title = string.format("Mine %d %s", count, itemName)
  local desc = string.format("Extract %d units of %s from asteroids in the sector.", count, itemName)

  return {
    id = makeId("pq_mine_" .. target .. "_" .. count),
    title = title,
    description = desc,
    objective = { type = "mine", target = target, count = count },
    reward = {
      gc = math.floor(count * 8 + math.random(30, 100)), -- GC reward for mining
      xp = rewardXP,
      items = {
        { id = "reward_crate_key", qty = 1 }
      }
    }
  }
end

local function buildSalvageQuest(opts)
  local resource = opts.target or "scraps"
  local item = Content.getItem(resource)
  local itemName = (item and item.name) or resource
  local count = opts.count or randRange(6, 16)
  local rewardXP = opts.rewardXP or (14 * count)
  local title = string.format("Salvage %d Wrecks", count)
  local desc = string.format("Recover %d loads of %s from wreckage fields.", count, itemName)

  return {
    id = makeId("pq_salvage_" .. resource .. "_" .. count),
    title = title,
    description = desc,
    objective = { type = "salvage", target = resource, count = count },
    reward = {
      gc = math.floor(count * 12 + math.random(40, 120)), -- GC reward for salvaging
      xp = rewardXP,
      items = {
        { id = "reward_crate_key", qty = 1 }
      }
    }
  }
end

function QuestGenerator.generateQuest(player)
  local roll = math.random()
  local thresholds = {
    { limit = 0.4, build = function()
        local droneCount = randRange(8, 18)
        return buildKillQuest({ count = droneCount })
      end },
    { limit = 0.75, build = function()
        local ore = (math.random() < 0.8) and "ore_tritanium" or "ore_palladium"
        local count = ore == "ore_tritanium" and randRange(14, 28) or randRange(10, 18)
        return buildMineQuest({ target = ore, count = count })
      end },
    { limit = 1.0, build = function()
        local count = randRange(8, 18)
        return buildSalvageQuest({ count = count })
      end }
  }

  for _, option in ipairs(thresholds) do
    if roll <= option.limit then
      return option.build()
    end
  end

  return buildKillQuest({})
end

-- Ensure a station has a quest board with the configured number of slots
function QuestGenerator.ensureBoard(station)
  if not station or not station.components or not station.components.station then return nil end
  local board = station.components.station.questBoard
  if not board then
    board = { slots = {} }
    station.components.station.questBoard = board
  end

  local desired = (Config.QUESTS and Config.QUESTS.STATION_SLOTS) or 3
  for i = 1, desired do
    board.slots[i] = board.slots[i] or { quest = nil, taken = false, cooldownUntil = nil }
    local slot = board.slots[i]
    -- If empty and no cooldown, generate a quest
    if not slot.quest and not slot.cooldownUntil then
      slot.quest = QuestGenerator.generateQuest()
      slot.taken = false
    end
  end
  return board
end

-- Tick board: refresh any slots whose cooldown has expired
function QuestGenerator.refresh(board)
  if not board or not board.slots then return end
  local now = love.timer and love.timer.getTime() or os.time()
  for i, slot in ipairs(board.slots) do
    if slot.cooldownUntil and now >= slot.cooldownUntil then
      slot.cooldownUntil = nil
      slot.quest = QuestGenerator.generateQuest()
      slot.taken = false
    elseif (not slot.quest) and (not slot.cooldownUntil) then
      slot.quest = QuestGenerator.generateQuest()
      slot.taken = false
    end
  end
end

-- Check if a quest slot should be replaced due to completion
function QuestGenerator.checkQuestCompletion(board, player)
  if not board or not board.slots or not player then return end
  local questLog = player.components and player.components.questLog
  if not questLog or not questLog.active then return end
  
  local now = love.timer and love.timer.getTime() or os.time()
  
  for i, slot in ipairs(board.slots) do
    if slot.quest and slot.taken then
      -- Check if this quest is no longer active (completed)
      local questStillActive = false
      for _, activeQuest in ipairs(questLog.active) do
        if activeQuest.id == slot.quest.id then
          questStillActive = true
          break
        end
      end
      
      -- If quest is no longer active, start 30-minute replacement timer
      if not questStillActive then
        slot.quest = nil
        slot.taken = false
        slot.cooldownUntil = now + (30 * 60) -- 30 minutes
      end
    end
  end
end

return QuestGenerator

