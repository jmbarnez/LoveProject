--[[
    Inventory UI Main Orchestrator
    
    Coordinates all Inventory UI modules and provides the main interface.
    Integrates with the panel registry system.
]]

local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local Content = require("src.content.content")
local Input = require("src.core.input")
local Util = require("src.core.util")
local Tooltip = require("src.ui.tooltip")
local IconSystem = require("src.core.icon_system")
local AuroraTitle = require("src.shaders.aurora_title")
local PlayerRef = require("src.core.player_ref")
local Window = require("src.ui.common.window")

-- Import all Inventory UI modules
local InventoryState = require("src.ui.inventory.state")
local InventoryFilters = require("src.ui.inventory.filters")
local ItemGrid = require("src.ui.inventory.item_grid")
local ContextMenu = require("src.ui.inventory.context_menu")
local ItemActions = require("src.ui.inventory.item_actions")
local RewardCrates = require("src.ui.inventory.reward_crates")

local Inventory = {}

function Inventory:new()
    local o = {}
    setmetatable(o, Inventory)
    Inventory.__index = Inventory
    
    -- Initialize state
    o.state = InventoryState.new()
    
    -- Initialize window
    o.window = Window.new({
        title = "Inventory",
        width = 520,
        height = 400,
        minWidth = 300,
        minHeight = 200,
        resizable = true
    })
    
    -- Initialize visibility
    o.visible = false
    
    return o
end

function Inventory:init()
    -- Initialize aurora shader
    if AuroraTitle then
        self.state:setAuroraShader(AuroraTitle)
    end
end

function Inventory:show()
    self.visible = true
    self.window:show()
    
    -- Update state from player
    self:updateFromPlayer()
end

function Inventory:hide()
    self.visible = false
    self.window:hide()
    
    -- Clear search focus
    self.state:clearSearchFocus()
end

function Inventory:isVisible()
    return self.visible
end

function Inventory:isSearchActive()
    return self.state:isSearchActive()
end

function Inventory:draw()
    if not self.visible then return end
    
    local x, y = self.window.x, self.window.y
    local w, h = self.window.height, self.window.height
    
    -- Draw window
    self.window:draw()
    
    -- Draw search and filter controls
    self:drawSearchControls(x + 12, y + 40, w - 24, 30)
    
    -- Draw item grid
    local gridY = y + 80
    local gridH = h - 120
    ItemGrid.draw(self, x + 12, gridY, w - 24, gridH)
    
    -- Draw context menu
    ContextMenu.draw(self, x, y, w, h)
end

function Inventory:drawSearchControls(x, y, w, h)
    local state = self.state
    
    -- Search input
    local searchW = w * 0.6
    local searchH = 24
    local searchX = x
    local searchY = y
    
    -- Search label
    Theme.setColor(Theme.colors.textSecondary)
    Theme.setFont("small")
    love.graphics.print("Search:", searchX, searchY - 16)
    
    -- Search input background
    local bgColor = state:isSearchActive() and Theme.colors.bg3 or Theme.colors.bg2
    Theme.setColor(bgColor)
    love.graphics.rectangle("fill", searchX, searchY, searchW, searchH)
    
    -- Search input border
    local borderColor = state:isSearchActive() and Theme.colors.borderBright or Theme.colors.border
    Theme.setColor(borderColor)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", searchX, searchY, searchW, searchH)
    
    -- Search input text
    Theme.setColor(Theme.colors.text)
    Theme.setFont("small")
    local searchText = state:getSearchText()
    love.graphics.print(searchText, searchX + 4, searchY + 6)
    
    -- Cursor (if active)
    if state:isSearchActive() then
        local cursorX = searchX + 4 + Theme.fonts.small:getWidth(searchText)
        local cursorY = searchY + 6
        local cursorH = Theme.fonts.small:getHeight()
        Theme.setColor(Theme.colors.text)
        love.graphics.rectangle("fill", cursorX, cursorY, 1, cursorH)
    end
    
    -- Sort controls
    local sortX = searchX + searchW + 10
    local sortW = w - searchW - 10
    local sortH = 24
    
    -- Sort label
    Theme.setColor(Theme.colors.textSecondary)
    love.graphics.print("Sort:", sortX, searchY - 16)
    
    -- Sort dropdown background
    Theme.setColor(Theme.colors.bg2)
    love.graphics.rectangle("fill", sortX, searchY, sortW, sortH)
    
    -- Sort dropdown border
    Theme.setColor(Theme.colors.border)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", sortX, searchY, sortW, sortH)
    
    -- Sort text
    Theme.setColor(Theme.colors.text)
    local sortText = state:getSortBy() .. " (" .. state:getSortOrder() .. ")"
    love.graphics.print(sortText, sortX + 4, searchY + 6)
    
    -- Store rects for interaction
    state:setSearchRect({x = searchX, y = searchY, w = searchW, h = searchH})
    state:setSortRect({x = sortX, y = searchY, w = sortW, h = sortH})
end

function Inventory:update(dt)
    if not self.visible then return end
    
    -- Update hover timer
    local hoverTimer = self.state:getHoverTimer()
    if hoverTimer > 0 then
        self.state:setHoverTimer(hoverTimer - dt)
    end
    
    -- Update state from player
    self:updateFromPlayer()
end

function Inventory:updateFromPlayer()
    local player = PlayerRef.get()
    if player then
        self.state:setPlayer(player)
    end
end

function Inventory:mousepressed(x, y, button)
    if not self.visible then return false end
    
    -- Check if click is within window bounds
    if not self.window:isPointInside(x, y) then
        return false
    end
    
    -- Handle context menu clicks
    if ContextMenu.handleClick(self, x, y, button) then
        return true
    end
    
    -- Handle search input clicks
    local searchRect = self.state:getSearchRect()
    if searchRect and x >= searchRect.x and x < searchRect.x + searchRect.w and
       y >= searchRect.y and y < searchRect.y + searchRect.h then
        self.state:setSearchActive(true)
        if love and love.keyboard and love.keyboard.setTextInput then
            love.keyboard.setTextInput(true)
        end
        return true
    end
    
    -- Handle item grid clicks
    if ItemGrid.handleItemClick(self, x, y, button) then
        return true
    end
    
    return false
end

function Inventory:mousereleased(x, y, button)
    if not self.visible then return false end
    
    -- Handle drag end
    if self.state:getDrag() then
        return ItemGrid.endDrag(self, x, y)
    end
    
    return false
end

function Inventory:mousemoved(x, y, dx, dy)
    if not self.visible then return false end
    
    -- Handle drag update
    if self.state:getDrag() then
        ItemGrid.updateDrag(self, x, y)
        return true
    end
    
    -- Handle item hover
    if ItemGrid.handleItemHover(self, x, y) then
        return true
    end
    
    return false
end

function Inventory:keypressed(key)
    if not self.visible then return false end
    
    -- Handle search input
    if self.state:isSearchActive() then
        if key == "return" or key == "kpenter" then
            self.state:setSearchActive(false)
            if love and love.keyboard and love.keyboard.setTextInput then
                love.keyboard.setTextInput(false)
            end
            return true
        elseif key == "escape" then
            self.state:setSearchActive(false)
            if love and love.keyboard and love.keyboard.setTextInput then
                love.keyboard.setTextInput(false)
            end
            return true
        elseif key == "backspace" then
            local searchText = self.state:getSearchText()
            if #searchText > 0 then
                self.state:setSearchText(searchText:sub(1, -2))
            end
            return true
        end
    end
    
    -- Handle escape to close context menu
    if key == "escape" then
        if self.state:isContextMenuActive() then
            ContextMenu.close(self)
            return true
        end
    end
    
    return false
end

function Inventory:textinput(text)
    if not self.visible then return false end
    
    -- Handle search input
    if self.state:isSearchActive() then
        local searchText = self.state:getSearchText()
        self.state:setSearchText(searchText .. text)
        return true
    end
    
    return false
end

function Inventory:resize(w, h)
    if self.window then
        self.window:resize(w, h)
    end
end

-- Backward compatibility methods
function Inventory:clearSearchFocus()
    self.state:clearSearchFocus()
end

function Inventory:isSearchInputActive()
    return self.state:isSearchActive()
end

return Inventory
