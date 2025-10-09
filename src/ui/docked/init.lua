--[[
    Docked UI Main Orchestrator
    
    Coordinates all Docked UI modules and provides the main interface.
    Integrates with the panel registry system.
]]

local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local Content = require("src.content.content")
local Tooltip = require("src.ui.tooltip")
local Input = require("src.core.input")
local Notifications = require("src.ui.notifications")
local Quests = require("src.ui.quests")
local Nodes = require("src.ui.nodes")
local IconSystem = require("src.core.icon_system")
local Window = require("src.ui.common.window")
local UITabs = require("src.ui.common.tabs")
local UIUtils = require("src.ui.common.utils")
local Shop = require("src.ui.docked.shop")
local Dropdown = require("src.ui.common.dropdown")

-- Import all Docked UI modules
local DockedState = require("src.ui.docked.state")
local DockedTabs = require("src.ui.docked.tabs")
local Furnace = require("src.ui.docked.furnace")

local DockedUI = {}

function DockedUI:new()
    local o = {}
    setmetatable(o, DockedUI)
    DockedUI.__index = DockedUI
    
    -- Initialize state
    o.state = DockedState.new()
    
    -- Initialize window
    o.window = Window.new({
        title = "Station Interface",
        width = 900,
        height = 560,
        minWidth = 600,
        minHeight = 400,
        resizable = true
    })
    
    -- Initialize furnace
    o.furnace = Furnace.new()
    o.furnace:init()
    
    return o
end

function DockedUI:show(player, station)
    self.state:setVisible(true)
    self.state:setPlayer(player)
    
    if station then
        self.state:setStationType(station.type or "hub_station")
    end
    
    self.window:show()
    
    -- Reset furnace state
    if self.state:isFurnaceStation() then
        self.furnace:reset()
        self.furnace.state:setPlayer(player)
    end
end

function DockedUI:hide()
    self.state:setVisible(false)
    self.window:hide()
    
    -- Reset furnace
    if self.furnace then
        self.furnace:reset()
    end
end

function DockedUI:isVisible()
    return self.state:isVisible()
end

function DockedUI:isSearchActive()
    return self.state:isSearchActive()
end

function DockedUI:draw(player)
    if not self:isVisible() then return end
    
    local x, y = self.window.x, self.window.y
    local w, h = self.window.width, self.window.height
    
    -- Draw window
    self.window:draw()
    
    -- Draw tabs
    local tabH = 32
    DockedTabs.draw(self, x, y + 24, w, tabH)
    
    -- Draw content based on active tab
    local contentY = y + 24 + tabH
    local contentH = h - 24 - tabH
    
    local activeTab = DockedTabs.getActiveTab(self)
    
    if activeTab == "Shop" then
        self:drawShopContent(x, contentY, w, contentH)
    elseif activeTab == "Quests" then
        self:drawQuestsContent(x, contentY, w, contentH)
    elseif activeTab == "Nodes" then
        self:drawNodesContent(x, contentY, w, contentH)
    end
end

function DockedUI:drawShopContent(x, y, w, h)
    -- Check if this is a furnace station
    if self.state:isFurnaceStation() then
        self:drawFurnaceContent(x, y, w, h)
        return
    end
    
    -- Regular shop content
    local shop = Shop
    if shop and shop.draw then
        shop.draw(self.state:getPlayer(), x, y, w, h)
    else
        -- Fallback shop rendering
        self:drawFallbackShop(x, y, w, h)
    end
end

function DockedUI:drawFurnaceContent(x, y, w, h)
    if self.furnace then
        self.furnace:draw(self.window, x, y, w, h)
    end
end

function DockedUI:drawQuestsContent(x, y, w, h)
    -- Background
    Theme.setColor(Theme.colors.bg1)
    love.graphics.rectangle("fill", x, y, w, h)
    
    -- Border
    Theme.setColor(Theme.colors.border)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h)
    
    -- Title
    Theme.setColor(Theme.colors.text)
    Theme.setFont("medium")
    love.graphics.print("Quests", x + 12, y + 12)
    
    -- Quest content would go here
    Theme.setColor(Theme.colors.textSecondary)
    Theme.setFont("small")
    love.graphics.print("Quest system not yet implemented", x + 12, y + 40)
end

function DockedUI:drawNodesContent(x, y, w, h)
    -- Background
    Theme.setColor(Theme.colors.bg1)
    love.graphics.rectangle("fill", x, y, w, h)
    
    -- Border
    Theme.setColor(Theme.colors.border)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h)
    
    -- Title
    Theme.setColor(Theme.colors.text)
    Theme.setFont("medium")
    love.graphics.print("Node Market", x + 12, y + 12)
    
    -- Node content would go here
    Theme.setColor(Theme.colors.textSecondary)
    Theme.setFont("small")
    love.graphics.print("Node market not yet integrated", x + 12, y + 40)
end

function DockedUI:drawFallbackShop(x, y, w, h)
    -- Background
    Theme.setColor(Theme.colors.bg1)
    love.graphics.rectangle("fill", x, y, w, h)
    
    -- Border
    Theme.setColor(Theme.colors.border)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h)
    
    -- Title
    Theme.setColor(Theme.colors.text)
    Theme.setFont("medium")
    love.graphics.print("Shop", x + 12, y + 12)
    
    -- Shop content would go here
    Theme.setColor(Theme.colors.textSecondary)
    Theme.setFont("small")
    love.graphics.print("Shop system not yet integrated", x + 12, y + 40)
end

function DockedUI:update(dt)
    if not self:isVisible() then return end
    
    -- Update furnace
    if self.furnace then
        self.furnace:update(dt)
    end
end

function DockedUI:mousepressed(x, y, button, player)
    if not self:isVisible() then return false end
    
    -- Check if click is within window bounds
    if not self.window:isPointInside(x, y) then
        return false
    end
    
    local w = self.window.width
    local tabH = 32
    local tabY = self.window.y + 24
    
    -- Handle tab clicks
    if DockedTabs.handleClick(self, x, y, self.window.x, tabY, w) then
        return true
    end
    
    -- Handle furnace input
    if self.state:isFurnaceStation() and self.furnace then
        local contentY = self.window.y + 24 + tabH
        local contentH = self.window.height - 24 - tabH
        if self.furnace:mousepressed(x, y, button) then
            return true
        end
    end
    
    return false
end

function DockedUI:mousereleased(x, y, button, player)
    if not self:isVisible() then return false end
    
    -- Handle furnace input
    if self.state:isFurnaceStation() and self.furnace then
        return self.furnace:mousereleased(x, y, button)
    end
    
    return false
end

function DockedUI:mousemoved(x, y, dx, dy, player)
    if not self:isVisible() then return false end
    
    -- Handle furnace input
    if self.state:isFurnaceStation() and self.furnace then
        return self.furnace:mousemoved(x, y, dx, dy)
    end
    
    return false
end

function DockedUI:keypressed(key)
    if not self:isVisible() then return false end
    
    -- Handle furnace input
    if self.state:isFurnaceStation() and self.furnace then
        return self.furnace:keypressed(key)
    end
    
    return false
end

function DockedUI:textinput(text)
    if not self:isVisible() then return false end
    
    -- Handle furnace input
    if self.state:isFurnaceStation() and self.furnace then
        return self.furnace:textinput(text)
    end
    
    return false
end

function DockedUI:resize(w, h)
    if self.window then
        self.window:resize(w, h)
    end
end

-- Backward compatibility methods
function DockedUI:drawFurnaceContent(window, x, y, w, h)
    if self.furnace then
        self.furnace:draw(window, x, y, w, h)
    end
end

function DockedUI:handleFurnaceMousePressed(x, y, button)
    if self.furnace then
        return self.furnace:mousepressed(x, y, button)
    end
    return false
end

return DockedUI
