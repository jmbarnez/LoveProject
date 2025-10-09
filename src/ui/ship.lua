--[[
    Ship UI - Legacy Wrapper
    
    This file now serves as a backward-compatible wrapper around the new modular Ship UI.
    All functionality has been moved to src/ui/ship/ modules.
]]

-- Import the new modular Ship UI
local ModularShip = require("src.ui.ship.init")

local Ship = {}

function Ship:new()
    -- Create instance using the new modular system
    return ModularShip:new()
end

-- Delegate all methods to the modular system
function Ship:draw()
    return self:draw()
end

function Ship:update(dt)
    return self:update(dt)
end

function Ship:mousepressed(x, y, button)
    return self:mousepressed(x, y, button)
end

function Ship:mousereleased(x, y, button)
    return self:mousereleased(x, y, button)
end

function Ship:mousemoved(x, y, dx, dy)
    return self:mousemoved(x, y, dx, dy)
end

function Ship:keypressed(key)
    return self:keypressed(key)
end

function Ship:textinput(text)
    return self:textinput(text)
end

function Ship:show()
    return self:show()
end

function Ship:hide()
    return self:hide()
end

function Ship:isVisible()
    return self:isVisible()
end

function Ship:resize(w, h)
    return self:resize(w, h)
end

-- Backward compatibility methods
function Ship:ensure()
    return self:ensure()
end

function Ship:drawDropdownOptions()
    return self:drawDropdownOptions()
end

return Ship
