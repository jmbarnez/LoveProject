local Log = require("src.core.log")

local ProjectileEventDispatcher = {}
ProjectileEventDispatcher.__index = ProjectileEventDispatcher

ProjectileEventDispatcher.EVENTS = {
    SPAWN = "spawn",
    UPDATE = "update",
    HIT = "hit",
    EXPIRE = "expire",
}

function ProjectileEventDispatcher.new()
    local self = setmetatable({}, ProjectileEventDispatcher)
    self.listeners = {}
    return self
end

function ProjectileEventDispatcher:on(event, handler)
    if not event or type(handler) ~= "function" then return handler end

    if not self.listeners[event] then
        self.listeners[event] = {}
    end

    table.insert(self.listeners[event], handler)
    return handler
end

function ProjectileEventDispatcher:emit(event, payload)
    local handlers = self.listeners[event]
    if not handlers then return end

    for _, handler in ipairs(handlers) do
        local ok, err = pcall(handler, payload)
        if not ok then
            Log.warn(string.format("Projectile event handler error for '%s': %s", tostring(event), tostring(err)))
        end
    end
end

function ProjectileEventDispatcher:clear()
    self.listeners = {}
end

function ProjectileEventDispatcher:asComponent()
    return {
        dispatcher = self,
    }
end

return ProjectileEventDispatcher
