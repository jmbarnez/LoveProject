--[[
    Inventory UI - Legacy Wrapper
    
    This file now serves as a backward-compatible wrapper around the new modular Inventory UI.
    All functionality has been moved to src/ui/inventory/ modules.
]]

-- Import the new modular Inventory UI
local ModularInventory = require("src.ui.inventory.init")

local Inventory = {}

function Inventory:new()
    -- Create instance using the new modular system
    return ModularInventory:new()
end

-- Delegate all methods to the modular system
function Inventory:draw()
    return self:draw()
end

function Inventory:update(dt)
    return self:update(dt)
end

function Inventory:mousepressed(x, y, button)
    return self:mousepressed(x, y, button)
end

function Inventory:mousereleased(x, y, button)
    return self:mousereleased(x, y, button)
end

function Inventory:mousemoved(x, y, dx, dy)
    return self:mousemoved(x, y, dx, dy)
end

function Inventory:keypressed(key)
    return self:keypressed(key)
end

function Inventory:textinput(text)
    return self:textinput(text)
end

function Inventory:show()
    return self:show()
end

function Inventory:hide()
    return self:hide()
end

function Inventory:isVisible()
    return self:isVisible()
end

function Inventory:resize(w, h)
    return self:resize(w, h)
end

-- Backward compatibility methods
function Inventory:clearSearchFocus()
    return self:clearSearchFocus()
end

function Inventory:isSearchInputActive()
    return self:isSearchInputActive()
end

return Inventory