--[[
  AI Squad System
  
  Manages squad coordination, formation flying, and group tactics.
  Handles communication between squad members and coordinated actions.
]]

local Log = require("src.core.log")

local AISquad = {}

-- Squad data structure
local Squad = {}
Squad.__index = Squad

function Squad.new(squadId, leader, aiType, role)
    local self = setmetatable({}, Squad)
    self.id = squadId
    self.leader = leader
    self.members = {}
    self.aiType = aiType or "fighter"
    self.role = role or "patrol"
    self.formation = "line" -- line, wedge, diamond, circle
    self.state = "idle" -- idle, patrol, combat, retreat
    self.objective = nil
    self.lastUpdate = 0
    self.communication = {
        messages = {},
        lastMessage = 0
    }
    return self
end

-- Add member to squad
function Squad:addMember(entity)
    if not entity or not entity.components or not entity.components.ai then
        return false
    end
    
    entity.components.ai.squadId = self.id
    table.insert(self.members, entity)
    
    Log.info("Added entity %s to squad %s", entity.id or "unknown", self.id)
    return true
end

-- Remove member from squad
function Squad:removeMember(entity)
    for i, member in ipairs(self.members) do
        if member == entity then
            table.remove(self.members, i)
            if entity.components and entity.components.ai then
                entity.components.ai.squadId = nil
            end
            Log.info("Removed entity %s from squad %s", entity.id or "unknown", self.id)
            return true
        end
    end
    return false
end

-- Update squad
function Squad:update(dt, world, globalContext)
    self.lastUpdate = globalContext.gameTime or 0
    
    -- Update squad state based on members
    self:updateSquadState()
    
    -- Coordinate squad actions
    self:coordinateActions(dt, world, globalContext)
    
    -- Update formation
    self:updateFormation(dt, world)
    
    -- Handle communication
    self:updateCommunication(dt)
end

-- Update squad state based on member states
function Squad:updateSquadState()
    local combatCount = 0
    local retreatCount = 0
    local totalMembers = #self.members
    
    for _, member in ipairs(self.members) do
        if member.components and member.components.ai then
            local ai = member.components.ai
            if ai.state == "combat" then
                combatCount = combatCount + 1
            elseif ai.state == "retreat" then
                retreatCount = retreatCount + 1
            end
        end
    end
    
    -- Determine squad state
    if retreatCount > totalMembers * 0.5 then
        self.state = "retreat"
    elseif combatCount > 0 then
        self.state = "combat"
    elseif self.objective then
        self.state = "patrol"
    else
        self.state = "idle"
    end
end

-- Coordinate actions between squad members
function Squad:coordinateActions(dt, world, globalContext)
    if not self.leader or not self.leader.components or not self.leader.components.ai then
        return
    end
    
    local leaderAI = self.leader.components.ai
    
    -- Leader makes decisions for the squad
    if leaderAI.role == "leader" then
        self:coordinateLeaderActions(dt, world, globalContext)
    else
        self:coordinateWingmanActions(dt, world, globalContext)
    end
end

-- Coordinate leader actions
function Squad:coordinateLeaderActions(dt, world, globalContext)
    -- Leader decides squad objective
    if not self.objective or self:isObjectiveComplete() then
        self.objective = self:selectSquadObjective(globalContext)
    end
    
    -- Communicate objective to squad
    self:communicateObjective()
    
    -- Coordinate formation
    self:coordinateFormation()
    
    -- Assign roles to members
    self:assignMemberRoles()
end

-- Coordinate wingman actions
function Squad:coordinateWingmanActions(dt, world, globalContext)
    -- Wingmen follow leader's lead
    for _, member in ipairs(self.members) do
        if member ~= self.leader and member.components and member.components.ai then
            local ai = member.components.ai
            if ai.role == "wingman" then
                self:coordinateWingmanBehavior(member, dt, world)
            end
        end
    end
end

-- Coordinate individual wingman behavior
function Squad:coordinateWingmanBehavior(member, dt, world)
    local ai = member.components.ai
    local leaderPos = self.leader.components.position
    
    if not leaderPos then return end
    
    -- Calculate desired position relative to leader
    local desiredPos = self:calculateWingmanPosition(member)
    
    -- Update member's target position
    if not ai.memory then
        ai.memory = {}
    end
    ai.memory.squadTargetPosition = desiredPos
    ai.memory.squadLeader = self.leader
end

-- Calculate wingman position relative to leader
function Squad:calculateWingmanPosition(member)
    local leaderPos = self.leader.components.position
    if not leaderPos then return nil end
    
    local memberIndex = self:getMemberIndex(member)
    if memberIndex == -1 then return nil end
    
    local formation = self.formation
    local spacing = 100 -- Distance between members
    
    if formation == "line" then
        -- Line formation: members spread horizontally
        local offset = (memberIndex - 1) * spacing
        return {
            x = leaderPos.x + offset,
            y = leaderPos.y
        }
    elseif formation == "wedge" then
        -- Wedge formation: V-shape behind leader
        local angle = (memberIndex - 1) * 0.5 -- 0.5 radians between members
        local distance = memberIndex * spacing
        return {
            x = leaderPos.x - math.cos(angle) * distance,
            y = leaderPos.y - math.sin(angle) * distance
        }
    elseif formation == "diamond" then
        -- Diamond formation: diamond shape around leader
        local positions = {
            {x = leaderPos.x, y = leaderPos.y - spacing},      -- Front
            {x = leaderPos.x + spacing, y = leaderPos.y},      -- Right
            {x = leaderPos.x, y = leaderPos.y + spacing},      -- Back
            {x = leaderPos.x - spacing, y = leaderPos.y}       -- Left
        }
        return positions[memberIndex] or positions[1]
    elseif formation == "circle" then
        -- Circle formation: members in a circle around leader
        local angle = (memberIndex - 1) * (2 * math.pi / #self.members)
        return {
            x = leaderPos.x + math.cos(angle) * spacing,
            y = leaderPos.y + math.sin(angle) * spacing
        }
    end
    
    return {x = leaderPos.x, y = leaderPos.y}
end

-- Get member index in squad
function Squad:getMemberIndex(member)
    for i, m in ipairs(self.members) do
        if m == member then
            return i
        end
    end
    return -1
end

-- Select squad objective
function Squad:selectSquadObjective(globalContext)
    local objectives = {
        "patrol",
        "defend",
        "attack",
        "escort",
        "mine"
    }
    
    -- Simple objective selection based on squad type and context
    if self.aiType == "fighter" then
        if globalContext.activeEnemies > 0 then
            return "attack"
        else
            return "patrol"
        end
    elseif self.aiType == "support" then
        return "defend"
    elseif self.aiType == "miner" then
        return "mine"
    end
    
    return "patrol"
end

-- Check if objective is complete
function Squad:isObjectiveComplete()
    -- Simple completion check
    return false -- For now, objectives never complete
end

-- Communicate objective to squad
function Squad:communicateObjective()
    if not self.objective then return end
    
    local message = {
        type = "objective",
        objective = self.objective,
        timestamp = self.lastUpdate
    }
    
    self:addMessage(message)
end

-- Coordinate formation
function Squad:coordinateFormation()
    -- Set formation based on squad state and type
    if self.state == "combat" then
        self.formation = "wedge" -- Aggressive formation
    elseif self.state == "retreat" then
        self.formation = "line" -- Defensive formation
    elseif self.aiType == "support" then
        self.formation = "circle" -- Protective formation
    else
        self.formation = "line" -- Default formation
    end
end

-- Assign roles to squad members
function Squad:assignMemberRoles()
    for i, member in ipairs(self.members) do
        if member.components and member.components.ai then
            local ai = member.components.ai
            
            if member == self.leader then
                ai.role = "leader"
            elseif i == 2 then
                ai.role = "wingman" -- Second member is primary wingman
            else
                ai.role = "wingman" -- Other members are wingmen
            end
        end
    end
end

-- Update formation
function Squad:updateFormation(dt, world)
    -- Formation updates are handled in individual member coordination
end

-- Update communication
function Squad:updateCommunication(dt)
    -- Clean old messages
    local cutoffTime = self.lastUpdate - 10 -- Keep messages for 10 seconds
    for i = #self.communication.messages, 1, -1 do
        if self.communication.messages[i].timestamp < cutoffTime then
            table.remove(self.communication.messages, i)
        end
    end
end

-- Add message to squad communication
function Squad:addMessage(message)
    table.insert(self.communication.messages, message)
    self.communication.lastMessage = self.lastUpdate
end

-- Get squad members
function Squad:getMembers()
    return self.members
end

-- Get squad leader
function Squad:getLeader()
    return self.leader
end

-- Get squad state
function Squad:getState()
    return self.state
end

-- Get squad objective
function Squad:getObjective()
    return self.objective
end

-- Squad management
local squads = {}
local nextSquadId = 1

-- Create new squad
function AISquad.createSquad(leader, aiType, role)
    local squadId = "squad_" .. nextSquadId
    nextSquadId = nextSquadId + 1
    
    local squad = Squad.new(squadId, leader, aiType, role)
    squads[squadId] = squad
    
    Log.info("Created squad %s with leader %s", squadId, leader.id or "unknown")
    return squad
end

-- Add entity to squad
function AISquad.addEntityToSquad(squadId, entity)
    local squad = squads[squadId]
    if squad then
        return squad:addMember(entity)
    end
    return false
end

-- Remove entity from squad
function AISquad.removeEntityFromSquad(squadId, entity)
    local squad = squads[squadId]
    if squad then
        return squad:removeMember(entity)
    end
    return false
end

-- Get squad by ID
function AISquad.getSquad(squadId)
    return squads[squadId]
end

-- Get squad members
function AISquad.getSquadMembers(squadId)
    local squad = squads[squadId]
    if squad then
        return squad:getMembers()
    end
    return {}
end

-- Update all squads
function AISquad.updateAllSquads(dt, world, globalContext)
    for _, squad in pairs(squads) do
        squad:update(dt, world, globalContext)
    end
end

-- Get squad count
function AISquad.getSquadCount()
    local count = 0
    for _ in pairs(squads) do
        count = count + 1
    end
    return count
end

-- Get all squads
function AISquad.getAllSquads()
    return squads
end

-- Remove squad
function AISquad.removeSquad(squadId)
    local squad = squads[squadId]
    if squad then
        -- Remove all members
        for _, member in ipairs(squad.members) do
            if member.components and member.components.ai then
                member.components.ai.squadId = nil
            end
        end
        squads[squadId] = nil
        Log.info("Removed squad %s", squadId)
        return true
    end
    return false
end

return AISquad
