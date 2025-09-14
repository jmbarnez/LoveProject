local Content = require("src.content.content")
local Config = require("src.content.config")

local QuestGenerator = {}

local function randRange(a, b)
  return a + math.random(0, b - a)
end

local function makeId(prefix)
  return string.format("%s_%d_%d", prefix, os.time(), math.random(1000, 9999))
end

-- Build a kill quest
local function buildKillQuest(opts)
  local count = opts.count or randRange(4, 10)
  local target = opts.target or "basic_drone"
  local title = string.format("Purge %d Drones", count)
  local desc = string.format("Eliminate %d %s in the sector.", count, (Content.getShip(target) and Content.getShip(target).name) or target)
  local rewardGC = 150 * count
  local rewardXP = 10 * count

  return {
    id = makeId("pq_kill_" .. target .. "_" .. count),
    title = title,
    description = desc,
    objective = { type = "kill", target = target, count = count },
    reward = { gc = rewardGC, xp = rewardXP }
  }
end

-- Build a mining quest
local function buildMineQuest(opts)
  local count = opts.count or randRange(8, 25)
  local target = opts.target or "ore_tritanium"
  local item = Content.getItem(target)
  local itemName = (item and item.name) or target
  local title = string.format("Mine %d %s", count, itemName)
  local desc = string.format("Extract %d units of %s from local asteroids.", count, itemName)
  local rewardGC = 50 * count
  local rewardXP = 6 * count

  return {
    id = makeId("pq_mine_" .. target .. "_" .. count),
    title = title,
    description = desc,
    objective = { type = "mine", target = target, count = count },
    reward = { gc = rewardGC, xp = rewardXP }
  }
end

-- Choose a random quest type based on simple weights
function QuestGenerator.generateQuest(player)
  local choices = {
    { w = 0.6, f = function() return buildKillQuest({}) end },
    { w = 0.4, f = function()
        -- Mine either tritanium (common) or palladium (rare)
        local ore = (math.random() < 0.75) and "ore_tritanium" or "ore_palladium"
        local count = ore == "ore_tritanium" and randRange(10, 24) or randRange(6, 14)
        return buildMineQuest({ target = ore, count = count })
      end },
  }

  local r = math.random()
  local acc = 0
  for _, c in ipairs(choices) do
    acc = acc + c.w
    if r <= acc then return c.f() end
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

return QuestGenerator

