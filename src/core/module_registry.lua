local Log = require("src.core.log")

local ModuleRegistry = {}

local lazyLoaders = {}
local loadedModules = {}
local metadataByName = {}
local tagsIndex = {}

local function shallowCopy(source)
    if not source then
        return nil
    end

    local copy = {}
    for key, value in pairs(source) do
        copy[key] = value
    end

    return copy
end

local function validateName(name)
    assert(type(name) == "string" and name ~= "", "Module name must be a non-empty string")
    return name
end

local function validateLoader(loader)
    assert(type(loader) == "function", "Module loader must be a function")
    return loader
end

local function normalizeTags(tags)
    if not tags then
        return nil
    end

    local normalized = {}

    if type(tags) == "string" then
        normalized[1] = tags
        return normalized
    end

    for _, tag in ipairs(tags) do
        table.insert(normalized, tag)
    end

    return normalized
end

local function applyMetadata(name, opts)
    if not opts then
        return
    end

    local metadata = metadataByName[name]
    if not metadata then
        metadata = {}
        metadataByName[name] = metadata
    end

    if opts.metadata then
        for key, value in pairs(opts.metadata) do
            metadata[key] = value
        end
    end

    local tags = normalizeTags(opts.tags)
    if tags then
        for _, tag in ipairs(tags) do
            if not tagsIndex[tag] then
                tagsIndex[tag] = {}
            end
            tagsIndex[tag][name] = true
        end
    end
end

local function registerLoader(name, loader)
    if not loader then
        return
    end

    validateLoader(loader)
    lazyLoaders[name] = loader
end

function ModuleRegistry.register(name, loader, opts)
    validateName(name)

    if type(loader) == "table" then
        opts = loader
        loader = opts.loader
    end

    opts = opts or {}

    if opts.module ~= nil then
        ModuleRegistry.set(name, opts.module, opts)
    end

    registerLoader(name, loader)
    applyMetadata(name, opts)
end

function ModuleRegistry.registerMany(entries)
    assert(type(entries) == "table", "registerMany expects a table of loader functions or descriptors")
    for name, descriptor in pairs(entries) do
        if type(descriptor) == "table" and (descriptor.loader or descriptor.module or descriptor.metadata or descriptor.tags) then
            ModuleRegistry.register(name, descriptor.loader, descriptor)
        else
            ModuleRegistry.register(name, descriptor)
        end
    end
end

function ModuleRegistry.set(name, module, opts)
    validateName(name)
    loadedModules[name] = module
    applyMetadata(name, opts)
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

function ModuleRegistry.getMetadata(name)
    return shallowCopy(metadataByName[name])
end

function ModuleRegistry.listByTag(tag)
    assert(type(tag) == "string" and tag ~= "", "Tag must be a non-empty string")

    local bucket = tagsIndex[tag]
    if not bucket then
        return {}
    end

    local modules = {}

    for name in pairs(bucket) do
        local module = ModuleRegistry.get(name)
        if module then
            table.insert(modules, {
                name = name,
                module = module,
                metadata = ModuleRegistry.getMetadata(name) or {},
            })
        end
    end

    table.sort(modules, function(a, b)
        return a.name < b.name
    end)

    return modules
end

return ModuleRegistry
