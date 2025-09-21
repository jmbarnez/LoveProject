local AI = {}
AI.__index = AI

-- AI Intelligence Level definitions
AI.INTELLIGENCE_LEVELS = {
    BASIC = {
        level = 1,
        name = "Basic Patrol",
        detectionRange = 1200,        -- Increased detection range
        engagementRange = 800,        -- When to start actively pursuing
        patrolRange = 1500,           -- How far to patrol from spawn
        reactionTime = 0.8,           -- Slower reaction for basic AI
        accuracy = 0.7,
        aggressiveness = 0.5,         -- Less aggressive
        evasion = 0.3,                -- Less evasive
        packCoordination = false,
        persistentHunting = false,
        retreatHealthPercent = 0.15,  -- Retreat earlier
        patrolSpeed = 80,             -- Slower patrol
        chaseSpeed = 120,             -- Moderate chase speed
    },
    STANDARD = {
        level = 2,
        name = "Standard Guard",
        detectionRange = 2000,        -- Much larger detection range
        engagementRange = 1200,       -- Engage at medium range
        patrolRange = 2500,           -- Patrol larger area
        reactionTime = 0.4,           -- Quick reaction
        accuracy = 0.8,
        aggressiveness = 0.8,
        evasion = 0.6,
        packCoordination = true,
        persistentHunting = true,
        retreatHealthPercent = 0.25,
        patrolSpeed = 100,            -- Good patrol speed
        chaseSpeed = 180,             -- Fast chase speed
    },
    ELITE = {
        level = 3,
        name = "Elite Hunter",
        detectionRange = 3000,        -- Very large detection range
        engagementRange = 2000,       -- Engage at long range
        patrolRange = 3500,           -- Patrol very large area
        reactionTime = 0.2,           -- Very quick reaction
        accuracy = 0.9,
        aggressiveness = 0.9,
        evasion = 0.8,
        packCoordination = true,
        persistentHunting = true,
        retreatHealthPercent = 0.3,
        patrolSpeed = 120,            -- Fast patrol speed
        chaseSpeed = 220,             -- Very fast chase speed
    },
    ACE = {
        level = 4,
        name = "Ace Pilot",
        detectionRange = 4000,        -- Massive detection range
        engagementRange = 3000,       -- Engage at extreme range
        patrolRange = 5000,           -- Patrol huge area
        reactionTime = 0.1,           -- Instant reaction
        accuracy = 0.95,
        aggressiveness = 1.0,
        evasion = 0.9,
        packCoordination = true,
        persistentHunting = true,
        retreatHealthPercent = 0.35,
        patrolSpeed = 140,            -- Very fast patrol
        chaseSpeed = 260,             -- Extremely fast chase
    }
}

function AI.new(args)
    local ai = {}
    setmetatable(ai, AI)

    -- Set intelligence level
    local intelligenceLevel = args.intelligenceLevel or "STANDARD"
    ai.intelligence = AI.INTELLIGENCE_LEVELS[intelligenceLevel] or AI.INTELLIGENCE_LEVELS.STANDARD

    ai.state = args.state or "patrolling"  -- Start with patrolling instead of idle
    ai.target = args.target or nil
    ai.range = ai.intelligence.detectionRange
    ai.aggressiveType = args.aggressiveType or "aggressive"  -- Default to aggressive for enemies

    -- Enhanced AI properties
    ai.hasSeenPlayer = false
    ai.lastReactionTime = 0
    ai.aggressionLevel = ai.intelligence.aggressiveness

    -- Patrol behavior - store spawn position for patrolling
    ai.spawnPos = args.spawnPos or {x = 0, y = 0}
    ai.patrolCenter = args.patrolCenter or ai.spawnPos
    ai.patrolRadius = ai.intelligence.patrolRange
    ai.patrolAngle = math.random() * math.pi * 2
    ai.patrolTimer = 0
    ai.patrolDirection = 1  -- 1 or -1 for direction changes

    -- Memory and search behavior
    ai.lastPlayerPos = nil
    ai.searchTimer = 0
    ai.searchDuration = 8  -- How long to search after losing target
    ai.memoryDuration = 15 -- How long to remember player position

    -- Formation/group behavior
    ai.formationPosition = args.formationPosition or nil
    ai.formationLeader = args.formationLeader or nil
    ai.groupMembers = args.groupMembers or {}

    -- Movement speeds from intelligence level
    ai.patrolSpeed = ai.intelligence.patrolSpeed
    ai.chaseSpeed = ai.intelligence.chaseSpeed

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