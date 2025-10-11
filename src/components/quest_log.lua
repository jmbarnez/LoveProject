local Util = require("src.core.util")

local QuestLog = {}
QuestLog.__index = QuestLog

function QuestLog.new(props)
    props = props or {}
    local self = setmetatable({}, QuestLog)
    self.active = props.active or {}
    self.progress = props.progress or {}
    self.startTimes = props.startTimes or {}
    self.readyTurnin = props.readyTurnin or {}
    self.killSeen = props.killSeen or {}
    return self
end

function QuestLog:add(quest)
    table.insert(self.active, Util.deepCopy(quest))
end

function QuestLog:remove(id)
    for i = #self.active, 1, -1 do
        if self.active[i].id == id then
            table.remove(self.active, i)
        end
    end
    self.progress[id] = nil
    self.startTimes[id] = nil
    self.readyTurnin[id] = nil
    self.killSeen[id] = nil
end

function QuestLog:serialize()
    return {
        active = Util.deepCopy(self.active),
        progress = Util.deepCopy(self.progress),
        startTimes = Util.deepCopy(self.startTimes),
        readyTurnin = Util.deepCopy(self.readyTurnin),
        killSeen = Util.deepCopy(self.killSeen),
    }
end

function QuestLog.deserialize(data)
    if not data then return QuestLog.new() end
    return QuestLog.new{
        active = Util.deepCopy(data.active or {}),
        progress = Util.deepCopy(data.progress or {}),
        startTimes = Util.deepCopy(data.startTimes or {}),
        readyTurnin = Util.deepCopy(data.readyTurnin or {}),
        killSeen = Util.deepCopy(data.killSeen or {}),
    }
end

return QuestLog
