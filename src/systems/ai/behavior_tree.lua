--[[
  AI Behavior Tree System
  
  Hierarchical behavior trees for executing AI actions.
  Modular, reusable behaviors that can be combined in different ways.
]]

local Log = require("src.core.log")

local AIBehaviorTree = {}

-- Node types
local NODE_TYPES = {
    SEQUENCE = "sequence",     -- Execute children in order, fail if any fails
    SELECTOR = "selector",     -- Execute children until one succeeds
    PARALLEL = "parallel",     -- Execute all children simultaneously
    DECORATOR = "decorator",   -- Modify child behavior
    ACTION = "action",         -- Execute specific action
    CONDITION = "condition"    -- Check condition
}

-- Behavior tree node
local BehaviorNode = {}
BehaviorNode.__index = BehaviorNode

function BehaviorNode.new(nodeType, name, action, condition)
    local self = setmetatable({}, BehaviorNode)
    self.type = nodeType
    self.name = name or "unnamed"
    self.action = action
    self.condition = condition
    self.children = {}
    self.state = "ready" -- ready, running, success, failure
    self.lastResult = nil
    return self
end

-- Add child node
function BehaviorNode:addChild(child)
    table.insert(self.children, child)
end

-- Execute the node
function BehaviorNode:execute(entity, dt, world)
    if self.type == NODE_TYPES.ACTION then
        return self:executeAction(entity, dt, world)
    elseif self.type == NODE_TYPES.CONDITION then
        return self:executeCondition(entity, dt, world)
    elseif self.type == NODE_TYPES.SEQUENCE then
        return self:executeSequence(entity, dt, world)
    elseif self.type == NODE_TYPES.SELECTOR then
        return self:executeSelector(entity, dt, world)
    elseif self.type == NODE_TYPES.PARALLEL then
        return self:executeParallel(entity, dt, world)
    elseif self.type == NODE_TYPES.DECORATOR then
        return self:executeDecorator(entity, dt, world)
    end
    
    return "failure"
end

-- Execute action node
function BehaviorNode:executeAction(entity, dt, world)
    if self.action and type(self.action) == "function" then
        local result = self.action(entity, dt, world)
        self.lastResult = result
        return result
    end
    return "failure"
end

-- Execute condition node
function BehaviorNode:executeCondition(entity, dt, world)
    if self.condition and type(self.condition) == "function" then
        local result = self.condition(entity, dt, world)
        self.lastResult = result
        return result and "success" or "failure"
    end
    return "failure"
end

-- Execute sequence node
function BehaviorNode:executeSequence(entity, dt, world)
    for _, child in ipairs(self.children) do
        local result = child:execute(entity, dt, world)
        if result == "failure" then
            return "failure"
        elseif result == "running" then
            return "running"
        end
    end
    return "success"
end

-- Execute selector node
function BehaviorNode:executeSelector(entity, dt, world)
    for _, child in ipairs(self.children) do
        local result = child:execute(entity, dt, world)
        if result == "success" then
            return "success"
        elseif result == "running" then
            return "running"
        end
    end
    return "failure"
end

-- Execute parallel node
function BehaviorNode:executeParallel(entity, dt, world)
    local results = {}
    local running = false
    
    for _, child in ipairs(self.children) do
        local result = child:execute(entity, dt, world)
        table.insert(results, result)
        if result == "running" then
            running = true
        end
    end
    
    if running then
        return "running"
    end
    
    -- All children completed, return success if any succeeded
    for _, result in ipairs(results) do
        if result == "success" then
            return "success"
        end
    end
    
    return "failure"
end

-- Execute decorator node
function BehaviorNode:executeDecorator(entity, dt, world)
    if #self.children > 0 then
        local child = self.children[1]
        local result = child:execute(entity, dt, world)
        
        -- Apply decorator logic here
        -- For now, just pass through the result
        return result
    end
    return "failure"
end

-- Create behavior tree for specific AI type and role
function AIBehaviorTree.createTree(aiType, aiRole)
    local root = BehaviorNode.new(NODE_TYPES.SELECTOR, "root")
    
    -- Add type-specific behaviors
    if aiType == "scout" then
        AIBehaviorTree.addScoutBehaviors(root)
    elseif aiType == "fighter" then
        AIBehaviorTree.addFighterBehaviors(root)
    elseif aiType == "support" then
        AIBehaviorTree.addSupportBehaviors(root)
    elseif aiType == "miner" then
        AIBehaviorTree.addMinerBehaviors(root)
    elseif aiType == "boss" then
        AIBehaviorTree.addBossBehaviors(root)
    elseif aiType == "civilian" then
        AIBehaviorTree.addCivilianBehaviors(root)
    elseif aiType == "patrol" then
        AIBehaviorTree.addPatrolBehaviors(root)
    end
    
    -- Add role-specific behaviors
    if aiRole == "leader" then
        AIBehaviorTree.addLeaderBehaviors(root)
    elseif aiRole == "wingman" then
        AIBehaviorTree.addWingmanBehaviors(root)
    elseif aiRole == "escort" then
        AIBehaviorTree.addEscortBehaviors(root)
    elseif aiRole == "interceptor" then
        AIBehaviorTree.addInterceptorBehaviors(root)
    end
    
    return root
end

-- Add scout-specific behaviors
function AIBehaviorTree.addScoutBehaviors(root)
    -- Scout behaviors: patrol, detect, report, flee
    local scoutSequence = BehaviorNode.new(NODE_TYPES.SEQUENCE, "scout_sequence")
    
    -- Patrol behavior
    local patrolAction = BehaviorNode.new(NODE_TYPES.ACTION, "patrol", AIBehaviorTree.actions.patrol)
    scoutSequence:addChild(patrolAction)
    
    -- Detection behavior
    local detectAction = BehaviorNode.new(NODE_TYPES.ACTION, "detect", AIBehaviorTree.actions.detect)
    scoutSequence:addChild(detectAction)
    
    -- Report behavior
    local reportAction = BehaviorNode.new(NODE_TYPES.ACTION, "report", AIBehaviorTree.actions.report)
    scoutSequence:addChild(reportAction)
    
    root:addChild(scoutSequence)
    
    -- Flee behavior (high priority)
    local fleeAction = BehaviorNode.new(NODE_TYPES.ACTION, "flee", AIBehaviorTree.actions.flee)
    root:addChild(fleeAction)
end

-- Add fighter-specific behaviors
function AIBehaviorTree.addFighterBehaviors(root)
    -- Fighter behaviors: engage, attack, flank, retreat
    local combatSequence = BehaviorNode.new(NODE_TYPES.SEQUENCE, "combat_sequence")
    
    -- Approach target
    local approachAction = BehaviorNode.new(NODE_TYPES.ACTION, "approach", AIBehaviorTree.actions.approach)
    combatSequence:addChild(approachAction)
    
    -- Attack target
    local attackAction = BehaviorNode.new(NODE_TYPES.ACTION, "attack", AIBehaviorTree.actions.attack)
    combatSequence:addChild(attackAction)
    
    -- Flank if needed
    local flankAction = BehaviorNode.new(NODE_TYPES.ACTION, "flank", AIBehaviorTree.actions.flank)
    combatSequence:addChild(flankAction)
    
    root:addChild(combatSequence)
    
    -- Retreat behavior
    local retreatAction = BehaviorNode.new(NODE_TYPES.ACTION, "retreat", AIBehaviorTree.actions.retreat)
    root:addChild(retreatAction)
end

-- Add support-specific behaviors
function AIBehaviorTree.addSupportBehaviors(root)
    -- Support behaviors: heal, buff, defend, coordinate
    local supportSequence = BehaviorNode.new(NODE_TYPES.SEQUENCE, "support_sequence")
    
    -- Find allies in need
    local findAllyAction = BehaviorNode.new(NODE_TYPES.ACTION, "find_ally", AIBehaviorTree.actions.findAlly)
    supportSequence:addChild(findAllyAction)
    
    -- Heal allies
    local healAction = BehaviorNode.new(NODE_TYPES.ACTION, "heal", AIBehaviorTree.actions.heal)
    supportSequence:addChild(healAction)
    
    -- Defend allies
    local defendAction = BehaviorNode.new(NODE_TYPES.ACTION, "defend", AIBehaviorTree.actions.defend)
    supportSequence:addChild(defendAction)
    
    root:addChild(supportSequence)
end

-- Add miner-specific behaviors
function AIBehaviorTree.addMinerBehaviors(root)
    -- Miner behaviors: find resources, mine, avoid danger, dock
    local miningSequence = BehaviorNode.new(NODE_TYPES.SEQUENCE, "mining_sequence")
    
    -- Find mining targets
    local findMiningAction = BehaviorNode.new(NODE_TYPES.ACTION, "find_mining", AIBehaviorTree.actions.findMining)
    miningSequence:addChild(findMiningAction)
    
    -- Mine resources
    local mineAction = BehaviorNode.new(NODE_TYPES.ACTION, "mine", AIBehaviorTree.actions.mine)
    miningSequence:addChild(mineAction)
    
    -- Dock to unload
    local dockAction = BehaviorNode.new(NODE_TYPES.ACTION, "dock", AIBehaviorTree.actions.dock)
    miningSequence:addChild(dockAction)
    
    root:addChild(miningSequence)
    
    -- Avoid danger
    local avoidAction = BehaviorNode.new(NODE_TYPES.ACTION, "avoid", AIBehaviorTree.actions.avoid)
    root:addChild(avoidAction)
end

-- Add boss-specific behaviors
function AIBehaviorTree.addBossBehaviors(root)
    -- Boss behaviors: complex multi-phase combat
    local bossSequence = BehaviorNode.new(NODE_TYPES.SEQUENCE, "boss_sequence")
    
    -- Phase 1: Approach
    local approachAction = BehaviorNode.new(NODE_TYPES.ACTION, "approach", AIBehaviorTree.actions.approach)
    bossSequence:addChild(approachAction)
    
    -- Phase 2: Attack
    local attackAction = BehaviorNode.new(NODE_TYPES.ACTION, "attack", AIBehaviorTree.actions.attack)
    bossSequence:addChild(attackAction)
    
    -- Phase 3: Special abilities
    local specialAction = BehaviorNode.new(NODE_TYPES.ACTION, "special", AIBehaviorTree.actions.special)
    bossSequence:addChild(specialAction)
    
    root:addChild(bossSequence)
end

-- Add civilian-specific behaviors
function AIBehaviorTree.addCivilianBehaviors(root)
    -- Civilian behaviors: trade, dock, avoid combat
    local civilianSequence = BehaviorNode.new(NODE_TYPES.SEQUENCE, "civilian_sequence")
    
    -- Trade behavior
    local tradeAction = BehaviorNode.new(NODE_TYPES.ACTION, "trade", AIBehaviorTree.actions.trade)
    civilianSequence:addChild(tradeAction)
    
    -- Dock behavior
    local dockAction = BehaviorNode.new(NODE_TYPES.ACTION, "dock", AIBehaviorTree.actions.dock)
    civilianSequence:addChild(dockAction)
    
    root:addChild(civilianSequence)
    
    -- Avoid combat (high priority)
    local avoidAction = BehaviorNode.new(NODE_TYPES.ACTION, "avoid", AIBehaviorTree.actions.avoid)
    root:addChild(avoidAction)
end

-- Add patrol-specific behaviors
function AIBehaviorTree.addPatrolBehaviors(root)
    -- Patrol behaviors: guard, patrol, respond to threats
    local patrolSequence = BehaviorNode.new(NODE_TYPES.SEQUENCE, "patrol_sequence")
    
    -- Patrol area
    local patrolAction = BehaviorNode.new(NODE_TYPES.ACTION, "patrol", AIBehaviorTree.actions.patrol)
    patrolSequence:addChild(patrolAction)
    
    -- Respond to threats
    local respondAction = BehaviorNode.new(NODE_TYPES.ACTION, "respond", AIBehaviorTree.actions.respond)
    patrolSequence:addChild(respondAction)
    
    root:addChild(patrolSequence)
end

-- Add role-specific behaviors
function AIBehaviorTree.addLeaderBehaviors(root)
    -- Leader behaviors: coordinate, command, make decisions
    local leaderAction = BehaviorNode.new(NODE_TYPES.ACTION, "lead", AIBehaviorTree.actions.lead)
    root:addChild(leaderAction)
end

function AIBehaviorTree.addWingmanBehaviors(root)
    -- Wingman behaviors: follow, support, cover
    local wingmanAction = BehaviorNode.new(NODE_TYPES.ACTION, "follow", AIBehaviorTree.actions.follow)
    root:addChild(wingmanAction)
end

function AIBehaviorTree.addEscortBehaviors(root)
    -- Escort behaviors: protect, guard, defend
    local escortAction = BehaviorNode.new(NODE_TYPES.ACTION, "escort", AIBehaviorTree.actions.escort)
    root:addChild(escortAction)
end

function AIBehaviorTree.addInterceptorBehaviors(root)
    -- Interceptor behaviors: fast response, hit and run
    local interceptorAction = BehaviorNode.new(NODE_TYPES.ACTION, "intercept", AIBehaviorTree.actions.intercept)
    root:addChild(interceptorAction)
end

-- Execute a specific action
function AIBehaviorTree.executeAction(behaviorTree, action, entity, dt, world)
    if not behaviorTree or not action then
        return "failure"
    end
    
    -- Find and execute the action node
    local actionNode = AIBehaviorTree.findActionNode(behaviorTree, action)
    if actionNode then
        return actionNode:execute(entity, dt, world)
    end
    
    return "failure"
end

-- Find action node by name
function AIBehaviorTree.findActionNode(node, actionName)
    if node.name == actionName then
        return node
    end
    
    for _, child in ipairs(node.children) do
        local result = AIBehaviorTree.findActionNode(child, actionName)
        if result then
            return result
        end
    end
    
    return nil
end

-- Action implementations
AIBehaviorTree.actions = {
    patrol = function(entity, dt, world)
        -- Implement patrol behavior
        Log.debug("Entity %s is patrolling", entity.id or "unknown")
        return "success"
    end,
    
    detect = function(entity, dt, world)
        -- Implement detection behavior
        Log.debug("Entity %s is detecting", entity.id or "unknown")
        return "success"
    end,
    
    report = function(entity, dt, world)
        -- Implement reporting behavior
        Log.debug("Entity %s is reporting", entity.id or "unknown")
        return "success"
    end,
    
    flee = function(entity, dt, world)
        -- Implement flee behavior
        Log.debug("Entity %s is fleeing", entity.id or "unknown")
        return "success"
    end,
    
    approach = function(entity, dt, world)
        -- Implement approach behavior
        Log.debug("Entity %s is approaching", entity.id or "unknown")
        return "success"
    end,
    
    attack = function(entity, dt, world)
        -- Implement attack behavior
        Log.debug("Entity %s is attacking", entity.id or "unknown")
        return "success"
    end,
    
    flank = function(entity, dt, world)
        -- Implement flank behavior
        Log.debug("Entity %s is flanking", entity.id or "unknown")
        return "success"
    end,
    
    retreat = function(entity, dt, world)
        -- Implement retreat behavior
        Log.debug("Entity %s is retreating", entity.id or "unknown")
        return "success"
    end,
    
    findAlly = function(entity, dt, world)
        -- Implement find ally behavior
        Log.debug("Entity %s is finding ally", entity.id or "unknown")
        return "success"
    end,
    
    heal = function(entity, dt, world)
        -- Implement heal behavior
        Log.debug("Entity %s is healing", entity.id or "unknown")
        return "success"
    end,
    
    defend = function(entity, dt, world)
        -- Implement defend behavior
        Log.debug("Entity %s is defending", entity.id or "unknown")
        return "success"
    end,
    
    findMining = function(entity, dt, world)
        -- Implement find mining behavior
        Log.debug("Entity %s is finding mining target", entity.id or "unknown")
        return "success"
    end,
    
    mine = function(entity, dt, world)
        -- Implement mine behavior
        Log.debug("Entity %s is mining", entity.id or "unknown")
        return "success"
    end,
    
    dock = function(entity, dt, world)
        -- Implement dock behavior
        Log.debug("Entity %s is docking", entity.id or "unknown")
        return "success"
    end,
    
    avoid = function(entity, dt, world)
        -- Implement avoid behavior
        Log.debug("Entity %s is avoiding", entity.id or "unknown")
        return "success"
    end,
    
    special = function(entity, dt, world)
        -- Implement special ability behavior
        Log.debug("Entity %s is using special ability", entity.id or "unknown")
        return "success"
    end,
    
    trade = function(entity, dt, world)
        -- Implement trade behavior
        Log.debug("Entity %s is trading", entity.id or "unknown")
        return "success"
    end,
    
    respond = function(entity, dt, world)
        -- Implement respond behavior
        Log.debug("Entity %s is responding", entity.id or "unknown")
        return "success"
    end,
    
    lead = function(entity, dt, world)
        -- Implement lead behavior
        Log.debug("Entity %s is leading", entity.id or "unknown")
        return "success"
    end,
    
    follow = function(entity, dt, world)
        -- Implement follow behavior
        Log.debug("Entity %s is following", entity.id or "unknown")
        return "success"
    end,
    
    escort = function(entity, dt, world)
        -- Implement escort behavior
        Log.debug("Entity %s is escorting", entity.id or "unknown")
        return "success"
    end,
    
    intercept = function(entity, dt, world)
        -- Implement intercept behavior
        Log.debug("Entity %s is intercepting", entity.id or "unknown")
        return "success"
    end
}

-- Export constants
AIBehaviorTree.NODE_TYPES = NODE_TYPES

return AIBehaviorTree
