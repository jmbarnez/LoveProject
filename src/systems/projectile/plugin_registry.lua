local Log = require("src.core.log")

local PluginRegistry = {}

local plugins = {}

function PluginRegistry.register(name, plugin)
    if type(name) ~= "string" or name == "" then return end
    if type(plugin) ~= "function" then return end

    if plugins[name] then
        Log.warn("Projectile plugin '" .. name .. "' is being overwritten")
    end

    plugins[name] = plugin
end

function PluginRegistry.apply(name, context)
    local plugin = plugins[name]
    if not plugin then return end

    local ok, err = pcall(plugin, context)
    if not ok then
        Log.warn("Projectile plugin '" .. tostring(name) .. "' failed: " .. tostring(err))
    end
end

function PluginRegistry.available(name)
    return plugins[name] ~= nil
end

return PluginRegistry
