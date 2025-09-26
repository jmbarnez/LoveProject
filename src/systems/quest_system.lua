local QuestSystem = {}
local Content = require("src.content.content")
local Log = require("src.core.log")
local QuestLog = require("src.components.quest_log")
local Progression = require("src.components.progression")

local function ensureQuestLog(player)
    if not player or not player.components then return nil end
    if not player.components.questLog then
        player.components.questLog = QuestLog.new()
    end
    return player.components.questLog
end

local function ensureProgression(player)
    if not player or not player.components then return nil end
    if not player.components.progression then
        player.components.progression = Progression.new()
    end
    return player.components.progression
end

function QuestSystem.init(player)
    ensureQuestLog(player)
    ensureProgression(player)
end

function QuestSystem.update(player)
    -- TODO: Implement quest update logic (check conditions, progress, etc.)
end

function QuestSystem.addQuest(player, quest)
    local questLog = ensureQuestLog(player)
    if not questLog or not quest then return end
    questLog:add(quest)
    questLog.progress[quest.id] = 0
    questLog.startTimes[quest.id] = love.timer.getTime()
end

function QuestSystem.removeQuest(player, quest)
    local questLog = ensureQuestLog(player)
    if not questLog or not quest then return end
    questLog:remove(quest.id)
end

function QuestSystem.addProgress(player, questId, amount)
    local questLog = ensureQuestLog(player)
    if not questLog then return end
    questLog.progress[questId] = (questLog.progress[questId] or 0) + (amount or 1)
end

function QuestSystem.complete(player, quest)
    if not quest then return end
    local questLog = ensureQuestLog(player)
    local progression = ensureProgression(player)
    if questLog then questLog:remove(quest.id) end
    if progression and quest.reward then
        if quest.reward.gc then progression:addGC(quest.reward.gc) end
        if quest.reward.xp then progression:addXP(quest.reward.xp) end
    end
end

function QuestSystem.serialize(player)
    local questLog = ensureQuestLog(player)
    return questLog and questLog:serialize()
end

function QuestSystem.deserialize(player, data)
    if not player or not player.components then return end
    player.components.questLog = QuestLog.deserialize(data)
end

return QuestSystem
