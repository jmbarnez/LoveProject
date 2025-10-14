--[[
    UI Input Router
    
    Routes all input events (mouse, keyboard, wheel, text) to appropriate UI components.
    Handles capture/release mechanics, hit testing, and modal blocking logic.
]]

local Log = require("src.core.log")
local PanelRegistry = require("src.ui.panels.init")

local UIInputRouter = {}

-- Input capture state for drag operations
local capturedComponent = nil

-- Initialize input router
function UIInputRouter.init()
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

-- Helper function to call component methods via PanelRegistry
local function callComponentMethod(componentId, methodName, ...)
    local record = PanelRegistry.get(componentId)
    if not record or not record.module then
        return false
    end

    local module = record.module
    local fn = module[methodName]
    if type(fn) ~= "function" then
        return false
    end

    local args = {...}
    local ok, result = pcall(function()
        if record.useSelf then
            return fn(module, table.unpack(args))
        else
            return fn(table.unpack(args))
        end
    end)

    if not ok then
        Log.error("Error calling method '" .. methodName .. "' on panel '" .. componentId .. "': " .. tostring(result))
        return false
    end

    return result
end

-- Check if text input is focused
function UIInputRouter.isTextInputFocused()
    for _, record in ipairs(PanelRegistry.list()) do
        local state = require("src.core.ui.state")
        if state.isOpen(record.id) and record.captureTextInput then
            local ok, captured = pcall(record.captureTextInput, record.module)
            if ok and captured then
                return true
            end
        end
    end
    return false
end

-- Handle mouse press events
function UIInputRouter.mousepressed(x, y, button, player)
    -- Build list of visible components from PanelRegistry (topmost first)
    local openLayers = {}
    local state = require("src.core.ui.state")
    for _, record in ipairs(PanelRegistry.list()) do
        if isPanelVisible(record, state) then
            table.insert(openLayers, { 
                name = record.id, 
                z = state.getZIndex(record.id), 
                getRect = function()
                    if record.getRect then
                        local ok, rect = pcall(record.getRect, record.module)
                        if ok then return rect end
                    end
                    local module = record.module
                    if module and type(module.getRect) == "function" then
                        local ok, rect = pcall(module.getRect, module)
                        if ok then return rect end
                    end
                    return nil
                end
            })
        end
    end
    
    -- Sort by z-index (highest first)
    table.sort(openLayers, function(a, b) return a.z > b.z end)

    -- Click-to-front behavior: bring clicked component to front
    local raised = false
    for _, layer in ipairs(openLayers) do
        local r = layer.getRect()
        if r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then
            state.open(layer.name)
            raised = true
            break
        end
    end

    -- Re-sort after raising
    for _, layer in ipairs(openLayers) do
        layer.z = state.getZIndex(layer.name)
    end
    table.sort(openLayers, function(a, b) return a.z > b.z end)

    -- Route input to components from top to bottom
    for _, layer in ipairs(openLayers) do
        local component = layer.name
        local handled = callComponentMethod(component, "mousepressed", x, y, button, player)
        if handled then
            capturedComponent = component
            return true
        end
    end

    return false
end

-- Handle mouse release events
function UIInputRouter.mousereleased(x, y, button, player)
    -- If a component captured the mouse on press, send release to it first
    if capturedComponent then
        local handled = callComponentMethod(capturedComponent, "mousereleased", x, y, button, player)
        capturedComponent = nil
        if handled then
            return true
        end
    end

    -- Route to all visible panels
    local state = require("src.core.ui.state")
    local sortedPanels = {}
    for _, record in ipairs(PanelRegistry.list()) do
        if isPanelVisible(record, state) then
            table.insert(sortedPanels, {
                id = record.id,
                zIndex = state.getZIndex(record.id)
            })
        end
    end
    
    -- Sort by z-index (highest first)
    table.sort(sortedPanels, function(a, b) return a.zIndex > b.zIndex end)
    
    for _, panel in ipairs(sortedPanels) do
        local handled = callComponentMethod(panel.id, "mousereleased", x, y, button, player)
        if handled then
            return true
        end
    end

    return false
end

-- Handle mouse move events
function UIInputRouter.mousemoved(x, y, dx, dy, player)
    -- If a component captured the mouse on press, route movement directly to it
    if capturedComponent then
        local handled = callComponentMethod(capturedComponent, "mousemoved", x, y, dx, dy, player)
        if handled then
            return true
        end
    end

    -- Route to all visible panels
    local state = require("src.core.ui.state")
    local sortedPanels = {}
    for _, record in ipairs(PanelRegistry.list()) do
        if state.isOpen(record.id) then
            table.insert(sortedPanels, {
                id = record.id,
                zIndex = state.getZIndex(record.id)
            })
        end
    end
    
    -- Sort by z-index (highest first)
    table.sort(sortedPanels, function(a, b) return a.zIndex > b.zIndex end)
    
    for _, panel in ipairs(sortedPanels) do
        local handled = callComponentMethod(panel.id, "mousemoved", x, y, dx, dy, player)
        if handled then
            return true
        end
    end

    return false
end

-- Handle wheel events
function UIInputRouter.wheelmoved(x, y, dx, dy, player)
    if dy == nil then return false end

    local state = require("src.core.ui.state")
    local sortedPanels = {}
    for _, record in ipairs(PanelRegistry.list()) do
        if state.isOpen(record.id) then
            table.insert(sortedPanels, {
                id = record.id,
                zIndex = state.getZIndex(record.id)
            })
        end
    end
    
    -- Sort by z-index (highest first)
    table.sort(sortedPanels, function(a, b) return a.zIndex > b.zIndex end)
    
    for _, panel in ipairs(sortedPanels) do
        local handled = false
        if panel.id == "map" then -- Special case for map, expects (mouseX, wheelDeltaY)
            handled = callComponentMethod(panel.id, "wheelmoved", x, dy, player)
        else -- Generic convention: (mx, my, dx, dy)
            handled = callComponentMethod(panel.id, "wheelmoved", x, y, dx, dy, player)
        end
        if handled then
            return true
        end
    end

    return false
end

-- Handle keyboard events
function UIInputRouter.keypressed(key, scancode, isrepeat, player)
    -- Special handling for escape key - always toggle escape panel
    if key == "escape" then
        local UIManager = require("src.core.ui.manager")
        UIManager.toggle("escape")
        return true
    end
    
    -- Normal key handling for non-escape keys
    local state = require("src.core.ui.state")
    local sortedPanels = {}
    for _, record in ipairs(PanelRegistry.list()) do
        if state.isOpen(record.id) then
            table.insert(sortedPanels, {
                id = record.id,
                zIndex = state.getZIndex(record.id)
            })
        end
    end
    
    -- Sort by z-index (highest first)
    table.sort(sortedPanels, function(a, b) return a.zIndex > b.zIndex end)
    
    for _, panel in ipairs(sortedPanels) do
        local handled = callComponentMethod(panel.id, "keypressed", key, scancode, isrepeat, player)
        if handled then
            return true
        end
    end

    return false
end

-- Handle key release events
function UIInputRouter.keyreleased(key, scancode, player)
    local state = require("src.core.ui.state")
    local sortedPanels = {}
    for _, record in ipairs(PanelRegistry.list()) do
        if state.isOpen(record.id) then
            table.insert(sortedPanels, {
                id = record.id,
                zIndex = state.getZIndex(record.id)
            })
        end
    end
    
    -- Sort by z-index (highest first)
    table.sort(sortedPanels, function(a, b) return a.zIndex > b.zIndex end)
    
    for _, panel in ipairs(sortedPanels) do
        local handled = callComponentMethod(panel.id, "keyreleased", key, scancode, player)
        if handled then
            return true
        end
    end

    return false
end

-- Handle text input events
function UIInputRouter.textinput(text, player)
    local state = require("src.core.ui.state")
    local sortedPanels = {}
    for _, record in ipairs(PanelRegistry.list()) do
        if state.isOpen(record.id) then
            table.insert(sortedPanels, {
                id = record.id,
                zIndex = state.getZIndex(record.id)
            })
        end
    end
    
    -- Sort by z-index (highest first)
    table.sort(sortedPanels, function(a, b) return a.zIndex > b.zIndex end)
    
    for _, panel in ipairs(sortedPanels) do
        local handled = callComponentMethod(panel.id, "textinput", text, player)
        if handled then
            return true
        end
    end

    return false
end

return UIInputRouter