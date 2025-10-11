--[[
    TooltipManager
    
    Centralized tooltip management system that ensures tooltips always render
    on top of all other UI elements. Individual UI components register tooltips
    instead of drawing them directly.
]]

local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local Tooltip = require("src.ui.tooltip")

local TooltipManager = {}

-- Current tooltip state
local currentTooltip = nil
local tooltipData = nil

-- Register a tooltip to be drawn
function TooltipManager.setTooltip(item, x, y)
    if item then
        currentTooltip = { item = item, x = x, y = y }
        tooltipData = nil
    else
        currentTooltip = nil
        tooltipData = nil
    end
end

-- Register a custom tooltip with data
function TooltipManager.setCustomTooltip(data, x, y)
    if data then
        currentTooltip = nil
        tooltipData = { data = data, x = x, y = y }
    else
        currentTooltip = nil
        tooltipData = nil
    end
end

-- Clear current tooltip
function TooltipManager.clearTooltip()
    currentTooltip = nil
    tooltipData = nil
end

-- Draw all tooltips (called by UIManager at the end of rendering)
function TooltipManager.draw()
    if currentTooltip then
        local success, error = pcall(function()
            Tooltip.drawItemTooltip(currentTooltip.item, currentTooltip.x, currentTooltip.y)
        end)
        if not success then
            print("TooltipManager: Error drawing tooltip:", error)
        end
    elseif tooltipData then
        -- Handle custom tooltip data if needed
        -- For now, we'll use the same item tooltip system
        if tooltipData.data then
            local success, error = pcall(function()
                Tooltip.drawItemTooltip(tooltipData.data, tooltipData.x, tooltipData.y)
            end)
            if not success then
                print("TooltipManager: Error drawing custom tooltip:", error)
            end
        end
    end
end

-- Check if a tooltip is currently active
function TooltipManager.hasTooltip()
    return currentTooltip ~= nil or tooltipData ~= nil
end

-- Get current tooltip position (for hit testing)
function TooltipManager.getTooltipRect()
    if currentTooltip then
        local item = currentTooltip.item
        local x, y = currentTooltip.x, currentTooltip.y
        
        -- Calculate approximate tooltip dimensions
        local tooltipConfig = Theme.components and Theme.components.tooltip or {
            maxWidth = 500, minWidth = 150, padding = 8
        }
        
        local name = item.proceduralName or item.name or "Unknown Item"
        local nameFont = Theme.fonts and Theme.fonts.medium or love.graphics.getFont()
        local nameW = nameFont:getWidth(name)
        local w = math.max(tooltipConfig.minWidth, nameW + tooltipConfig.padding * 2)
        local h = 100 -- Approximate height
        
        -- Position tooltip (same logic as in Tooltip.drawItemTooltip)
        local sw, sh = Viewport.getDimensions()
        local tx = x + 20
        local ty = y
        if tx + w > sw then tx = x - w - 20 end
        if ty + h > sh then ty = sh - h end
        if ty < 0 then ty = 0 end
        
        return { x = tx, y = ty, w = w, h = h }
    elseif tooltipData then
        -- Similar logic for custom tooltips
        local x, y = tooltipData.x, tooltipData.y
        local tooltipConfig = Theme.components and Theme.components.tooltip or {
            maxWidth = 500, minWidth = 150, padding = 8
        }
        local w = tooltipConfig.minWidth
        local h = 100
        
        local sw, sh = Viewport.getDimensions()
        local tx = x + 20
        local ty = y
        if tx + w > sw then tx = x - w - 20 end
        if ty + h > sh then ty = sh - h end
        if ty < 0 then ty = 0 end
        
        return { x = tx, y = ty, w = w, h = h }
    end
    
    return nil
end

return TooltipManager
