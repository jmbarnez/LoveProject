--[[
    Docked UI Tabs
    
    Handles tab rendering and switching for the docked interface including:
    - Tab rendering
    - Tab switching logic
    - Tab state management
]]

local Theme = require("src.core.theme")

local DockedTabs = {}

function DockedTabs.draw(self, x, y, w, h)
    local state = self.state
    if not state or not state.tabs then return end
    
    local tabH = 32
    local tabW = w / #state.tabs
    
    for i, tab in ipairs(state.tabs) do
        local tabX = x + (i - 1) * tabW
        local tabY = y
        local isActive = state.activeTab == tab
        
        DockedTabs.drawTab(tab, tabX, tabY, tabW, tabH, isActive)
    end
end

function DockedTabs.drawTab(tab, x, y, w, h, active)
    -- Tab background
    local bgColor = active and Theme.colors.accent or Theme.colors.bg2
    Theme.setColor(bgColor)
    love.graphics.rectangle("fill", x, y, w, h)
    
    -- Tab border
    local borderColor = active and Theme.colors.borderBright or Theme.colors.border
    Theme.setColor(borderColor)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h)
    
    -- Tab text
    local textColor = active and Theme.colors.textHighlight or Theme.colors.text
    Theme.setColor(textColor)
    Theme.setFont("medium")
    local textW = Theme.fonts.medium:getWidth(tab)
    local textH = Theme.fonts.medium:getHeight()
    local textX = x + (w - textW) * 0.5
    local textY = y + (h - textH) * 0.5
    love.graphics.print(tab, textX, textY)
end

function DockedTabs.handleClick(self, mx, my, x, y, w)
    local state = self.state
    if not state or not state.tabs then return false end
    
    local tabH = 32
    local tabW = w / #state.tabs
    
    if my >= y and my < y + tabH then
        for i, tab in ipairs(state.tabs) do
            local tabX = x + (i - 1) * tabW
            if mx >= tabX and mx < tabX + tabW then
                if state.activeTab ~= tab then
                    state.activeTab = tab
                    return true
                end
            end
        end
    end
    
    return false
end

function DockedTabs.getActiveTab(self)
    local state = self.state
    return state and state.activeTab or "Shop"
end

function DockedTabs.setActiveTab(self, tab)
    local state = self.state
    if state and state.tabs then
        for _, t in ipairs(state.tabs) do
            if t == tab then
                state.activeTab = tab
                return true
            end
        end
    end
    return false
end

return DockedTabs
