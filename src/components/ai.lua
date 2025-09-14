local AI = {}
AI.__index = AI

-- AI Intelligence Level definitions
AI.INTELLIGENCE_LEVELS = {
    BASIC = {
        level = 1,
        name = "Basic Patrol",
        detectionRange = 450,
        reactionTime = 0.8,
        accuracy = 0.6,
        aggressiveness = 0.5,
        evasion = 0.3,
        packCoordination = false,
        persistentHunting = false
    },
    STANDARD = {
        level = 2,
        name = "Standard Guard",
        detectionRange = 650,
        reactionTime = 0.5,
        accuracy = 0.75,
        aggressiveness = 0.7,
        evasion = 0.6,
        packCoordination = true,
        persistentHunting = true
    },
    ELITE = {
        level = 3,
        name = "Elite Hunter",
        detectionRange = 900,
        reactionTime = 0.3,
        accuracy = 0.85,
        aggressiveness = 0.9,
        evasion = 0.8,
        packCoordination = true,
        persistentHunting = true
    },
    ACE = {
        level = 4,
        name = "Ace Pilot",
        detectionRange = 1200,
        reactionTime = 0.1,
        accuracy = 0.95,
        aggressiveness = 1.0,
        evasion = 0.9,
        packCoordination = true,
        persistentHunting = true
    }
}

function AI.new(args)
    local ai = {}
    setmetatable(ai, AI)

    -- Set intelligence level
    local intelligenceLevel = args.intelligenceLevel or "STANDARD"
    ai.intelligence = AI.INTELLIGENCE_LEVELS[intelligenceLevel] or AI.INTELLIGENCE_LEVELS.STANDARD

    ai.state = args.state or "idle"
    ai.target = args.target or nil
    ai.range = ai.intelligence.detectionRange
    ai.aggressiveType = args.aggressiveType or "neutral"  -- "passive", "neutral", "aggressive", "hostile"
    
    
    -- Enhanced AI properties for persistent hunting
    ai.hasSeenPlayer = false
    ai.huntTime = 0
    ai.lastReactionTime = 0
    ai.aggressionLevel = ai.intelligence.aggressiveness
    
    -- Wander behavior defaults
    ai.wanderTimer = math.random() * 2 + 1
    ai.wanderDir = math.random() * math.pi * 2
    ai.wanderSpeed = (args.wanderSpeed or 80)
    
    return ai
end

-- Helper function to get AI level by name
function AI.getIntelligenceLevel(levelName)
    return AI.INTELLIGENCE_LEVELS[levelName] or AI.INTELLIGENCE_LEVELS.STANDARD
end

-- Helper function to check if AI should react to player detection
function AI.shouldReact(ai, dt)
    ai.lastReactionTime = (ai.lastReactionTime or 0) + dt
    return ai.lastReactionTime >= ai.intelligence.reactionTime
end

-- Helper function to determine if AI is aggressive type
function AI.isAggressive(ai)
    return ai.aggressiveType == "aggressive" or ai.aggressiveType == "hostile"
end

return AI
