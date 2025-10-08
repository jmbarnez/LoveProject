local Log = require("src.core.log")

local ModuleRegistry = {}

local lazyLoaders = {}
local loadedModules = {}

local function validateName(name)
    assert(type(name) == "string" and name ~= "", "Module name must be a non-empty string")
    return name
end

local function validateLoader(loader)
    assert(type(loader) == "function", "Module loader must be a function")
    return loader
end

function ModuleRegistry.register(name, loader)
    validateName(name)
    validateLoader(loader)
    lazyLoaders[name] = loader
end

function ModuleRegistry.registerMany(entries)
    assert(type(entries) == "table", "registerMany expects a table of loader functions")
    for name, loader in pairs(entries) do
        ModuleRegistry.register(name, loader)
    end
end

function ModuleRegistry.set(name, module)
    validateName(name)
    loadedModules[name] = module
end

function ModuleRegistry.isLoaded(name)
    return loadedModules[name] ~= nil
end

function ModuleRegistry.clear(name)
    if name then
        loadedModules[name] = nil
        return
    end

    for key in pairs(loadedModules) do
        loadedModules[key] = nil
    end
end

function ModuleRegistry.get(name, onLazyLoad)
    validateName(name)

    if loadedModules[name] then
        return loadedModules[name], false
    end

    local loader = lazyLoaders[name]
    if not loader then
        Log.error("Attempted to resolve unknown module: " .. name)
        return nil, false
    end

    local startTime
    if love and love.timer and love.timer.getTime then
        startTime = love.timer.getTime()
    end

    local module = loader()
    loadedModules[name] = module

    if startTime and onLazyLoad then
        local loadTime = (love.timer.getTime() - startTime) * 1000
        onLazyLoad(loadTime)
    elseif onLazyLoad then
        onLazyLoad(nil)
    end

    return module, true
end

return ModuleRegistry
