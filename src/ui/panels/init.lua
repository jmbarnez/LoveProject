local PanelRegistry = require("src.ui.core.panel_registry")

local function requireRegistration(moduleName)
    local ok, err = pcall(require, moduleName)
    if not ok then
        error(string.format("Failed to load UI panel registration '%s': %s", moduleName, err))
    end
end

local function loadDirectoryRegistrations()
    if not love or not love.filesystem or not love.filesystem.getDirectoryItems then
        return false
    end

    local ok, items = pcall(love.filesystem.getDirectoryItems, "src/ui/panels/registry")
    if not ok then
        return false
    end

    for _, file in ipairs(items) do
        if file:sub(-4) == ".lua" then
            local moduleName = file:sub(1, -5)
            requireRegistration("src.ui.panels.registry." .. moduleName)
        end
    end

    return true
end

local function loadFallbackRegistrations()
    local defaults = {
        "inventory",
        "ship",
        "skills",
        "docked",
        "map",
        "warp",
        "escape_menu",
        "settings",
        "repair_popup",
        "beacon_repair_popup",
        "reward_wheel",
        "debug",
    }

    for _, name in ipairs(defaults) do
        requireRegistration("src.ui.panels.registry." .. name)
    end
end

if not loadDirectoryRegistrations() then
    loadFallbackRegistrations()
end

return PanelRegistry
