--[[
    ECS Manager

    Wraps the vendored tiny-ecs world and exposes a thin abstraction that keeps
    system context wiring consistent with the previous manual pipeline. This
    allows us to progressively move bespoke systems across without rewriting the
    broader game loop all at once.
]]

local tiny = require("src.libs.tiny")

local ECS = {}
ECS.__index = ECS

function ECS.new()
    local self = setmetatable({}, ECS)
    self.tiny_world = tiny.world()
    self.context = {}
    self.systems = {}
    self.game_world = nil
    return self
end

function ECS:setWorld(world)
    self.game_world = world
    if self.tiny_world then
        self.tiny_world.game_world = world
    end
end

local function sync_system_worlds(tiny_world, game_world)
    if not tiny_world or not tiny_world.systems then return end
    for _, system in ipairs(tiny_world.systems) do
        system.game_world = game_world
    end
end

function ECS:addSystem(system)
    if not system then return end
    table.insert(self.systems, system)
    self.tiny_world:addSystem(system)
    system.game_world = self.game_world
    return system
end

function ECS:addEntity(entity)
    if not self.tiny_world then return end
    self.tiny_world:addEntity(entity)
end

function ECS:removeEntity(entity)
    if not self.tiny_world then return end
    self.tiny_world:removeEntity(entity)
end

function ECS:refresh(entity)
    if not self.tiny_world then return end
    self.tiny_world:refresh(entity)
end

local function merge_context(base, updates)
    if not updates then return base end
    for key, value in pairs(updates) do
        base[key] = value
    end
    return base
end

function ECS:update(dt, context)
    if not self.tiny_world then return end

    self.context.dt = dt
    self.context.world = self.game_world
    merge_context(self.context, context)

    sync_system_worlds(self.tiny_world, self.game_world)
    self.tiny_world:update(dt, self.context)
end

return ECS
