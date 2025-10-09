--[[
    Docked UI - Legacy Wrapper
    
    This file now serves as a backward-compatible wrapper around the new modular Docked UI.
    All functionality has been moved to src/ui/docked/ modules.
]]

-- Import the new modular Docked UI
local ModularDocked = require("src.ui.docked.init")

local DockedUI = {}

function DockedUI:new()
    -- Create instance using the new modular system
    return ModularDocked:new()
end

-- Delegate all methods to the modular system
function DockedUI:draw(player)
    return self:draw(player)
end

function DockedUI:update(dt)
    return self:update(dt)
end

function DockedUI:mousepressed(x, y, button, player)
    return self:mousepressed(x, y, button, player)
end

function DockedUI:mousereleased(x, y, button, player)
    return self:mousereleased(x, y, button, player)
end

function DockedUI:mousemoved(x, y, dx, dy, player)
    return self:mousemoved(x, y, dx, dy, player)
end

function DockedUI:keypressed(key)
    return self:keypressed(key)
end

function DockedUI:textinput(text)
    return self:textinput(text)
end

function DockedUI:show(player, station)
    return self:show(player, station)
end

function DockedUI:hide()
    return self:hide()
end

function DockedUI:isVisible()
    return self:isVisible()
end

function DockedUI:isSearchActive()
    return self:isSearchActive()
end

function DockedUI:resize(w, h)
    return self:resize(w, h)
end

-- Backward compatibility methods
function DockedUI:drawFurnaceContent(window, x, y, w, h)
    return self:drawFurnaceContent(window, x, y, w, h)
end

function DockedUI:handleFurnaceMousePressed(x, y, button)
    return self:handleFurnaceMousePressed(x, y, button)
end

return DockedUI
