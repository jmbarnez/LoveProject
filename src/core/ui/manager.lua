--[[
    UI Manager - Lightweight Orchestrator
    
    Coordinates all UI subsystems while maintaining the same public API
    as the original UIManager. Delegates to specialized modules for
    state management, input routing, rendering, and modal handling.
]]

local Log = require("src.core.log")
local Warp = require("src.ui.warp")

-- Import all UI modules
local UIState = require("src.core.ui.state")
local UIInputRouter = require("src.core.ui.input_router")
local UIRenderer = require("src.core.ui.renderer")
local UIModalHandler = require("src.core.ui.modal_handler")

-- Import required core modules
local PanelRegistry = require("src.ui.panels.init")
local HUDRegistry = require("src.ui.hud.init")

local UIManager = {}

-- Expose state for backward compatibility (will be initialized in init())
UIManager.state = {}
UIManager.topZ = 0
UIManager.layerOrder = {}
UIManager.modalActive = false
UIManager.modalComponent = nil

-- Initialize UI Manager
function UIManager.init()
    Log.info("Initializing new modular UIManager")
    
    -- Initialize all sub-modules
    UIState.init()
    UIInputRouter.init()
    UIRenderer.init()
    UIModalHandler.init()
    
    -- Update backward compatibility state
    UIManager.state = UIState.getState()
    UIManager.topZ = UIState.getTopZ()
    UIManager.layerOrder = UIState.getLayerOrder()
    
    -- Mark as initialized
    UIManager._initialized = true

    -- The new modular system uses PanelRegistry exclusively
    -- No need to manually register components here
end

function UIManager.resize(w, h)
    -- Delegate resize to individual panels via PanelRegistry
    for _, record in ipairs(PanelRegistry.list()) do
        local module = record.module
        if module and type(module.resize) == "function" then
            local ok, err = pcall(module.resize, module, w, h)
            if not ok then
                Log.error(string.format("Error resizing panel '%s': %s", record.id, err))
            end
        end
    end
    
    -- Reload theme fonts
    local Theme = require("src.core.theme")
    if Theme and Theme.loadFonts then Theme.loadFonts() end
end

-- Update UI Manager state
function UIManager.update(dt, player)
    -- Store player reference for input routing
    UIManager._player = player
    
    -- Update modal state
    UIModalHandler.update()
    UIManager.modalActive = UIModalHandler.isModalActive()
    UIManager.modalComponent = UIModalHandler.getModalComponent()

    -- Update individual panels via PanelRegistry
    for _, record in ipairs(PanelRegistry.list()) do
        if UIState.isOpen(record.id) then
            local module = record.module
            if module and type(module.update) == "function" then
                local ok, err = pcall(module.update, module, dt, player)
                if not ok then
                    Log.error(string.format("Error updating panel '%s': %s", record.id, err))
                end
            end
        end
    end
    
    -- Update HUD components via registry
    for _, record in ipairs(HUDRegistry.list()) do
        if record.update then
            local ok, err = pcall(record.update, record.module, dt)
            if not ok then
                Log.error(string.format("Error updating HUD component '%s': %s", record.id, err))
            end
        end
    end
end

-- Draw all UI components in proper order
function UIManager.draw(player, world, enemies, hub, wreckage, lootDrops)
    UIRenderer.draw(player, world, enemies, hub, wreckage, lootDrops)
end

-- Returns true if the mouse is currently over any visible UI component
function UIManager.isMouseOverUI()
    return UIRenderer.isMouseOverUI()
end

-- Toggle UI component visibility
function UIManager.toggle(component)
    if UIState.isOpen(component) then
        UIManager.close(component)
        return false
    else
        UIManager.open(component)
        return true
    end
end

-- Open UI component
function UIManager.open(component)
    Log.info("UIManager.open called for component: " .. component)
    
    -- Handle special cases
    if component == "docked" then
        UIState.closeAll({"docked", "escape"})
    elseif component == "escape" then
        UIState.closeAll({"docked", "escape"})
    end
    
    UIState.open(component)
    
    -- Sync with the actual panel module
    local record = PanelRegistry.get(component)
    if record and record.module then
        local module = record.module
        
        -- Set the panel's visible property to match UIState
        if module.visible ~= nil then
            module.visible = true
        end
        
        -- Call panel's onOpen callback if it exists (this handles show() calls)
        if record.onOpen then
            local ok, err = pcall(record.onOpen, module)
            if not ok then
                Log.error(string.format("Error in onOpen for panel '%s': %s", component, err))
            end
        elseif module.show then
            -- Call show directly if no onOpen callback
            local ok, err = pcall(module.show, module)
            if not ok then
                Log.error(string.format("Error calling show on panel '%s': %s", component, err))
            end
        end
    end
end

-- Close UI component
function UIManager.close(component)
    Log.info("UIManager.close called for component: " .. component)
    UIState.close(component)
    
    -- Sync with the actual panel module
    local record = PanelRegistry.get(component)
    if record and record.module then
        local module = record.module
        
        -- Set the panel's visible property to match UIState
        if module.visible ~= nil then
            module.visible = false
        end
        
        -- Call panel's onClose callback if it exists (this handles hide() calls)
        if record.onClose then
            local ok, err = pcall(record.onClose, module)
            if not ok then
                Log.error(string.format("Error in onClose for panel '%s': %s", component, err))
            end
        elseif module.hide then
            -- Call hide directly if no onClose callback
            local ok, err = pcall(module.hide, module)
            if not ok then
                Log.error(string.format("Error calling hide on panel '%s': %s", component, err))
            end
        end
    end
end

-- Close all UI components except specified ones
function UIManager.closeAll(except)
    except = except or {}
    local exceptSet = {}
    for _, comp in ipairs(except) do
        exceptSet[comp] = true
    end
    
    -- Close all panels via PanelRegistry
    for _, record in ipairs(PanelRegistry.list()) do
        if not exceptSet[record.id] and UIState.isOpen(record.id) then
            UIManager.close(record.id)
        end
    end
end

function UIManager.reset()
    UIState.reset()
    UIModalHandler.reset()
    UIManager.modalActive = false
    UIManager.modalComponent = nil
end

-- Check if a UI component is open
function UIManager.isOpen(component)
    return UIState.isOpen(component)
end

-- Check if any modal UI is open
function UIManager.isModalActive()
    return UIModalHandler.isModalActive()
end

-- Get the active modal component
function UIManager.getModalComponent()
    return UIModalHandler.getModalComponent()
end

-- Handle mouse input for UI components
function UIManager.mousepressed(x, y, button)
    return UIInputRouter.mousepressed(x, y, button, UIManager._player)
end

function UIManager.mousereleased(x, y, button)
    return UIInputRouter.mousereleased(x, y, button, UIManager._player)
end

function UIManager.mousemoved(x, y, dx, dy)
    return UIInputRouter.mousemoved(x, y, dx, dy)
end

function UIManager.wheelmoved(x, y, dx, dy)
    return UIInputRouter.wheelmoved(x, y, dx, dy)
end

-- Handle keyboard input for UI components
function UIManager.keypressed(key, scancode, isrepeat)
    return UIInputRouter.keypressed(key, scancode, isrepeat, UIManager._player)
end

function UIManager.keyreleased(key, scancode)
    return UIInputRouter.keyreleased(key, scancode, UIManager._player)
end

-- Handle text input for UI components
function UIManager.textinput(text)
    return UIInputRouter.textinput(text, UIManager._player)
end

-- Check if text input is active
function UIManager.isTextInputActive()
    return UIInputRouter.isTextInputFocused()
end

-- Get warp instance (for external access)
function UIManager.getWarpInstance()
    return Warp.getInstance()
end

return UIManager
