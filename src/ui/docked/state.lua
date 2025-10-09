local FurnacePanel = require("src.ui.docked.furnace_panel")

local DockedState = {}

local function default_context_menu()
    return { visible = false, x = 0, y = 0, item = nil, quantity = "1", type = "buy" }
end

function DockedState.new()
    return {
        visible = false,
        player = nil,
        station = nil,
        stationType = nil,
        window = nil,
        quests = nil,
        nodes = nil,
        tabs = { "Shop", "Quests", "Nodes" },
        activeTab = "Shop",
        shopScroll = 0,
        selectedCategory = "All",
        buybackItems = {},
        searchText = "",
        searchActive = false,
        hoveredItem = nil,
        hoverTimer = 0,
        drag = nil,
        contextMenu = default_context_menu(),
        contextMenuActive = false,
        furnaceState = FurnacePanel.createState(),
    }
end

local function resolve_station_type(station)
    if not station or not station.components then return nil end
    local stationComponent = station.components.station
    if not stationComponent then return nil end
    return stationComponent.type
end

function DockedState.prepareForShow(state, player, station)
    state.visible = true
    state.player = player
    state.station = station
    state.stationType = resolve_station_type(station)
    state.searchActive = false
    state.contextMenuActive = false
    state.hoveredItem = nil
    state.hoverTimer = 0
    state.shopScroll = 0
    if state.stationType == "ore_furnace_station" then
        state.activeTab = "Furnace"
    elseif state.activeTab == "Furnace" then
        state.activeTab = "Shop"
    end
end

function DockedState.markHidden(state)
    state.visible = false
    state.player = nil
    state.station = nil
    state.stationType = nil
    state.searchActive = false
    state.contextMenuActive = false
    state.hoveredItem = nil
    state.hoverTimer = 0
    FurnacePanel.reset(state.furnaceState)
    state.contextMenu = default_context_menu()
end

return DockedState
