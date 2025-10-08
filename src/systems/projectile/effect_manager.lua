local Log = require("src.core.log")
local EffectRegistry = require("src.systems.projectile.effect_registry")

local EffectManager = {}
EffectManager.__index = EffectManager

local function shallow_copy(tbl)
    local copy = {}
    for k, v in pairs(tbl) do
        copy[k] = v
    end
    return copy
end

function EffectManager.new(projectile, dispatcher)
    local self = setmetatable({}, EffectManager)
    self.projectile = projectile
    self.dispatcher = dispatcher
    self.effects = {}
    return self
end

function EffectManager:getContext()
    return {
        projectile = self.projectile,
        dispatcher = self.dispatcher,
        manager = self,
    }
end

local function attach_events(manager, effect)
    if not effect.events then return end

    for eventName, handler in pairs(effect.events) do
        if type(handler) == "function" then
            manager.dispatcher:on(eventName, handler)
        end
    end
end

function EffectManager:store(effect, effectType)
    if not effect then return end
    table.insert(self.effects, effect)
    if effect.components then
        self.projectile:applyComponentDefinitions(effect.components, {
            source = string.format("effect:%s", tostring(effectType or "unknown")),
        })
    end
    attach_events(self, effect)
end

local function resolve_effect_type(def)
    if type(def) ~= "table" then return nil end
    if def.type then return def.type end
    if def.kind and EffectRegistry.isRegistered(def.kind) then return def.kind end
    if def.name and EffectRegistry.isRegistered(def.name) then return def.name end
    if def.effect and EffectRegistry.isRegistered(def.effect) then return def.effect end
    return nil
end

function EffectManager:addEffect(definition)
    if type(definition) ~= "table" then return nil end

    local effectType = resolve_effect_type(definition)
    if not effectType then
        if definition.type or definition.kind or definition.name or definition.effect then
            Log.warn("Unable to resolve projectile effect type for definition")
        end
        return nil
    end

    local context = self:getContext()
    local effect = EffectRegistry.create(effectType, context, definition)
    if not effect then return nil end

    self:store(effect, effectType)
    return effect
end

function EffectManager:loadConfig(effectsConfig)
    if type(effectsConfig) ~= "table" then return end

    if #effectsConfig > 0 then
        for _, def in ipairs(effectsConfig) do
            if type(def) == "table" then
                self:addEffect(def)
            end
        end
    else
        for key, def in pairs(effectsConfig) do
            if type(def) == "table" then
                local normalized = shallow_copy(def)
                if not normalized.type then
                    normalized.type = key
                end
                self:addEffect(normalized)
            end
        end
    end
end

return EffectManager
