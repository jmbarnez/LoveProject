local EnemyLevel = {}
EnemyLevel.__index = EnemyLevel

function EnemyLevel.new(props)
    props = props or {}
    local self = setmetatable({}, EnemyLevel)
    
    -- Level range: 1-20 for normal enemies, 21+ for bosses
    self.level = props.level or 1
    self.isBoss = props.isBoss or false
    self.threatLevel = props.threatLevel or "normal" -- "low", "normal", "high", "boss"
    
    return self
end

function EnemyLevel:getThreatColor()
    if self.isBoss then
        return {0.8, 0.2, 0.8, 1.0} -- Purple for bosses
    elseif self.threatLevel == "high" then
        return {0.9, 0.3, 0.3, 1.0} -- Red for high threat
    elseif self.threatLevel == "normal" then
        return {0.9, 0.9, 0.3, 1.0} -- Yellow for normal threat
    else
        return {0.3, 0.9, 0.3, 1.0} -- Green for low threat
    end
end

function EnemyLevel:getDisplayText()
    if self.isBoss then
        return "Boss"
    else
        return "Lv." .. self.level
    end
end

function EnemyLevel:serialize()
    return {
        level = self.level,
        isBoss = self.isBoss,
        threatLevel = self.threatLevel
    }
end

function EnemyLevel.deserialize(data)
    if not data then return EnemyLevel.new() end
    return EnemyLevel.new{
        level = data.level,
        isBoss = data.isBoss,
        threatLevel = data.threatLevel
    }
end

return EnemyLevel
