local Log = require("src.core.log")
local BehaviorRegistry = require("src.systems.projectile.behavior_registry")

local BehaviorManager = {}
BehaviorManager.__index = BehaviorManager

local function shallow_copy(tbl)
    local copy = {}
    for k, v in pairs(tbl) do
        copy[k] = v
    end
    return copy
end

local function attach_events(manager, behavior)
    if not behavior.events then return end

    for eventName, handler in pairs(behavior.events) do
        if type(handler) == "function" then
            manager.dispatcher:on(eventName, handler)
        end
    end
end

function BehaviorManager.new(projectile, dispatcher)
    local self = setmetatable({}, BehaviorManager)
    self.projectile = projectile
    self.dispatcher = dispatcher
    self.behaviors = {}
    return self
end

function BehaviorManager:getContext()
    return {
        projectile = self.projectile,
        dispatcher = self.dispatcher,
        manager = self,
    }
end

function BehaviorManager:store(behavior, behaviorType)
    if not behavior then return end
    table.insert(self.behaviors, behavior)
    if behavior.components then
        self.projectile:applyComponentDefinitions(behavior.components, {
            source = string.format("behavior:%s", tostring(behaviorType or "unknown")),
        })
    end
    attach_events(self, behavior)
end

local function resolve_behavior_type(def)
    if type(def) ~= "table" then return nil end
    if def.type then return def.type end
    if def.name and BehaviorRegistry.isRegistered(def.name) then return def.name end
    if def.behavior and BehaviorRegistry.isRegistered(def.behavior) then return def.behavior end
    if def.kind and BehaviorRegistry.isRegistered(def.kind) then return def.kind end
    return nil
end

function BehaviorManager:addBehavior(definition)
    if type(definition) ~= "table" then return nil end

    local behaviorType = resolve_behavior_type(definition)
    if not behaviorType then
        if definition.type or definition.name or definition.behavior or definition.kind then
            Log.warn("Unable to resolve projectile behavior type for definition")
        end
        return nil
    end

    local context = self:getContext()
    local behavior = BehaviorRegistry.create(behaviorType, context, definition)
    if not behavior then return nil end

    self:store(behavior, behaviorType)
    return behavior
end

function BehaviorManager:loadConfig(behaviorsConfig)
    if type(behaviorsConfig) ~= "table" then return end

    if #behaviorsConfig > 0 then
        for _, def in ipairs(behaviorsConfig) do
            if type(def) == "table" then
                self:addBehavior(def)
            end
        end
    else
        for key, def in pairs(behaviorsConfig) do
            if type(def) == "table" then
                local normalized = shallow_copy(def)
                if not normalized.type then
                    normalized.type = key
                end
                self:addBehavior(normalized)
            end
        end
    end
end

function BehaviorManager:asComponent()
    return {
        manager = self,
    }
end

function BehaviorManager:getBehaviors()
    return self.behaviors
end

return BehaviorManager
