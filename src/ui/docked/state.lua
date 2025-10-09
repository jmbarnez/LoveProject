--[[
    Docked UI State Management
    
    Manages all state for the Docked UI including:
    - Station type and docking status
    - Active tab management
    - Shop state (search, scroll, categories)
    - Furnace state
    - Context menu state
]]

local DockedState = {}

function DockedState.new()
    local state = {
        -- Core docking state
        visible = false,
        player = nil,
        stationType = nil,
        
        -- Tab management
        tabs = {"Shop", "Quests", "Nodes"},
        activeTab = "Shop",
        
        -- Shop state
        shopScroll = 0,
        selectedCategory = "All",
        buybackItems = {},
        searchText = "",
        searchActive = false,
        hoveredItem = nil,
        hoverTimer = 0,
        drag = nil,
        
        -- Context menu state
        contextMenu = {
            visible = false,
            x = 0,
            y = 0,
            item = nil,
            quantity = "1",
            type = "buy"
        },
        contextMenuActive = false,
        
        -- Furnace state
        furnaceState = {
            slots = {},
            selectedOreId = nil,
            selectedOre = nil,
            amountText = "1",
            inputActive = false,
            inputRect = nil,
            smeltButtonRect = nil,
            infoText = nil,
            hoveredRecipe = nil,
            hoverRect = nil,
        }
    }
    
    return state
end

function DockedState.setVisible(state, visible)
    state.visible = visible
end

function DockedState.isVisible(state)
    return state.visible
end

function DockedState.setPlayer(state, player)
    state.player = player
end

function DockedState.getPlayer(state)
    return state.player
end

function DockedState.setStationType(state, stationType)
    state.stationType = stationType
end

function DockedState.getStationType(state)
    return state.stationType
end

function DockedState.setActiveTab(state, tab)
    if state.tabs then
        for _, t in ipairs(state.tabs) do
            if t == tab then
                state.activeTab = tab
                return true
            end
        end
    end
    return false
end

function DockedState.getActiveTab(state)
    return state.activeTab
end

function DockedState.setShopScroll(state, scroll)
    state.shopScroll = scroll
end

function DockedState.getShopScroll(state)
    return state.shopScroll
end

function DockedState.setSelectedCategory(state, category)
    state.selectedCategory = category
end

function DockedState.getSelectedCategory(state)
    return state.selectedCategory
end

function DockedState.setSearchText(state, text)
    state.searchText = text
end

function DockedState.getSearchText(state)
    return state.searchText
end

function DockedState.setSearchActive(state, active)
    state.searchActive = active
end

function DockedState.isSearchActive(state)
    return state.searchActive
end

function DockedState.setHoveredItem(state, item)
    state.hoveredItem = item
end

function DockedState.getHoveredItem(state)
    return state.hoveredItem
end

function DockedState.setHoverTimer(state, timer)
    state.hoverTimer = timer
end

function DockedState.getHoverTimer(state)
    return state.hoverTimer
end

function DockedState.setDrag(state, drag)
    state.drag = drag
end

function DockedState.getDrag(state)
    return state.drag
end

function DockedState.setContextMenu(state, menu)
    state.contextMenu = menu
end

function DockedState.getContextMenu(state)
    return state.contextMenu
end

function DockedState.setContextMenuActive(state, active)
    state.contextMenuActive = active
end

function DockedState.isContextMenuActive(state)
    return state.contextMenuActive
end

function DockedState.setFurnaceState(state, furnaceState)
    state.furnaceState = furnaceState
end

function DockedState.getFurnaceState(state)
    return state.furnaceState
end

function DockedState.updateFurnaceState(state, updates)
    if state.furnaceState and updates then
        for key, value in pairs(updates) do
            state.furnaceState[key] = value
        end
    end
end

function DockedState.isFurnaceStation(state)
    return state.stationType == "ore_furnace_station"
end

function DockedState.resetFurnaceState(state)
    state.furnaceState = {
        slots = {},
        selectedOreId = nil,
        selectedOre = nil,
        amountText = "1",
        inputActive = false,
        inputRect = nil,
        smeltButtonRect = nil,
        infoText = nil,
        hoveredRecipe = nil,
        hoverRect = nil,
    }
end

function DockedState.setBuybackItems(state, items)
    state.buybackItems = items or {}
end

function DockedState.getBuybackItems(state)
    return state.buybackItems
end

function DockedState.addBuybackItem(state, item, quantity)
    if not state.buybackItems then
        state.buybackItems = {}
    end
    
    -- Check if item already exists
    for _, existing in ipairs(state.buybackItems) do
        if existing.item and existing.item.id == item.id then
            existing.quantity = (existing.quantity or 0) + (quantity or 1)
            return
        end
    end
    
    -- Add new item
    table.insert(state.buybackItems, {
        item = item,
        quantity = quantity or 1
    })
end

function DockedState.removeBuybackItem(state, itemId)
    if not state.buybackItems then return end
    
    for i = #state.buybackItems, 1, -1 do
        local buyback = state.buybackItems[i]
        if buyback.item and buyback.item.id == itemId then
            table.remove(state.buybackItems, i)
            break
        end
    end
end

return DockedState
