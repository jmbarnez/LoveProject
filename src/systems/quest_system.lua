local QuestSystem = {}
local Events = require("src.core.events")
local QuestLog = require("src.components.quest_log")
local Progression = require("src.components.progression")

local function getObjectiveGoal(objective)
    if not objective then return nil end
    if objective.type == "timer" then
        return objective.duration or objective.time or objective.seconds or objective.count
    end
    return objective.count or objective.amount or objective.quantity or objective.targetCount or objective.required
end

local function findQuestById(questLog, questId)
    if not questLog or not questLog.active then return nil end
    for _, quest in ipairs(questLog.active) do
        if quest.id == questId then
            return quest
        end
    end
    return nil
end

local function isPlayerSource(player, source)
    if not source then return false end
    if source == player then return true end
    if source.isPlayer then return true end
    if source.components and source.components.player then return true end
    if source.owner then
        return isPlayerSource(player, source.owner)
    end
    return false
end

local function normalizeTargetList(target)
    if not target then return nil end
    if type(target) == "string" then
        return { target }
    elseif type(target) == "table" then
        local list = {}
        if target.id and type(target.id) == "string" then
            table.insert(list, target.id)
        end
        for _, value in ipairs(target) do
            if type(value) == "string" then
                table.insert(list, value)
            end
        end
        return list
    end
    return { tostring(target) }
end

local function targetMatches(target, candidates)
    if not target then return true end
    local normalized = normalizeTargetList(target)
    if not normalized or not candidates then return false end
    for _, candidate in ipairs(candidates) do
        if candidate then
            for _, expected in ipairs(normalized) do
                if candidate == expected then
                    return true
                end
            end
        end
    end
    return false
end

local function emitQuestUpdate(player, quest, questLog, target, progressChanged, readyChanged)
    if not quest or not quest.id then return end
    if not (progressChanged or readyChanged) then return end
    Events.emit(Events.GAME_EVENTS.QUEST_UPDATED, {
        questId = quest.id,
        quest = quest,
        player = player,
        progress = questLog.progress[quest.id] or 0,
        ready = questLog.readyTurnin[quest.id] or false,
        target = target
    })
end

local function updateQuestState(player, questLog, quest, opts)
    if not quest or not quest.id then return end
    local questId = quest.id
    questLog.progress[questId] = questLog.progress[questId] or 0
    local objective = quest.objective or {}
    local target = getObjectiveGoal(objective)
    local progress = questLog.progress[questId]

    local readyBefore = questLog.readyTurnin[questId] or false
    local readyNow = readyBefore

    if target and target > 0 then
        if progress >= target then
            if progress > target then
                questLog.progress[questId] = target
                progress = target
                if opts then opts.progressChanged = true end
            end
            readyNow = true
        else
            readyNow = false
        end
    elseif objective.type == "timer" then
        -- Timers without explicit duration shouldn't auto-complete
        readyNow = readyBefore
    end

    questLog.readyTurnin[questId] = readyNow

    local readyChanged = readyNow ~= readyBefore
    local progressChanged = opts and opts.progressChanged or false

    if readyChanged or progressChanged then
        emitQuestUpdate(player, quest, questLog, target, progressChanged, readyChanged)
    end
end

local function handleObjectiveEvent(player, eventName, data)
    if not player or not player.components then return end
    local questLog = player.components.questLog
    if not questLog or not questLog.active or #questLog.active == 0 then return end

    if eventName == Events.GAME_EVENTS.ENTITY_DESTROYED then
        if not data or not data.entity or not isPlayerSource(player, data.killedBy) then return end

        local entity = data.entity
        local candidates = {}
        if entity.shipId then table.insert(candidates, entity.shipId) end
        if entity.name then table.insert(candidates, entity.name) end
        if entity.type then table.insert(candidates, entity.type) end
        if entity.faction then table.insert(candidates, entity.faction) end

        for _, quest in ipairs(questLog.active) do
            local objective = quest.objective
            if objective and objective.type == "kill" then
                if targetMatches(objective.target, candidates) then
                    local questId = quest.id
                    questLog.killSeen[questId] = questLog.killSeen[questId] or {}
                    local seen = questLog.killSeen[questId]
                    local uniqueId = data.entityId or entity.id
                    if uniqueId and seen[uniqueId] then
                        goto continue_kill
                    end
                    if uniqueId then
                        seen[uniqueId] = true
                    end
                    QuestSystem.addProgress(player, questId, 1)
                end
            end
            ::continue_kill::
        end
    elseif eventName == Events.GAME_EVENTS.ASTEROID_MINED then
        if not data or (data.player and data.player ~= player) then return end
        local item = data.item
        local itemId = item and (item.id or item.name or item.type) or data.resourceId
        if not itemId then return end
        local amount = data.amount or 1
        if amount <= 0 then return end

        for _, quest in ipairs(questLog.active) do
            local objective = quest.objective
            if objective and objective.type == "mine" then
                if targetMatches(objective.target, { itemId }) then
                    QuestSystem.addProgress(player, quest.id, amount)
                end
            end
        end
    elseif eventName == Events.GAME_EVENTS.WRECKAGE_SALVAGED then
        if not data or (data.player and data.player ~= player) then return end
        local resourceId = data.resourceId or "scraps"
        local amount = data.amount or 1
        if amount <= 0 then return end

        for _, quest in ipairs(questLog.active) do
            local objective = quest.objective
            if objective and objective.type == "salvage" then
                if targetMatches(objective.target, { resourceId }) then
                    QuestSystem.addProgress(player, quest.id, amount)
                end
            end
        end
    end
end

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

    if not player then return end
    player._questEventSubscriptions = player._questEventSubscriptions or {}

    local subscriptions = player._questEventSubscriptions
    if #subscriptions == 0 then
        local function subscribe(eventName)
            local unsubscribe = Events.on(eventName, function(eventData)
                handleObjectiveEvent(player, eventName, eventData)
            end)
            table.insert(subscriptions, unsubscribe)
        end

        subscribe(Events.GAME_EVENTS.ENTITY_DESTROYED)
        subscribe(Events.GAME_EVENTS.ASTEROID_MINED)
        subscribe(Events.GAME_EVENTS.WRECKAGE_SALVAGED)
    end
end

function QuestSystem.update(player)
    local questLog = ensureQuestLog(player)
    if not questLog or not questLog.active then return end

    local now = love.timer and love.timer.getTime() or os.time()
    for _, quest in ipairs(questLog.active) do
        if quest and quest.id then
            questLog.progress[quest.id] = questLog.progress[quest.id] or 0
            questLog.readyTurnin[quest.id] = questLog.readyTurnin[quest.id] or false

            local objective = quest.objective or {}
            local progressChanged = false

            if objective.type == "timer" then
                local duration = getObjectiveGoal(objective)
                if duration and duration > 0 then
                    local startTime = questLog.startTimes[quest.id] or now
                    local elapsed = math.max(0, now - startTime)
                    local capped = math.min(duration, elapsed)
                    local previous = questLog.progress[quest.id]
                    if previous ~= capped then
                        questLog.progress[quest.id] = capped
                        if math.floor(previous) ~= math.floor(capped) then
                            progressChanged = true
                        end
                    end
                end
            end

            updateQuestState(player, questLog, quest, { progressChanged = progressChanged })
        end
    end
end

function QuestSystem.addQuest(player, quest)
    local questLog = ensureQuestLog(player)
    if not questLog or not quest then return end
    questLog:add(quest)
    questLog.progress[quest.id] = 0
    questLog.startTimes[quest.id] = love.timer.getTime()
    questLog.readyTurnin[quest.id] = false
    questLog.killSeen[quest.id] = {}

    player.active_quests = player.active_quests or {}
    table.insert(player.active_quests, quest)
end

function QuestSystem.removeQuest(player, quest)
    local questLog = ensureQuestLog(player)
    if not questLog or not quest then return end
    questLog:remove(quest.id)

    if player.active_quests then
        for i = #player.active_quests, 1, -1 do
            if player.active_quests[i].id == quest.id then
                table.remove(player.active_quests, i)
            end
        end
    end
end

function QuestSystem.startQuest(player, quest)
    if not player or not quest then return false end

    if QuestSystem.start then
        local result = QuestSystem.start(player, quest)
        if result then
            QuestSystem.addQuest(player, quest)
        end
        return result
    end

    QuestSystem.addQuest(player, quest)
    return true
end

function QuestSystem.completeQuest(player, quest)
    if not player or not quest then return false end

    if QuestSystem.complete then
        QuestSystem.complete(player, quest)
    end

    QuestSystem.removeQuest(player, quest)
    return true
end

function QuestSystem.addProgress(player, questId, amount)
    local questLog = ensureQuestLog(player)
    if not questLog then return end
    if not questId then return end

    local delta = amount or 1
    if delta == 0 then return end

    questLog.progress[questId] = questLog.progress[questId] or 0
    local current = questLog.progress[questId]
    local quest = findQuestById(questLog, questId)
    local objective = quest and quest.objective or nil
    local target = getObjectiveGoal(objective)

    if target and target > 0 and current >= target then
        return
    end

    local newValue = current + delta
    if target and target > 0 then
        newValue = math.min(newValue, target)
    end

    if newValue ~= current then
        questLog.progress[questId] = newValue
        if quest then
            updateQuestState(player, questLog, quest, { progressChanged = true })
        else
            Events.emit(Events.GAME_EVENTS.QUEST_UPDATED, {
                questId = questId,
                quest = nil,
                player = player,
                progress = newValue,
                ready = false,
                target = target
            })
        end
    end
end

function QuestSystem.isQuestReadyToTurnIn(player, quest)
    if not quest or not quest.id then return false end
    local questLog = ensureQuestLog(player)
    if not questLog then return false end
    return questLog.readyTurnin[quest.id] or false
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
