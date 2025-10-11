--[[
    UIManager - New Modular System
    
    This is the new modular UIManager that replaces the monolithic original.
    It delegates to specialized modules for state management, input routing,
    rendering, and modal handling while maintaining the same public API.
]]

local Log = require("src.core.log")

-- Load the new modular UIManager
local NewUIManager = require("src.core.ui.manager")
Log.info("Using new modular UIManager")

return NewUIManager