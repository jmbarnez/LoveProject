local AI = {}
AI.__index = AI

-- Simple AI configuration - no complex intelligence levels
AI.BASIC_CONFIG = {
    detectionRange = 2400,    -- Simple radius-based detection
    chaseSpeed = 150,        -- Speed when actively chasing
    patrolSpeed = 60,        -- Speed when patrolling
    retreatHealthPercent = 0.25,  -- Retreat when health drops below 25%
    reactionTime = 0.5,      -- Time before reacting to damage
}

function AI.new(args)
    local ai = {}
    setmetatable(ai, AI)

    -- Simple basic configuration
    local config = AI.BASIC_CONFIG
    ai.detectionRange = (args and args.detectionRange) or config.detectionRange
    ai.chaseSpeed = config.chaseSpeed
    ai.patrolSpeed = config.patrolSpeed
    ai.retreatHealthPercent = config.retreatHealthPercent
    ai.reactionTime = config.reactionTime

    -- Basic AI state
    ai.state = "patrolling"  -- Start patrolling
    ai.target = nil
    ai.isHunting = false  -- Simple flag instead of complex states

    -- Store spawn position for patrolling
    ai.spawnPos = args.spawnPos or {x = 0, y = 0}
    ai.patrolCenter = args.patrolCenter or ai.spawnPos

    -- Simple patrol behavior
    ai.patrolAngle = math.random() * math.pi * 2
    ai.patrolTimer = 0
    ai.patrolDirection = 1

    -- Damage response
    ai.damagedByPlayer = false
    ai.lastDamageTime = 0

    return ai
end

-- Simple helper functions for basic AI
function AI:shouldReact(dt)
    return (love.timer.getTime() - (self.lastDamageTime or 0)) >= self.reactionTime
end

function AI:isPlayerInRange(playerPos, entityPos)
    local dx = playerPos.x - entityPos.x
    local dy = playerPos.y - entityPos.y
    local distance = math.sqrt(dx * dx + dy * dy)
    return distance <= self.detectionRange
end

return AI