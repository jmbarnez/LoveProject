local Events = require("src.core.events")
local Log = require("src.core.log")

local QuestSystem = {}

-- Internal reference to player (set during init)
local currentPlayer = nil

-- Initialize quest system with player reference and event listeners
function QuestSystem.init(player)
  currentPlayer = player
  
  -- Ensure player has quest tracking structures
  if not player.active_quests then player.active_quests = {} end
  if not player.quest_progress then player.quest_progress = {} end
  if not player.quest_start_times then player.quest_start_times = {} end
  if not player.quest_ready_turnin then player.quest_ready_turnin = {} end
  if not player.quest_kill_seen then player.quest_kill_seen = {} end
  
  -- Set up event listeners for quest tracking
  Events.on(Events.GAME_EVENTS.ENTITY_DESTROYED, function(data)
    QuestSystem.handleEntityDestroyed(data)
  end)
  
  Events.on(Events.GAME_EVENTS.ITEM_PICKED_UP, function(data)
    QuestSystem.handleItemPickedUp(data)
  end)
  
  Events.on(Events.GAME_EVENTS.ASTEROID_MINED, function(data)
    QuestSystem.handleItemMined(data)
  end)
  
  Log.debug("Quest System initialized with event listeners")
end

-- Handle entity destruction for kill quests
function QuestSystem.handleEntityDestroyed(data)
  if not currentPlayer or not currentPlayer.active_quests then return end
  
  local entity = data.entity
  if not entity then return end
  local entityId = data.entityId or entity.id

  -- Defense-in-depth: dedupe repeated death events for the same entity
  if entityId then
    if currentPlayer.quest_kill_seen[entityId] then
      Log.debug("Skipping duplicate kill event for entity", entityId)
      return
    end
    currentPlayer.quest_kill_seen[entityId] = true
  end

  local shipId = entity.shipId -- Added by EntityFactory
  local currentTime = love.timer.getTime()
  
  if not shipId then return end -- Not a ship or no ID
  
  -- Check if this kill progresses any active quests
  for _, quest in ipairs(currentPlayer.active_quests) do
    if quest.objective.type == "kill" and quest.objective.target == shipId then
      -- Only count kills that happened AFTER the quest was started
      local questStartTime = currentPlayer.quest_start_times and currentPlayer.quest_start_times[quest.id]
      
      if not questStartTime then
        -- Quest has no start time (old save or bug), count it anyway but warn
        Log.warn("Quest", quest.id, "has no start time, allowing kill")
        questStartTime = 0
      end
      
      if currentTime >= questStartTime then
        local progress = currentPlayer.quest_progress[quest.id] or 0
        currentPlayer.quest_progress[quest.id] = progress + 1
        
        -- Emit quest progress event
        Events.emit(Events.GAME_EVENTS.QUEST_UPDATED, {
          quest = quest,
          progress = currentPlayer.quest_progress[quest.id],
          target = quest.objective.count
        })
        
        Log.debug(string.format("Quest progress: %s (%d/%d)", quest.title, 
              currentPlayer.quest_progress[quest.id], quest.objective.count))
      else
        -- Kill happened before quest started, ignore it
        Log.debug("Ignoring kill from before quest start:", quest.title)
      end
    end
  end
end

-- Handle item pickup for collection quests
function QuestSystem.handleItemPickedUp(data)
  if not currentPlayer or not currentPlayer.active_quests then return end
  
  local item = data.item
  if not item or not item.id then return end
  
  for _, quest in ipairs(currentPlayer.active_quests) do
    if quest.objective.type == "collect" and quest.objective.target == item.id then
      local progress = currentPlayer.quest_progress[quest.id] or 0
      local amount = data.amount or 1
      currentPlayer.quest_progress[quest.id] = progress + amount
      
      Events.emit(Events.GAME_EVENTS.QUEST_UPDATED, {
        quest = quest,
        progress = currentPlayer.quest_progress[quest.id],
        target = quest.objective.count
      })
      
      Log.debug(string.format("Quest progress: %s (%d/%d)", quest.title, 
            currentPlayer.quest_progress[quest.id], quest.objective.count))
    end
  end
end

-- Handle mining for mining quests
function QuestSystem.handleItemMined(data)
  if not currentPlayer or not currentPlayer.active_quests then return end
  
  local item = data.item
  if not item or not item.id then return end
  
  for _, quest in ipairs(currentPlayer.active_quests) do
    if quest.objective.type == "mine" and quest.objective.target == item.id then
      local progress = currentPlayer.quest_progress[quest.id] or 0
      local amount = data.amount or 1
      currentPlayer.quest_progress[quest.id] = progress + amount
      
      Events.emit(Events.GAME_EVENTS.QUEST_UPDATED, {
        quest = quest,
        progress = currentPlayer.quest_progress[quest.id],
        target = quest.objective.count
      })
      
      Log.debug(string.format("Quest progress: %s (%d/%d)", quest.title, 
            currentPlayer.quest_progress[quest.id], quest.objective.count))
    end
  end
end

-- Start a new quest
function QuestSystem.startQuest(player, quest)
  if not player.active_quests then player.active_quests = {} end
  if not player.quest_progress then player.quest_progress = {} end
  if not player.quest_start_times then player.quest_start_times = {} end
  
  -- Check if quest is already active
  for _, activeQuest in ipairs(player.active_quests) do
    if activeQuest.id == quest.id then
      Log.info("Quest already active:", quest.title)
      return false
    end
  end
  
  table.insert(player.active_quests, quest)
  player.quest_progress[quest.id] = 0
  -- Record when this quest was started
  player.quest_start_times[quest.id] = love.timer.getTime()
  
  Events.emit(Events.GAME_EVENTS.QUEST_STARTED, {
    quest = quest,
    player = player
  })
  
  Log.info("Started quest:", quest.title)
  return true
end

-- Complete a quest and give rewards
function QuestSystem.completeQuest(player, quest)
  player:addGC(quest.reward.gc or 0)
  player:addXP(quest.reward.xp or 0)
  
  -- Remove from active quests
  for i = #player.active_quests, 1, -1 do
    if player.active_quests[i].id == quest.id then
      table.remove(player.active_quests, i)
      break
    end
  end
  
  -- Clean up progress and timing tracking
  player.quest_progress[quest.id] = nil
  if player.quest_start_times then
    player.quest_start_times[quest.id] = nil
  end
  if player.quest_ready_turnin then
    player.quest_ready_turnin[quest.id] = nil
  end
  
  Events.emit(Events.GAME_EVENTS.QUEST_COMPLETED, {
    quest = quest,
    player = player,
    rewards = quest.reward
  })
  
  Log.info("Completed quest:", quest.title, "Rewards: GC=" .. (quest.reward.gc or 0) .. ", XP=" .. (quest.reward.xp or 0))
end

function QuestSystem.update(player)
  if not player.active_quests or #player.active_quests == 0 then
    return
  end

  -- Mark quests ready for turn-in when objectives are met (do not auto-complete)
  for i, quest in ipairs(player.active_quests) do
    local progress = player.quest_progress[quest.id] or 0
    if progress >= quest.objective.count then
      if not player.quest_ready_turnin[quest.id] then
        player.quest_ready_turnin[quest.id] = true
        Events.emit(Events.GAME_EVENTS.OBJECTIVE_COMPLETED, {
          quest = quest,
          player = player
        })
      end
    end
  end
end

function QuestSystem.isQuestReadyToTurnIn(player, quest)
  return player and quest and player.quest_ready_turnin and player.quest_ready_turnin[quest.id] == true
end

return QuestSystem
