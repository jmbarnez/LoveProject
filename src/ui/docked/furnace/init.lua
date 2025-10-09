--[[
    Furnace Module - Main Orchestrator
    
    Coordinates all furnace functionality including:
    - Recipe management
    - UI rendering
    - Input handling
    - Smelting operations
]]

local FurnaceState = require("src.ui.docked.furnace.state")
local FurnaceRecipes = require("src.ui.docked.furnace.recipes")
local FurnaceUI = require("src.ui.docked.furnace.ui")
local FurnaceInput = require("src.ui.docked.furnace.input")

local Furnace = {}

function Furnace.new()
    local o = {}
    setmetatable(o, Furnace)
    Furnace.__index = Furnace
    
    -- Initialize state
    o.state = FurnaceState.new()
    
    return o
end

function Furnace:init()
    -- Initialize recipes
    FurnaceRecipes.init()
end

function Furnace:draw(window, x, y, w, h)
    return FurnaceUI.draw(self, window, x, y, w, h)
end

function Furnace:update(dt)
    -- Update furnace state
    if self.state then
        self.state:update(dt)
    end
end

function Furnace:mousepressed(x, y, button)
    return FurnaceInput.mousepressed(self, x, y, button)
end

function Furnace:mousereleased(x, y, button)
    return FurnaceInput.mousereleased(self, x, y, button)
end

function Furnace:mousemoved(x, y, dx, dy)
    return FurnaceInput.mousemoved(self, x, y, dx, dy)
end

function Furnace:keypressed(key)
    return FurnaceInput.keypressed(self, key)
end

function Furnace:textinput(text)
    return FurnaceInput.textinput(self, text)
end

function Furnace:reset()
    if self.state then
        self.state:reset()
    end
end

function Furnace:isInputActive()
    return self.state and self.state.inputActive
end

return Furnace
