--[[
    Nodes UI - Legacy Wrapper
    
    This file now serves as a backward-compatible wrapper around the new modular Nodes UI.
    All functionality has been moved to src/ui/nodes/ modules.
]]

-- Import the new modular Nodes UI
local ModularNodes = require("src.ui.nodes.init")

local Nodes = {}

function Nodes:new()
    -- Create instance using the new modular system
    return ModularNodes:new()
end

-- Delegate all methods to the modular system
function Nodes:draw(player, x, y, w, h)
    return self:draw(player, x, y, w, h)
end

function Nodes:update(dt)
    return self:update(dt)
end

function Nodes:mousepressed(player, x, y, button)
    return self:mousepressed(player, x, y, button)
end

function Nodes:mousereleased(player, x, y, button)
    return self:mousereleased(player, x, y, button)
end

function Nodes:mousemoved(player, x, y, dx, dy)
    return self:mousemoved(player, x, y, dx, dy)
end

function Nodes:wheelmoved(player, dx, dy)
    return self:wheelmoved(player, dx, dy)
end

function Nodes:textinput(text)
    return self:textinput(text)
end

function Nodes:keypressed(playerOrKey, maybeKey)
    return self:keypressed(playerOrKey, maybeKey)
end

function Nodes:executeBuy(player)
    return self:executeBuy(player)
end

function Nodes:executeSell(player)
    return self:executeSell(player)
end

function Nodes:show()
    return self:show()
end

function Nodes:hide()
    return self:hide()
end

function Nodes:isVisible()
    return self:isVisible()
end

function Nodes:resize(w, h)
    return self:resize(w, h)
end

return Nodes