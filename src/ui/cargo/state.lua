local CargoState = {}

local function createState()
    return {
        visible = false,
        hoveredItem = nil,
        hoverTimer = 0,
        scroll = 0,
        _scrollMax = 0,
        contextMenu = {
            visible = false,
            x = 0,
            y = 0,
            item = nil,
            options = {},
        },
        auroraShader = nil,
        searchText = "",
        sortBy = "name",
        sortOrder = "asc",
        _searchInputActive = false,
        _scrollDragging = false,
        _scrollDragOffset = 0,
        _searchRect = nil,
        _sortRect = nil,
        _cargoSnapshot = nil,
    }
end

CargoState.state = createState()

function CargoState.reset()
    CargoState.state = createState()
    return CargoState.state
end

function CargoState.get()
    return CargoState.state
end

function CargoState.setSearchActive(active)
    local state = CargoState.state
    if state._searchInputActive == active then return end
    state._searchInputActive = active
    if love and love.keyboard and love.keyboard.setTextInput then
        love.keyboard.setTextInput(active)
    end
end

function CargoState.clearSearchFocus()
    CargoState.setSearchActive(false)
end

function CargoState.isSearchInputActive()
    return CargoState.state._searchInputActive
end

return CargoState
