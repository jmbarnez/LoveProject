--[[
    UI Modal Handler
    
    Tracks modal state, blocks input to lower layers, and manages focus
    and text input capture for UI components.
]]

local Log = require("src.core.log")

local UIModalHandler = {}

-- Modal state
local modalActive = false
local modalComponent = nil

function UIModalHandler.init()
    modalActive = false
    modalComponent = nil
end

-- Update modal state based on open panels
function UIModalHandler.update()
    local state = require("src.core.ui.state")
    
    -- Block camera movement when ANY UI is open
    modalActive = state.isOpen("escape") or 
                  state.isOpen("warp") or 
                  state.isOpen("ship") or 
                  state.isOpen("settings") or
                  state.isOpen("inventory") or 
                  state.isOpen("docked") or 
                  state.isOpen("skills") or 
                  state.isOpen("map") or 
                  state.isOpen("rewardWheel") or 
                  state.isOpen("beaconRepair") or 
                  state.isOpen("debug")
    
    -- Determine the active modal component
    if state.isOpen("settings") then
        modalComponent = "settings"
    elseif state.isOpen("escape") and state.isShowingSaveSlots() then
        modalComponent = "escape_save_slots"
    elseif state.isOpen("escape") then
        modalComponent = "escape"
    elseif state.isOpen("ship") then
        modalComponent = "ship"
    elseif state.isOpen("warp") then
        modalComponent = "warp"
    elseif state.isOpen("beaconRepair") then
        modalComponent = "beaconRepair"
    else
        modalComponent = nil
    end
end

function UIModalHandler.isModalActive()
    return modalActive
end

function UIModalHandler.getModalComponent()
    return modalComponent
end

function UIModalHandler.setModalActive(active)
    modalActive = active
end

function UIModalHandler.setModalComponent(component)
    modalComponent = component
end

function UIModalHandler.reset()
    modalActive = false
    modalComponent = nil
end

-- Check if text input is focused in any panel
function UIModalHandler.isTextInputFocused()
    local PanelRegistry = require("src.ui.panels.init")
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

-- Check if a specific component should block input
function UIModalHandler.shouldBlockInput(component)
    if not modalActive then
        return false
    end
    
    -- If no specific modal component, block all input
    if not modalComponent then
        return true
    end
    
    -- Allow input to the modal component itself
    if component == modalComponent then
        return false
    end
    
    -- Block input to lower layers
    return true
end

-- Get the topmost modal component that should receive input
function UIModalHandler.getTopmostModalComponent()
    if not modalActive then
        return nil
    end
    
    return modalComponent
end

-- Check if escape key should be handled by modal system
function UIModalHandler.shouldHandleEscape()
    return modalActive and modalComponent ~= nil
end

-- Handle escape key for modal components
function UIModalHandler.handleEscape()
    if not modalActive or not modalComponent then
        return false
    end
    
    local state = require("src.core.ui.state")
    
    -- Close the modal component
    if modalComponent == "escape" then
        state.close("escape")
        return true
    elseif modalComponent == "settings" then
        state.close("settings")
        return true
    elseif modalComponent == "ship" then
        state.close("ship")
        return true
    elseif modalComponent == "warp" then
        state.close("warp")
        return true
    elseif modalComponent == "beaconRepair" then
        state.close("beaconRepair")
        return true
    end
    
    return false
end

return UIModalHandler
