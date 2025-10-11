local Progression = {}
Progression.__index = Progression

function Progression.new(props)
    props = props or {}
    local self = setmetatable({}, Progression)
    self.level = props.level or 1
    self.xp = props.xp or 0
    self.gc = props.gc or 0
    return self
end

function Progression:addXP(amount)
    amount = amount or 0
    self.xp = self.xp + amount
    local leveledUp = false
    while self.xp >= self.level * 100 do
        self.xp = self.xp - self.level * 100
        self.level = self.level + 1
        leveledUp = true
    end
    return leveledUp
end

function Progression:addGC(amount)
    amount = amount or 0
    self.gc = math.max(0, self.gc + amount)
    return self.gc
end

function Progression:spendGC(amount)
    amount = amount or 0
    if self.gc >= amount then
        self.gc = self.gc - amount
        return true
    end
    return false
end

function Progression:serialize()
    return {
        level = self.level,
        xp = self.xp,
        gc = self.gc,
    }
end

function Progression.deserialize(data)
    if not data then return Progression.new() end
    return Progression.new{
        level = data.level,
        xp = data.xp,
        gc = data.gc,
    }
end

return Progression
