-- AI Component Module
-- Provides baseline behaviour state for enemies with room to extend later

local AI = {}
AI.__index = AI

AI.STATE = {
    PATROL = "patrolling",
    CHASE = "hunting",
    ATTACK = "attacking",
}

AI.BASIC_CONFIG = {
    detectionRange = 1800,        -- How far enemies can sense the player
    attackRange = 650,            -- Preferred distance when attacking
    chaseSpeed = 160,             -- Movement speed while closing distance
    patrolSpeed = 80,             -- Slow drift during patrol
    reactionTime = 0.4,           -- Delay before reacting to new threats
    patrolRadius = 420,           -- Radius around patrol center
    lossBuffer = 280,             -- Extra distance before giving up chase
    targetMemory = 2.0,           -- Seconds to remember last seen target
}

local function clonePosition(pos)
    if not pos then
        return { x = 0, y = 0 }
    end
    return { x = pos.x or 0, y = pos.y or 0 }
end

function AI.new(args)
    args = args or {}
    local ai = setmetatable({}, AI)
    local config = AI.BASIC_CONFIG

    ai.detectionRange = args.detectionRange or config.detectionRange
    ai.attackRange = math.min(args.attackRange or config.attackRange, ai.detectionRange)
    ai.chaseSpeed = args.chaseSpeed or args.chase_speed or config.chaseSpeed
    ai.patrolSpeed = args.patrolSpeed or args.wanderSpeed or config.patrolSpeed
    ai.reactionTime = args.reactionTime or config.reactionTime
    ai.patrolRadius = args.patrolRadius or config.patrolRadius
    ai.lossBuffer = args.lossBuffer or config.lossBuffer
    ai.targetMemory = args.targetMemory or config.targetMemory

    ai.state = AI.STATE.PATROL
    ai.stateTime = 0
    ai.target = nil
    ai.isHunting = false
    ai.lastSeenTargetTime = nil
    ai.lastKnownTargetPos = nil

    ai.spawnPos = clonePosition(args.spawnPos)
    ai.patrolCenter = clonePosition(args.patrolCenter or ai.spawnPos)

    ai.patrolHeading = math.random() * math.pi * 2
    ai.patrolTimer = 0
    ai.patrolDuration = 0
    ai.patrolTarget = nil
    ai.attackOrbitDir = (math.random() < 0.5) and 1 or -1

    ai.damagedByPlayer = false
    ai.lastDamageTime = 0

    ai.intelligenceLevel = args.intelligenceLevel or 1
    ai.aggressiveType = args.aggressiveType or "standard"

    return ai
end

function AI:setState(newState)
    if self.state ~= newState then
        self.state = newState
        self.stateTime = 0
    end
    self.isHunting = (self.state == AI.STATE.CHASE or self.state == AI.STATE.ATTACK)
end

function AI:updateTimers(dt)
    self.stateTime = (self.stateTime or 0) + dt
    self.patrolTimer = (self.patrolTimer or 0) + dt
end

function AI:shouldReact()
    return (love.timer.getTime() - (self.lastDamageTime or 0)) >= (self.reactionTime or 0)
end

function AI:isPlayerInRange(playerPos, entityPos)
    local dx = playerPos.x - entityPos.x
    local dy = playerPos.y - entityPos.y
    return (dx * dx + dy * dy) <= (self.detectionRange * self.detectionRange)
end

function AI:rememberTarget()
    self.lastSeenTargetTime = love.timer.getTime()
end

function AI:hasFreshTargetMemory()
    if not self.lastSeenTargetTime then
        return false
    end
    return (love.timer.getTime() - self.lastSeenTargetTime) <= (self.targetMemory or 0)
end

return AI
