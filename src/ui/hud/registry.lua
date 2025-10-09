--[[
    HUD Component Registry
    
    Manages HUD components that are always visible during gameplay.
    These components are different from UI panels as they don't have
    open/close states and are always rendered.
]]

local ModuleRegistry = require("src.core.module_registry")

local HUDRegistry = {}

local HUD_TAG = "ui.hud"
local registrations = {}

local function ensureModule(record)
    if record.module then
        return record.module
    end

    if record.loader then
        local module = record.loader()
        record.module = module
        ModuleRegistry.set(record.registryName, module)
        return module
    end

    return nil
end

function HUDRegistry.register(options)
    assert(options and type(options.id) == "string" and options.id ~= "", "HUD registration requires an id")

    local registryName = options.registryName or ("ui.hud." .. options.id)

    if registrations[options.id] then
        local existing = registrations[options.id]

        if options.module then
            existing.module = options.module
            ModuleRegistry.set(existing.registryName, module, {
                tags = { HUD_TAG },
                metadata = {
                    id = existing.id,
                    priority = options.priority or existing.priority,
                },
            })
        end

        existing.priority = options.priority or existing.priority
        existing.update = options.update or existing.update
        existing.draw = options.draw or existing.draw
        existing.init = options.init or existing.init

        return existing
    end

    local record = {
        id = options.id,
        loader = options.loader,
        module = options.module,
        registryName = registryName,
        priority = options.priority or 0,
        update = options.update,
        draw = options.draw,
        init = options.init,
    }

    registrations[options.id] = record

    ModuleRegistry.register(registryName, function()
        return ensureModule(record)
    end, {
        tags = { HUD_TAG },
        metadata = {
            id = record.id,
            priority = record.priority,
        },
    })

    if record.module and options.metadata then
        ModuleRegistry.set(registryName, record.module, {
            tags = { HUD_TAG },
            metadata = options.metadata,
        })
    end

    return record
end

function HUDRegistry.list()
    local entries = {}

    for id, record in pairs(registrations) do
        ensureModule(record)
        table.insert(entries, record)
    end

    -- Sort by priority (higher priority draws on top)
    table.sort(entries, function(a, b)
        local pa = a.priority or 0
        local pb = b.priority or 0
        if pa == pb then
            return a.id < b.id
        end
        return pa > pb
    end)

    return entries
end

function HUDRegistry.get(id)
    local record = registrations[id]
    if record then
        ensureModule(record)
    end
    return record
end

return HUDRegistry
