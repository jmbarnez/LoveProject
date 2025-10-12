--[[
    Centralized Debug System
    
    Provides conditional compilation and debug logging capabilities
    throughout the application. All debug code should use this system
    instead of scattered debug flags and commented code.
]]

local Debug = {}

-- Debug flags - set these to control debug output
Debug.flags = {
    -- Core systems
    events = false,
    physics = false,
    collision = false,
    rendering = false,
    
    -- Game systems
    ai = false,
    spawning = false,
    destruction = false,
    player = false,
    game = true,
    
    -- UI systems
    ui_manager = false,
    input = false,
    hotbar = false,
    
    -- Content systems
    content_loading = false,
    entity_factory = false,
    
    -- Performance
    performance = false,
    memory = false,
    
    -- Development
    development = false,
}

-- Debug levels
Debug.levels = {
    TRACE = 1,
    DEBUG = 2,
    INFO = 3,
    WARN = 4,
    ERROR = 5
}

-- Current debug level (only show messages at this level or higher)
Debug.currentLevel = Debug.levels.INFO

-- Debug output functions
function Debug.trace(flag, message, ...)
    if Debug.flags[flag] and Debug.currentLevel <= Debug.levels.TRACE then
        print("[TRACE][" .. flag .. "] " .. string.format(message, ...))
    end
end

function Debug.debug(flag, message, ...)
    if Debug.flags[flag] and Debug.currentLevel <= Debug.levels.DEBUG then
        print("[DEBUG][" .. flag .. "] " .. string.format(message, ...))
    end
end

function Debug.info(flag, message, ...)
    if Debug.flags[flag] and Debug.currentLevel <= Debug.levels.INFO then
        print("[INFO][" .. flag .. "] " .. string.format(message, ...))
    end
end

function Debug.warn(flag, message, ...)
    if Debug.flags[flag] and Debug.currentLevel <= Debug.levels.WARN then
        print("[WARN][" .. flag .. "] " .. string.format(message, ...))
    end
end

function Debug.error(flag, message, ...)
    if Debug.flags[flag] and Debug.currentLevel <= Debug.levels.ERROR then
        print("[ERROR][" .. flag .. "] " .. string.format(message, ...))
    end
end

-- Enable/disable specific debug flags
function Debug.enable(flag)
    if Debug.flags[flag] ~= nil then
        Debug.flags[flag] = true
    end
end

function Debug.disable(flag)
    if Debug.flags[flag] ~= nil then
        Debug.flags[flag] = false
    end
end

-- Enable/disable all debug flags
function Debug.enableAll()
    for flag, _ in pairs(Debug.flags) do
        Debug.flags[flag] = true
    end
end

function Debug.disableAll()
    for flag, _ in pairs(Debug.flags) do
        Debug.flags[flag] = false
    end
end

-- Set debug level
function Debug.setLevel(level)
    if type(level) == "string" then
        level = Debug.levels[level:upper()]
    end
    if level then
        Debug.currentLevel = level
    end
end

-- Check if a debug flag is enabled
function Debug.isEnabled(flag)
    return Debug.flags[flag] == true
end

-- Development mode - enables common debug flags
function Debug.enableDevelopmentMode()
    Debug.enable("events")
    Debug.enable("ui_manager")
    Debug.enable("input")
    Debug.enable("development")
    Debug.setLevel("DEBUG")
end

-- Production mode - disables all debug output
function Debug.enableProductionMode()
    Debug.disableAll()
    Debug.setLevel("ERROR")
end

-- Performance profiling helpers
local performanceData = {}

function Debug.startTimer(name)
    if Debug.isEnabled("performance") then
        performanceData[name] = love.timer.getTime()
    end
end

function Debug.endTimer(name)
    if Debug.isEnabled("performance") and performanceData[name] then
        local elapsed = love.timer.getTime() - performanceData[name]
        Debug.debug("performance", "Timer '%s': %.3fms", name, elapsed * 1000)
        performanceData[name] = nil
    end
end

-- Memory usage tracking
function Debug.logMemory(flag, context)
    if Debug.isEnabled("memory") then
        local mem = collectgarbage("count")
        Debug.debug("memory", "Memory usage in %s: %.2f KB", context or "unknown", mem)
    end
end

-- Conditional execution - only run code if debug flag is enabled
function Debug.ifEnabled(flag, func)
    if Debug.isEnabled(flag) then
        func()
    end
end

-- Initialize debug system
function Debug.init()
    -- Set default mode based on environment
    if love and love.filesystem and love.filesystem.getInfo("debug.flag") then
        Debug.enableDevelopmentMode()
    else
        Debug.enableProductionMode()
    end
end

return Debug
