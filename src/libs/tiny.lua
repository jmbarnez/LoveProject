--[[
    tiny-ecs inspired entity-component-system helpers.

    This lightweight implementation vendors the tiny-ecs API surface that we
    rely on for the project's first integration pass. It keeps the familiar
    constructor helpers (world/process systems and component filters) so future
    systems can transition toward full tiny-ecs usage without immediately
    rewriting every subsystem.

    The implementation focuses on clarity over micro-optimisation: we evaluate
    filters on demand during updates which keeps entity/component bookkeeping
    straightforward while we migrate off bespoke loops elsewhere in the code
    base.
]]

local tiny = {}

local function is_system_active(system)
    if system == nil then return false end
    if system.enabled == false then return false end
    if system.active == false then return false end
    return true
end

function tiny.system()
    return { enabled = true }
end

function tiny.processingSystem()
    local system = tiny.system()
    system.__isProcessing = true
    function system:process(_, _, _)
        -- Intentionally left blank; concrete systems should override this.
    end
    return system
end

local function entity_has_components(entity, keys, require_any)
    if not entity then return false end
    local components = entity.components
    if not components then return false end

    if require_any then
        for _, key in ipairs(keys) do
            if components[key] then
                return true
            end
        end
        return #keys == 0
    else
        for _, key in ipairs(keys) do
            if not components[key] then
                return false
            end
        end
        return true
    end
end

function tiny.requireAll(...)
    local keys = { ... }
    return function(entity)
        return entity_has_components(entity, keys, false)
    end
end

function tiny.requireAny(...)
    local keys = { ... }
    return function(entity)
        return entity_has_components(entity, keys, true)
    end
end

function tiny.requireNone(...)
    local keys = { ... }
    return function(entity)
        if not entity then return true end
        local components = entity.components
        if not components then return true end
        for _, key in ipairs(keys) do
            if components[key] then
                return false
            end
        end
        return true
    end
end

local World = {}
World.__index = World

function World:addSystem(system)
    if not system then return end
    if system.world and system.world ~= self then
        error("system already added to a different world", 2)
    end
    system.world = self
    table.insert(self.systems, system)
    if system.onAddToWorld then
        system:onAddToWorld(self)
    end
    return system
end

function World:removeSystem(system)
    if not system then return end
    for index, candidate in ipairs(self.systems) do
        if candidate == system then
            table.remove(self.systems, index)
            if system.onRemoveFromWorld then
                system:onRemoveFromWorld(self)
            end
            system.world = nil
            break
        end
    end
end

function World:addEntity(entity)
    if not entity or self.entities[entity] then
        return
    end
    self.entities[entity] = true
    table.insert(self.entityList, entity)
end

function World:removeEntity(entity)
    if not entity or not self.entities[entity] then
        return
    end
    self.entities[entity] = nil
    for index, candidate in ipairs(self.entityList) do
        if candidate == entity then
            table.remove(self.entityList, index)
            break
        end
    end
end

function World:refresh(entity)
    -- This lightweight adapter evaluates filters during update so there is no
    -- cached membership data to refresh. The function exists to keep parity
    -- with the tiny-ecs API and future-proof call sites that expect it.
    return entity
end

function World:update(dt, context)
    for _, system in ipairs(self.systems) do
        if is_system_active(system) then
            if system.__isProcessing then
                local filter = system.filter
                for _, entity in ipairs(self.entityList) do
                    if entity and (not filter or filter(entity)) then
                        system:process(entity, dt, context)
                    end
                end
            elseif system.update then
                system:update(dt, context)
            end
        end
    end
end

function tiny.world(...)
    local systems = { ... }
    local world = setmetatable({
        systems = {},
        entities = {},
        entityList = {},
    }, World)

    for _, system in ipairs(systems) do
        world:addSystem(system)
    end

    return world
end

return tiny
