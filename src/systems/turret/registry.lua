local TurretRegistry = {}

local handlers = {}
local defaultHandler = nil

local function validateHandler(handler)
    if type(handler) ~= "table" then
        error("Turret handler must be a table", 2)
    end
    return handler
end

function TurretRegistry.register(kind, handler)
    validateHandler(handler)

    if type(kind) == "table" then
        for _, alias in ipairs(kind) do
            TurretRegistry.register(alias, handler)
        end
        return handler
    end

    if kind == nil then
        defaultHandler = handler
    else
        handlers[kind] = handler
    end

    return handler
end

function TurretRegistry.get(kind)
    if kind ~= nil then
        local handler = handlers[kind]
        if handler ~= nil then
            return handler
        end
    end
    return defaultHandler
end

function TurretRegistry.list()
    return handlers, defaultHandler
end

return TurretRegistry
