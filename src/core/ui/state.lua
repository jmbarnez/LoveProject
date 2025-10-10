--[[
    UI State Manager
    
    Manages the state of all UI panels including open/close status, z-index ordering,
    and synchronization with legacy panel visibility flags.
]]

local Log = require("src.core.log")

local UIState = {}

-- Default z-index values for different panel types
local DEFAULT_Z_INDEX = {
    cargo = 10,
    ship = 15,
    skills = 30,
    docked = 40,
    map = 50,
    warp = 60,
    escape = 100,
    settings = 110,
    repairPopup = 112,
    beaconRepair = 113,
    rewardWheel = 115,
    debug = 120,
}

-- Central UI state
local state = {
    cargo = { open = false, zIndex = DEFAULT_Z_INDEX.cargo },
    ship = { open = false, zIndex = DEFAULT_Z_INDEX.ship },
    skills = { open = false, zIndex = DEFAULT_Z_INDEX.skills },
    docked = { open = false, zIndex = DEFAULT_Z_INDEX.docked },
    map = { open = false, zIndex = DEFAULT_Z_INDEX.map },
    warp = { open = false, zIndex = DEFAULT_Z_INDEX.warp },
    escape = { open = false, zIndex = DEFAULT_Z_INDEX.escape, showingSaveSlots = false },
    settings = { open = false, zIndex = DEFAULT_Z_INDEX.settings },
    repairPopup = { open = false, zIndex = DEFAULT_Z_INDEX.repairPopup },
    beaconRepair = { open = false, zIndex = DEFAULT_Z_INDEX.beaconRepair },
    rewardWheel = { open = false, zIndex = DEFAULT_Z_INDEX.rewardWheel },
    debug = { open = false, zIndex = DEFAULT_Z_INDEX.debug }
}

local topZ = 0 -- Will be calculated dynamically based on open panels

-- UI layer order for proper layering
local layerOrder = {
    "cargo",
    "ship", 
    "skills",
    "docked",
    "map",
    "warp",
    "escape",
    "settings",
    "repairPopup",
    "beaconRepair",
    "rewardWheel",
    "debug"
}

function UIState.init()
    -- Initialize state for any panels discovered via registry
    local PanelRegistry = require("src.ui.panels.init")
    for _, record in ipairs(PanelRegistry.list()) do
        if not state[record.id] then
            local isVisible = false
            if record.isVisible then
                local ok, visible = pcall(record.isVisible, record.module)
                if ok then
                    isVisible = visible and true or false
                end
            elseif record.module and record.module.visible ~= nil then
                isVisible = record.module.visible == true
            end

            state[record.id] = { 
                open = isVisible, 
                zIndex = record.defaultZ or DEFAULT_Z_INDEX[record.id] or 0 
            }
            
            if record.id == "escape" then
                state[record.id].showingSaveSlots = false
            end
        end
    end
end

function UIState.getState()
    return state
end

function UIState.getTopZ()
    -- Calculate the actual top z-index from currently open panels
    local maxZ = 0
    for id, panelState in pairs(state) do
        if panelState.open and panelState.zIndex > maxZ then
            maxZ = panelState.zIndex
        end
    end
    return maxZ
end

function UIState.getLayerOrder()
    return layerOrder
end

function UIState.isOpen(component)
    return state[component] and state[component].open or false
end

function UIState.getZIndex(component)
    return state[component] and state[component].zIndex or 0
end

function UIState.open(component)
    if state[component] then
        -- Find the highest z-index among all currently open panels
        local maxZ = 0
        for id, panelState in pairs(state) do
            if panelState.open and panelState.zIndex > maxZ then
                maxZ = panelState.zIndex
            end
        end
        
        -- Set the new panel's z-index to be higher than all others
        state[component].zIndex = maxZ + 1
        topZ = state[component].zIndex
        state[component].open = true
        
        -- Reset save slots state when opening escape menu
        if component == "escape" then
            state[component].showingSaveSlots = false
        end
        
        Log.info("UIState.open: " .. component .. " opened with z-index " .. state[component].zIndex)
    end
end

function UIState.close(component)
    if state[component] then
        state[component].open = false
        
        -- Reset save slots state when closing escape menu
        if component == "escape" and state[component].showingSaveSlots then
            state[component].showingSaveSlots = false
        end
        
        Log.info("UIState.close: " .. component .. " closed")
    end
end

function UIState.toggle(component)
    if state[component] then
        if state[component].open then
            UIState.close(component)
        else
            UIState.open(component)
        end
        return state[component].open
    end
    return false
end

function UIState.closeAll(except)
    except = except or {}
    local exceptSet = {}
    for _, comp in ipairs(except) do
        exceptSet[comp] = true
    end

    for component, _ in pairs(state) do
        if not exceptSet[component] then
            UIState.close(component)
        end
    end
end

function UIState.reset()
    UIState.closeAll()
    topZ = 0
    for component, defaultZ in pairs(DEFAULT_Z_INDEX) do
        if state[component] then
            state[component].zIndex = defaultZ
        end
    end
    if state.escape then
        state.escape.showingSaveSlots = false
    end
end

function UIState.setShowingSaveSlots(show)
    if state.escape then
        state.escape.showingSaveSlots = show
    end
end

function UIState.isShowingSaveSlots()
    return state.escape and state.escape.showingSaveSlots or false
end


return UIState
