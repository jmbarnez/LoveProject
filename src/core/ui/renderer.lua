--[[
    UI Renderer
    
    Handles drawing order determination, executes draw calls in proper order,
    manages viewport/font restoration, and coordinates tooltip rendering.
]]

local Log = require("src.core.log")
local Viewport = require("src.core.viewport")
local PanelRegistry = require("src.ui.panels.init")
local HUDRegistry = require("src.ui.hud.init")

local UIRenderer = {}

function UIRenderer.init()
    -- No initialization needed for the new modular system
end

-- Helper function to check if a panel is visible
local function isPanelVisible(record, state)
    if record.isVisible then
        local ok, visible = pcall(record.isVisible, record.module)
        if ok then
            return visible and true or false
        end
    elseif record.module and record.module.visible ~= nil then
        return record.module.visible == true
    else
        -- Use UIState as final visibility check
        return state.isOpen(record.id)
    end
    return false
end

-- Helper function to call component draw methods via PanelRegistry
local function callComponentDraw(component, player, world, enemies, hub, wreckage, lootDrops)
    local record = PanelRegistry.get(component)
    if not record or not record.module then
        return false
    end

    local module = record.module
    
    -- Use the panel registration's draw function if it exists, otherwise fall back to module.draw
    local drawFn = record.draw or module.draw
    if type(drawFn) ~= "function" then
        return false
    end

    local ok, err = pcall(function()
        if record.draw then
            -- Use panel registration's draw function with parameters
            drawFn(module, player, world, enemies, hub, wreckage, lootDrops)
        else
            -- Use module's draw function with parameters
            if record.useSelf then
                drawFn(module, player, world, enemies, hub, wreckage, lootDrops)
            else
                drawFn(player, world, enemies, hub, wreckage, lootDrops)
            end
        end
    end)

    if not ok then
        Log.error("Error drawing panel '" .. component .. "': " .. tostring(err))
        return false
    end

    return true
end

-- Main draw function
function UIRenderer.draw(player, world, enemies, hub, wreckage, lootDrops)
    local state = require("src.core.ui.state")
    local drawStart = love.timer.getTime()
    
    -- Note: Viewport is already managed by the main game rendering pipeline
    -- We just need to draw UI components on top of the game world

    -- Set baseline font
    local Theme = require("src.core.theme")
    local oldFont = love.graphics.getFont()
    if Theme and Theme.fonts and Theme.fonts.normal then
        love.graphics.setFont(Theme.fonts.normal)
    end

    -- Draw all panels via PanelRegistry in z-index order
    local sortedPanels = {}
    for _, record in ipairs(PanelRegistry.list()) do
        if isPanelVisible(record, state) then
            table.insert(sortedPanels, {
                id = record.id,
                zIndex = state.getZIndex(record.id)
            })
        end
    end
    
    -- Sort by z-index (lowest to highest)
    table.sort(sortedPanels, function(a, b) return a.zIndex < b.zIndex end)
    
    -- Draw each panel
    for _, panel in ipairs(sortedPanels) do
        callComponentDraw(panel.id, player, world, enemies, hub, wreckage, lootDrops)
    end

    -- Draw HUD components via registry (in priority order)
    for _, record in ipairs(HUDRegistry.list()) do
        if record.draw then
            local ok, err = pcall(record.draw, record.module)
            if not ok then
                Log.error(string.format("Error drawing HUD component '%s': %s", record.id, err))
            end
        end
    end

    -- Draw FPS counter if enabled
    local Settings = require("src.core.settings")
    local graphicsSettings = Settings.getGraphicsSettings()
    if graphicsSettings and graphicsSettings.show_fps then
        local fps = love.timer.getFPS()
        local Theme = require("src.core.theme")
        local oldFont = love.graphics.getFont()
        love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
        Theme.setColor(Theme.colors.text)
        love.graphics.print("FPS: " .. fps, 10, 10)
        love.graphics.setFont(oldFont)
    end

    -- Note: Viewport finish is handled by the main game rendering pipeline

    -- Restore prior font to prevent persistent size changes across frames
    if oldFont then 
        love.graphics.setFont(oldFont) 
    end

    -- Update debug panel render stats
    local drawTime = (love.timer.getTime() - drawStart) * 1000
    local DebugPanel = require("src.ui.debug_panel")
    if DebugPanel and DebugPanel.setRenderStats then
        DebugPanel.setRenderStats(drawTime)
    end
end

-- Check if mouse is over any visible UI component
function UIRenderer.isMouseOverUI()
    local mx, my = Viewport.getMousePosition()
    local state = require("src.core.ui.state")
    
    -- PanelRegistry-driven hit testing for windows/panels
    for _, record in ipairs(PanelRegistry.list()) do
        if isPanelVisible(record, state) then
            -- Get component rect for hit testing
            local r = nil
            if record.getRect then
                local ok, rect = pcall(record.getRect, record.module)
                if ok then r = rect end
            end
            if not r and record.module and type(record.module.getRect) == "function" then
                local ok, rect = pcall(record.module.getRect, record.module)
                if ok then r = rect end
            end
            
            if r and mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h then
                return true
            end
            
            -- Fullscreen components like docked should always count as UI
            if record.id == "docked" then 
                return true 
            end
            if record.id == "escape" and state.isShowingSaveSlots() then 
                return true 
            end
        end
    end

    return false
end

return UIRenderer
