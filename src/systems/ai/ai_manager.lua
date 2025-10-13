--[[
  AI Manager - Core AI System
  
  Hybrid utility-based + behavior tree AI system for all entities.
  Supports different AI types, roles, and behaviors based on equipment and context.
]]

local AIBehaviorTree = require("src.systems.ai.behavior_tree")
local AIUtility = require("src.systems.ai.utility")
local AIContext = require("src.systems.ai.context")
local AISquad = require("src.systems.ai.squad")
local Log = require("src.core.log")

local AIManager = {
    entities = {},           -- All AI entities
    squads = {},            -- Squad management
    globalContext = {},     -- Global game context
    updateQueue = {},       -- Entities to update this frame
    maxUpdatesPerFrame = 50 -- Performance limit
}

-- AI Entity Types
local AI_TYPES = {
    SCOUT = "scout",           -- Fast, evasive, reconnaissance
    FIGHTER = "fighter",       -- Aggressive, direct combat
    SUPPORT = "support",       -- Healing, buffing, defensive
    MINER = "miner",          -- Resource-focused, defensive
    BOSS = "boss",            -- Complex multi-phase combat
    CIVILIAN = "civilian",    -- Non-combat, trading, etc.
    PATROL = "patrol"         -- Basic patrol and guard duty
}

-- AI Roles (can be combined with types)
local AI_ROLES = {
    LEADER = "leader",         -- Squad leader, makes decisions
    WINGMAN = "wingman",       -- Follows leader, supports
    LONE_WOLF = "lone_wolf",   -- Independent operation
    ESCORT = "escort",         -- Protects specific target
    INTERCEPTOR = "interceptor" -- Fast response, hit and run
}

-- Initialize AI Manager
function AIManager.initialize()
    AIManager.entities = {}
    AIManager.squads = {}
    AIManager.globalContext = {
        gameTime = 0,
        playerPosition = {x = 0, y = 0},
        playerHealth = 1.0,
        playerThreat = 0.0,
        activeEnemies = 0,
        activeAllies = 0,
        sectorType = "space",
        resourcesAvailable = 0
    }
    AIManager.updateQueue = {}
    
    Log.info("AI Manager initialized with hybrid utility + behavior tree system")
end

-- Register an entity with the AI system
function AIManager.registerEntity(entity, aiType, aiRole, squadId)
    if not entity or not entity.components then
        Log.warn("Attempted to register invalid entity with AI system")
        return false
    end
    
    -- Create AI component if it doesn't exist
    if not entity.components.ai then
        entity.components.ai = {
            type = aiType or AI_TYPES.FIGHTER,
            role = aiRole or AI_ROLES.LONE_WOLF,
            squadId = squadId,
            behaviorTree = nil,
            utilitySystem = nil,
            context = {},
            memory = {},
            state = "idle",
            lastUpdate = 0,
            updateInterval = 0.1, -- Update every 100ms
            enabled = true
        }
    else
        -- Update existing AI component
        entity.components.ai.type = aiType or entity.components.ai.type
        entity.components.ai.role = aiRole or entity.components.ai.role
        entity.components.ai.squadId = squadId
    end
    
    -- Initialize AI systems for this entity
    AIManager.initializeEntityAI(entity)
    
    -- Add to entities list
    AIManager.entities[entity.id or tostring(entity)] = entity
    
    -- Add to squad if specified
    if squadId then
        AISquad.addEntityToSquad(squadId, entity)
    end
    
    Log.info("Registered entity %s as %s %s", entity.id or "unknown", aiType, aiRole)
    return true
end

-- Initialize AI systems for a specific entity
function AIManager.initializeEntityAI(entity)
    local ai = entity.components.ai
    if not ai then return end
    
    -- Create behavior tree based on AI type
    ai.behaviorTree = AIBehaviorTree.createTree(ai.type, ai.role)
    
    -- Create utility system
    ai.utilitySystem = AIUtility.createSystem(ai.type, ai.role)
    
    -- Initialize context
    ai.context = AIContext.createContext(entity)
    
    -- Initialize memory
    ai.memory = {
        lastKnownPlayerPos = nil,
        lastCombatTime = 0,
        preferredWeapon = nil,
        tacticalPosition = nil,
        squadMembers = {},
        enemies = {},
        allies = {}
    }
end

-- Update all AI entities
function AIManager.update(dt, world)
    AIManager.globalContext.gameTime = AIManager.globalContext.gameTime + dt
    
    -- Update global context
    AIManager.updateGlobalContext(world)
    
    -- Update squads first (for coordination)
    AISquad.updateAllSquads(dt, world, AIManager.globalContext)
    
    -- Update individual entities
    local updateCount = 0
    for entityId, entity in pairs(AIManager.entities) do
        if entity and entity.components and entity.components.ai and entity.components.ai.enabled then
            local ai = entity.components.ai
            
            -- Check if it's time to update this entity
            if AIManager.globalContext.gameTime - ai.lastUpdate >= ai.updateInterval then
                AIManager.updateEntity(entity, dt, world)
                ai.lastUpdate = AIManager.globalContext.gameTime
                updateCount = updateCount + 1
                
                -- Performance limit
                if updateCount >= AIManager.maxUpdatesPerFrame then
                    break
                end
            end
        end
    end
end

-- Update a single AI entity
function AIManager.updateEntity(entity, dt, world)
    local ai = entity.components.ai
    if not ai or not ai.enabled then return end
    
    -- Update context
    AIContext.updateContext(ai.context, entity, world, AIManager.globalContext)
    
    -- Update memory
    AIManager.updateEntityMemory(entity, world)
    
    -- Get utility scores for available actions
    local utilities = AIUtility.evaluateActions(ai.utilitySystem, ai.context, ai.memory)
    
    -- Select best action based on utilities
    local selectedAction = AIUtility.selectBestAction(utilities)
    
    -- Execute action using behavior tree
    if selectedAction and ai.behaviorTree then
        AIBehaviorTree.executeAction(ai.behaviorTree, selectedAction, entity, dt, world)
    end
end

-- Update entity memory
function AIManager.updateEntityMemory(entity, world)
    local ai = entity.components.ai
    if not ai then return end
    
    local pos = entity.components.position
    if not pos then return end
    
    -- Update last known player position
    local player = AIManager.globalContext.player
    if player and player.components and player.components.position then
        local playerPos = player.components.position
        local distance = math.sqrt((pos.x - playerPos.x)^2 + (pos.y - playerPos.y)^2)
        
        if distance < 1000 then -- Within detection range
            ai.memory.lastKnownPlayerPos = {x = playerPos.x, y = playerPos.y}
        end
    end
    
    -- Update combat memory
    if ai.state == "combat" then
        ai.memory.lastCombatTime = AIManager.globalContext.gameTime
    end
    
    -- Update squad members
    if ai.squadId then
        ai.memory.squadMembers = AISquad.getSquadMembers(ai.squadId)
    end
end

-- Update global context
function AIManager.updateGlobalContext(world)
    -- Find player
    local player = nil
    if world and world.entities then
        for _, entity in ipairs(world.entities) do
            if entity.isPlayer then
                player = entity
                break
            end
        end
    end
    
    if player then
        AIManager.globalContext.player = player
        if player.components and player.components.position then
            AIManager.globalContext.playerPosition = {
                x = player.components.position.x,
                y = player.components.position.y
            }
        end
        if player.components and player.components.hull then
            AIManager.globalContext.playerHealth = (player.components.hull.hp or 0) / (player.components.hull.maxHP or 100)
        end
    end
    
    -- Count active entities
    local enemyCount = 0
    local allyCount = 0
    
    for _, entity in pairs(AIManager.entities) do
        if entity and not entity.dead then
            if entity.isEnemy then
                enemyCount = enemyCount + 1
            elseif entity.isPlayer or entity.isRemotePlayer then
                allyCount = allyCount + 1
            end
        end
    end
    
    AIManager.globalContext.activeEnemies = enemyCount
    AIManager.globalContext.activeAllies = allyCount
end

-- Remove entity from AI system
function AIManager.unregisterEntity(entity)
    if not entity then return end
    
    local entityId = entity.id or tostring(entity)
    
    -- Remove from squad
    if entity.components and entity.components.ai and entity.components.ai.squadId then
        AISquad.removeEntityFromSquad(entity.components.ai.squadId, entity)
    end
    
    -- Remove from entities list
    AIManager.entities[entityId] = nil
    
    Log.info("Unregistered entity %s from AI system", entityId)
end

-- Get AI statistics
function AIManager.getStats()
    local stats = {
        totalEntities = 0,
        activeEntities = 0,
        squads = 0,
        byType = {},
        byRole = {}
    }
    
    for _, entity in pairs(AIManager.entities) do
        if entity and entity.components and entity.components.ai then
            stats.totalEntities = stats.totalEntities + 1
            if not entity.dead then
                stats.activeEntities = stats.activeEntities + 1
            end
            
            local ai = entity.components.ai
            stats.byType[ai.type] = (stats.byType[ai.type] or 0) + 1
            stats.byRole[ai.role] = (stats.byRole[ai.role] or 0) + 1
        end
    end
    
    stats.squads = AISquad.getSquadCount()
    
    return stats
end

-- Export constants
AIManager.AI_TYPES = AI_TYPES
AIManager.AI_ROLES = AI_ROLES

return AIManager
