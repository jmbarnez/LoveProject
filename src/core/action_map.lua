local Settings = require("src.core.settings")
local Events = require("src.core.events")

local ActionMap = {}

local registeredActions = {}

print("ACTION MAP LOADED!")


local function normalizeKeys(value)
    local keys = {}
    if type(value) == "string" then
        table.insert(keys, value)
    elseif type(value) == "table" then
        for _, key in ipairs(value) do
            if type(key) == "string" then
                table.insert(keys, key)
            end
        end
    end
    return keys
end

local function mergeKeys(primaryKeys, fallbackKeys)
    local seen = {}
    local merged = {}

    local function addKey(key)
        if key and not seen[key] then
            table.insert(merged, key)
            seen[key] = true
        end
    end

    for _, key in ipairs(primaryKeys) do
        addKey(key)
    end

    for _, key in ipairs(normalizeKeys(fallbackKeys)) do
        addKey(key)
    end

    return merged
end

function ActionMap.bindingKeys(actionName, fallbackKeys)
    local binding = Settings.getBinding(actionName)
    local keys = {}

    if type(binding) == "table" then
        local order = { "primary", "secondary", "tertiary" }
        for _, slot in ipairs(order) do
            local key = binding[slot]
            if type(key) == "string" then
                table.insert(keys, key)
            end
        end
        for slot, key in pairs(binding) do
            if type(slot) == "string" and type(key) == "string" then
                local alreadyListed = false
                for _, existing in ipairs(keys) do
                    if existing == key then
                        alreadyListed = true
                        break
                    end
                end
                if not alreadyListed then
                    table.insert(keys, key)
                end
            end
        end
    elseif type(binding) == "string" then
        table.insert(keys, binding)
    end

    return mergeKeys(keys, fallbackKeys)
end

function ActionMap.registerAction(descriptor)
    assert(descriptor and descriptor.name, "Action descriptor must include a name")
    descriptor.priority = descriptor.priority or 0
    table.insert(registeredActions, descriptor)
end

local function sortByPriority(actions)
    table.sort(actions, function(a, b)
        return (a.priority or 0) < (b.priority or 0)
    end)
    return actions
end

function ActionMap.getActionsForKey(key)
    local matches = {}
    for _, descriptor in ipairs(registeredActions) do
        local keys = descriptor.getKeys and descriptor.getKeys() or descriptor.keys or {}
        for _, mappedKey in ipairs(keys) do
            if mappedKey == key then
                table.insert(matches, descriptor)
                break
            end
        end
    end
    return sortByPriority(matches)
end

function ActionMap.dispatch(key, context)
    local actions = ActionMap.getActionsForKey(key)
    for _, action in ipairs(actions) do
        if not action.enabled or action.enabled(context) then
            local handled = action.callback(context)
            if handled then
                return true, action
            end
        end
    end
    return false, nil
end

function ActionMap.iterate()
    return ipairs(registeredActions)
end


local function resolveUIManager(ctx)
    if ctx and ctx.UIManager then
        return ctx.UIManager
    end

    local loaded = package.loaded["src.core.ui_manager"]
    if type(loaded) == "table" then
        return loaded
    end

    return nil
end

local function ensureToggleCallback(component)
    return function(ctx)
        -- Always route toggles through the central UIManager module
        local ok, UIManager = pcall(require, "src.core.ui_manager")
        if not ok or not UIManager then return false end
        if UIManager.toggle then
            UIManager.toggle(component)
            return true
        end
        -- If toggle not available, try explicit open/close on UIManager
        if UIManager.isOpen and UIManager.isOpen(component) then
            if UIManager.close then UIManager.close(component) end
            return true
        else
            if UIManager.open then UIManager.open(component) end
            return true
        end
        return false
    end
end

local function toggleAction(name, bindingAction, component)
    ActionMap.registerAction({
        name = name,
        priority = 5,
        getKeys = function()
            return ActionMap.bindingKeys(bindingAction)
        end,
        enabled = function(ctx)
            local ui = resolveUIManager(ctx)
            return ui ~= nil and ui.open ~= nil and ui.close ~= nil and ui.isOpen ~= nil
        end,
        callback = ensureToggleCallback(component),
    })
end

toggleAction("toggle_inventory", "toggle_inventory", "inventory")
toggleAction("toggle_ship", "toggle_ship", "ship")
toggleAction("toggle_skills", "toggle_skills", "skills")
toggleAction("toggle_map", "toggle_map", "map")



ActionMap.registerAction({
    name = "repair_beacon",
    priority = 20,
    getKeys = function()
        return ActionMap.bindingKeys("repair_beacon")
    end,
    enabled = function(ctx)
        return ctx and ctx.player ~= nil and ctx.world ~= nil and ctx.repairSystem ~= nil
    end,
    callback = function(ctx)
        local player = ctx.player
        local world = ctx.world
        local repairSystem = ctx.repairSystem
        if not (player and world and repairSystem) then return false end

        local position = player.components and player.components.position
        if not position then return false end

        local stations = world.get_entities_with_components and world:get_entities_with_components("repairable")
        if not stations then return false end

        for _, station in ipairs(stations) do
            local repairable = station.components and station.components.repairable
            if repairable and repairable.broken then
                local pos = station.components.position
                if pos then
                    local dx = pos.x - position.x
                    local dy = pos.y - position.y
                    local distance = math.sqrt(dx * dx + dy * dy)
                    if distance <= 200 then
                        local success = repairSystem.tryRepair(station, player)
                        if ctx.notifications and ctx.notifications.add then
                            if success then
                                ctx.notifications.add("Beacon station repaired successfully!", "success")
                            else
                                ctx.notifications.add("Insufficient materials for repair", "error")
                            end
                        end
                        return true
                    end
                end
            end
        end

        return false
    end,
})

ActionMap.registerAction({
    name = "toggle_fullscreen",
    priority = 30,
    getKeys = function()
        return { "f11" }
    end,
    callback = function()
        if not love or not love.window then
            return false
        end

        local wasFullscreen = love.window.getFullscreen()
        local toggled = love.window.setFullscreen(not wasFullscreen, "desktop")

        if not toggled then
            return false
        end

        local width, height = love.graphics.getDimensions()

        -- Make sure the viewport and active UIs pick up the new backbuffer size.
        if love.handlers and love.handlers.resize then
            love.handlers.resize(width, height)
        elseif love.resize then
            love.resize(width, height)
        end

        local Settings = require("src.core.settings")
        local graphicsSettings = Settings.getGraphicsSettings()
        if graphicsSettings then
            graphicsSettings.fullscreen = not wasFullscreen
            graphicsSettings.fullscreen_type = "desktop"

            if not graphicsSettings.resolution then
                graphicsSettings.resolution = {}
            end
            graphicsSettings.resolution.width = width
            graphicsSettings.resolution.height = height
        end

        return true
    end,
})

print("REGISTERING F3 ACTION!")
ActionMap.registerAction({
    name = "toggle_multiplayer_host",
    priority = 25,
    getKeys = function()
        return { "f3" }
    end,
    enabled = function(ctx)
        return ctx and ctx.player ~= nil and ctx.world ~= nil
    end,
    callback = function(ctx)
        local Log = require("src.core.log")
        local Game = require("src.game")
        local Notifications = require("src.ui.notifications")
        
        print("F3 KEY PRESSED!")
        Log.info("F3 key pressed - attempting to toggle multiplayer hosting")
        print("Current state - isMultiplayer:", Game.isMultiplayer(), "isHost:", Game.isHost())

        local success, result = Game.toggleLanHosting()
        if not success then
            if result == "no_network" then
                Notifications.add("Network manager not available", "error")
            else
                Notifications.add("Failed to start multiplayer server", "error")
            end
            return false
        end

        if result == "lan_opened" then
            Notifications.add("Opened current world to LAN players (F3 to close)", "success")
        elseif result == "lan_closed" then
            Notifications.add("Stopped hosting multiplayer game", "info")
        else
            Notifications.add("Left multiplayer game", "info")
        end

        return true
    end,
})



return ActionMap
