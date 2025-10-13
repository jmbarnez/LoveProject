--[[
  AI Utility System
  
  Utility-based decision making for AI entities.
  Evaluates actions based on context and assigns utility scores.
]]

local Log = require("src.core.log")

local AIUtility = {}

-- Available actions for AI entities
local ACTIONS = {
    PATROL = "patrol",
    ENGAGE = "engage",
    RETREAT = "retreat",
    SUPPORT = "support",
    MINE = "mine",
    DOCK = "dock",
    FORMATION = "formation",
    INTERCEPT = "intercept",
    DEFEND = "defend",
    FLEE = "flee",
    IDLE = "idle"
}

-- Utility weights for different AI types
local UTILITY_WEIGHTS = {
    scout = {
        patrol = 0.8,
        engage = 0.3,
        retreat = 0.6,
        support = 0.4,
        mine = 0.1,
        dock = 0.2,
        formation = 0.5,
        intercept = 0.7,
        defend = 0.3,
        flee = 0.9,
        idle = 0.1
    },
    fighter = {
        patrol = 0.4,
        engage = 0.9,
        retreat = 0.3,
        support = 0.2,
        mine = 0.1,
        dock = 0.1,
        formation = 0.6,
        intercept = 0.8,
        defend = 0.4,
        flee = 0.2,
        idle = 0.1
    },
    support = {
        patrol = 0.3,
        engage = 0.4,
        retreat = 0.5,
        support = 0.9,
        mine = 0.2,
        dock = 0.3,
        formation = 0.8,
        intercept = 0.3,
        defend = 0.7,
        flee = 0.6,
        idle = 0.2
    },
    miner = {
        patrol = 0.6,
        engage = 0.2,
        retreat = 0.7,
        support = 0.1,
        mine = 0.9,
        dock = 0.8,
        formation = 0.3,
        intercept = 0.2,
        defend = 0.5,
        flee = 0.8,
        idle = 0.3
    },
    boss = {
        patrol = 0.2,
        engage = 0.8,
        retreat = 0.1,
        support = 0.1,
        mine = 0.0,
        dock = 0.0,
        formation = 0.3,
        intercept = 0.6,
        defend = 0.4,
        flee = 0.0,
        idle = 0.1
    },
    civilian = {
        patrol = 0.5,
        engage = 0.0,
        retreat = 0.9,
        support = 0.1,
        mine = 0.3,
        dock = 0.8,
        formation = 0.2,
        intercept = 0.0,
        defend = 0.1,
        flee = 0.9,
        idle = 0.6
    },
    patrol = {
        patrol = 0.8,
        engage = 0.6,
        retreat = 0.4,
        support = 0.3,
        mine = 0.2,
        dock = 0.5,
        formation = 0.7,
        intercept = 0.8,
        defend = 0.8,
        flee = 0.3,
        idle = 0.2
    }
}

-- Create utility system for an entity
function AIUtility.createSystem(aiType, aiRole)
    return {
        type = aiType,
        role = aiRole,
        weights = UTILITY_WEIGHTS[aiType] or UTILITY_WEIGHTS.fighter,
        modifiers = {}, -- Dynamic modifiers based on context
        lastUpdate = 0
    }
end

-- Evaluate all available actions and return utility scores
function AIUtility.evaluateActions(utilitySystem, context, memory)
    local utilities = {}
    
    for action, baseWeight in pairs(utilitySystem.weights) do
        local utility = baseWeight
        
        -- Apply context modifiers
        utility = utility * AIUtility.getContextModifier(action, context, memory)
        
        -- Apply role modifiers
        utility = utility * AIUtility.getRoleModifier(action, utilitySystem.role, context)
        
        -- Apply health modifiers
        utility = utility * AIUtility.getHealthModifier(action, context)
        
        -- Apply threat modifiers
        utility = utility * AIUtility.getThreatModifier(action, context, memory)
        
        -- Apply squad modifiers
        utility = utility * AIUtility.getSquadModifier(action, context, memory)
        
        -- Apply equipment modifiers
        utility = utility * AIUtility.getEquipmentModifier(action, context)
        
        -- Clamp utility between 0 and 1
        utilities[action] = math.max(0, math.min(1, utility))
    end
    
    return utilities
end

-- Select the best action based on utility scores
function AIUtility.selectBestAction(utilities)
    local bestAction = nil
    local bestScore = 0
    
    for action, score in pairs(utilities) do
        if score > bestScore then
            bestScore = score
            bestAction = action
        end
    end
    
    return bestAction, bestScore
end

-- Get context modifier for an action
function AIUtility.getContextModifier(action, context, memory)
    local modifier = 1.0
    
    -- Distance to player
    if context.distanceToPlayer then
        if action == "engage" or action == "intercept" then
            -- Prefer to engage when close
            if context.distanceToPlayer < 200 then
                modifier = modifier * 1.5
            elseif context.distanceToPlayer > 500 then
                modifier = modifier * 0.5
            end
        elseif action == "patrol" or action == "mine" then
            -- Prefer patrol/mining when far from player
            if context.distanceToPlayer > 300 then
                modifier = modifier * 1.3
            end
        end
    end
    
    -- Health level
    if context.healthPercent then
        if action == "retreat" or action == "flee" then
            -- More likely to retreat when low health
            if context.healthPercent < 0.3 then
                modifier = modifier * 2.0
            elseif context.healthPercent > 0.7 then
                modifier = modifier * 0.5
            end
        elseif action == "engage" then
            -- More likely to engage when healthy
            if context.healthPercent > 0.7 then
                modifier = modifier * 1.3
            elseif context.healthPercent < 0.3 then
                modifier = modifier * 0.7
            end
        end
    end
    
    -- Ammo/energy level
    if context.ammoPercent then
        if action == "engage" or action == "intercept" then
            -- Less likely to engage when low on ammo
            if context.ammoPercent < 0.2 then
                modifier = modifier * 0.3
            end
        elseif action == "retreat" or action == "dock" then
            -- More likely to retreat when low on ammo
            if context.ammoPercent < 0.2 then
                modifier = modifier * 1.5
            end
        end
    end
    
    -- Time since last combat
    if memory.lastCombatTime and context.gameTime then
        local timeSinceCombat = context.gameTime - memory.lastCombatTime
        if action == "patrol" or action == "mine" then
            -- Prefer peaceful actions after combat
            if timeSinceCombat > 10 then
                modifier = modifier * 1.2
            end
        end
    end
    
    return modifier
end

-- Get role modifier for an action
function AIUtility.getRoleModifier(action, role, context)
    local modifier = 1.0
    
    if role == "leader" then
        -- Leaders prefer formation and coordination actions
        if action == "formation" or action == "support" then
            modifier = modifier * 1.3
        end
    elseif role == "wingman" then
        -- Wingmen prefer following and supporting
        if action == "formation" or action == "support" then
            modifier = modifier * 1.2
        elseif action == "patrol" then
            modifier = modifier * 0.8
        end
    elseif role == "escort" then
        -- Escorts prefer defensive actions
        if action == "defend" or action == "support" then
            modifier = modifier * 1.4
        elseif action == "patrol" then
            modifier = modifier * 0.6
        end
    elseif role == "interceptor" then
        -- Interceptors prefer fast, aggressive actions
        if action == "intercept" or action == "engage" then
            modifier = modifier * 1.3
        elseif action == "patrol" or action == "mine" then
            modifier = modifier * 0.7
        end
    end
    
    return modifier
end

-- Get health modifier for an action
function AIUtility.getHealthModifier(action, context)
    local modifier = 1.0
    
    if context.healthPercent then
        if action == "retreat" or action == "flee" then
            -- More likely to retreat when damaged
            modifier = modifier * (2.0 - context.healthPercent)
        elseif action == "engage" or action == "intercept" then
            -- Less likely to engage when damaged
            modifier = modifier * context.healthPercent
        elseif action == "support" then
            -- Support actions less affected by health
            modifier = modifier * (0.5 + context.healthPercent * 0.5)
        end
    end
    
    return modifier
end

-- Get threat modifier for an action
function AIUtility.getThreatModifier(action, context, memory)
    local modifier = 1.0
    
    if context.threatLevel then
        if action == "retreat" or action == "flee" then
            -- More likely to retreat when threatened
            modifier = modifier * (1.0 + context.threatLevel)
        elseif action == "engage" or action == "intercept" then
            -- Less likely to engage when heavily threatened
            if context.threatLevel > 0.7 then
                modifier = modifier * 0.5
            end
        elseif action == "defend" then
            -- More likely to defend when threatened
            modifier = modifier * (1.0 + context.threatLevel * 0.5)
        end
    end
    
    return modifier
end

-- Get squad modifier for an action
function AIUtility.getSquadModifier(action, context, memory)
    local modifier = 1.0
    
    if memory.squadMembers and #memory.squadMembers > 0 then
        if action == "formation" or action == "support" then
            -- Prefer squad actions when in a squad
            modifier = modifier * 1.2
        elseif action == "flee" then
            -- Less likely to flee when in a squad
            modifier = modifier * 0.8
        end
    else
        -- Lone wolf behavior
        if action == "formation" or action == "support" then
            modifier = modifier * 0.5
        elseif action == "patrol" or action == "engage" then
            modifier = modifier * 1.1
        end
    end
    
    return modifier
end

-- Get equipment modifier for an action
function AIUtility.getEquipmentModifier(action, context)
    local modifier = 1.0
    
    if context.equipment then
        -- Check for specific weapon types
        if context.equipment.hasHealingWeapon and action == "support" then
            modifier = modifier * 1.5
        end
        
        if context.equipment.hasMiningWeapon and action == "mine" then
            modifier = modifier * 1.5
        end
        
        if context.equipment.hasLongRangeWeapon and action == "intercept" then
            modifier = modifier * 1.2
        end
        
        if context.equipment.hasCloseRangeWeapon and action == "engage" then
            modifier = modifier * 1.2
        end
    end
    
    return modifier
end

-- Get action description
function AIUtility.getActionDescription(action)
    local descriptions = {
        patrol = "Patrol the area and look for targets",
        engage = "Engage enemies in direct combat",
        retreat = "Retreat to a safer position",
        support = "Provide support to allies",
        mine = "Mine resources from asteroids",
        dock = "Dock with a station or ship",
        formation = "Maintain formation with squad",
        intercept = "Intercept and engage specific targets",
        defend = "Defend a specific position or target",
        flee = "Flee from the area entirely",
        idle = "Wait and observe"
    }
    
    return descriptions[action] or "Unknown action"
end

-- Export constants
AIUtility.ACTIONS = ACTIONS

return AIUtility
