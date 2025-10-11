local HUDRegistry = require("src.ui.hud.registry")

local function requireRegistration(moduleName)
    local ok, err = pcall(require, moduleName)
    if not ok then
        error(string.format("Failed to load HUD component registration '%s': %s", moduleName, err))
    end
end

local function loadDirectoryRegistrations()
    if not love or not love.filesystem or not love.filesystem.getDirectoryItems then
        return false
    end

    local ok, items = pcall(love.filesystem.getDirectoryItems, "src/ui/hud/registrations")
    if not ok then
        return false
    end

    for _, file in ipairs(items) do
        if file:sub(-4) == ".lua" then
            local moduleName = file:sub(1, -5)
            requireRegistration("src.ui.hud.registrations." .. moduleName)
        end
    end

    return true
end

local function loadFallbackRegistrations()
    local defaults = {
        "cursor",
        "notifications", 
        "experience_notification",
        "tooltip_manager",
    }

    for _, name in ipairs(defaults) do
        requireRegistration("src.ui.hud.registrations." .. name)
    end
end

if not loadDirectoryRegistrations() then
    loadFallbackRegistrations()
end

return HUDRegistry
