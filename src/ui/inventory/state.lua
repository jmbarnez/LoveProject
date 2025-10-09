--[[
    Inventory UI State Management
    
    Manages all state for the Inventory UI including:
    - Inventory display state
    - Search and filtering
    - Sorting options
    - Context menu state
    - Drag and drop state
    - Scroll state
]]

local InventoryState = {}

function InventoryState.new()
    local state = {
        -- Core UI state
        visible = false,
        player = nil,
        
        -- Display state
        scroll = 0,
        _scrollMax = 0,
        hoveredItem = nil,
        hoverTimer = 0,
        
        -- Search and filtering
        searchText = "",
        sortBy = "name", -- "name", "type", "rarity", "value", "quantity"
        sortOrder = "asc", -- "asc" or "desc"
        _searchInputActive = false,
        _searchRect = nil,
        _sortRect = nil,
        
        -- Drag and drop
        drag = nil,
        dragItem = nil,
        dragStartIndex = nil,
        
        -- Context menu
        contextMenu = {
            visible = false,
            x = 0,
            y = 0,
            item = nil,
            options = {}
        },
        contextMenuActive = false,
        
        -- Scroll dragging
        _scrollDragging = false,
        _scrollDragOffset = 0,
        
        -- Aurora shader
        auroraShader = nil,
        
        -- Window
        window = nil
    }
    
    return state
end

function InventoryState:setVisible(visible)
    self.visible = visible
end

function InventoryState:isVisible()
    return self.visible
end

function InventoryState:setPlayer(player)
    self.player = player
end

function InventoryState:getPlayer()
    return self.player
end

function InventoryState:setScroll(scroll)
    self.scroll = scroll
end

function InventoryState:getScroll()
    return self.scroll
end

function InventoryState:setScrollMax(max)
    self._scrollMax = max
end

function InventoryState:getScrollMax()
    return self._scrollMax
end

function InventoryState:setHoveredItem(item)
    self.hoveredItem = item
end

function InventoryState:getHoveredItem()
    return self.hoveredItem
end

function InventoryState:setHoverTimer(timer)
    self.hoverTimer = timer
end

function InventoryState:getHoverTimer()
    return self.hoverTimer
end

function InventoryState:setSearchText(text)
    self.searchText = text or ""
end

function InventoryState:getSearchText()
    return self.searchText
end

function InventoryState:setSearchActive(active)
    self._searchInputActive = active
end

function InventoryState:isSearchActive()
    return self._searchInputActive
end

function InventoryState:setSortBy(sortBy)
    self.sortBy = sortBy or "name"
end

function InventoryState:getSortBy()
    return self.sortBy
end

function InventoryState:setSortOrder(order)
    self.sortOrder = order or "asc"
end

function InventoryState:getSortOrder()
    return self.sortOrder
end

function InventoryState:setSearchRect(rect)
    self._searchRect = rect
end

function InventoryState:getSearchRect()
    return self._searchRect
end

function InventoryState:setSortRect(rect)
    self._sortRect = rect
end

function InventoryState:getSortRect()
    return self._sortRect
end

function InventoryState:setDrag(drag)
    self.drag = drag
end

function InventoryState:getDrag()
    return self.drag
end

function InventoryState:setDragItem(item)
    self.dragItem = item
end

function InventoryState:getDragItem()
    return self.dragItem
end

function InventoryState:setDragStartIndex(index)
    self.dragStartIndex = index
end

function InventoryState:getDragStartIndex()
    return self.dragStartIndex
end

function InventoryState:setContextMenu(menu)
    self.contextMenu = menu or {}
end

function InventoryState:getContextMenu()
    return self.contextMenu
end

function InventoryState:setContextMenuActive(active)
    self.contextMenuActive = active
end

function InventoryState:isContextMenuActive()
    return self.contextMenuActive
end

function InventoryState:setScrollDragging(dragging)
    self._scrollDragging = dragging
end

function InventoryState:isScrollDragging()
    return self._scrollDragging
end

function InventoryState:setScrollDragOffset(offset)
    self._scrollDragOffset = offset
end

function InventoryState:getScrollDragOffset()
    return self._scrollDragOffset
end

function InventoryState:setAuroraShader(shader)
    self.auroraShader = shader
end

function InventoryState:getAuroraShader()
    return self.auroraShader
end

function InventoryState:setWindow(window)
    self.window = window
end

function InventoryState:getWindow()
    return self.window
end

function InventoryState:clearSearchFocus()
    self:setSearchActive(false)
    if love and love.keyboard and love.keyboard.setTextInput then
        love.keyboard.setTextInput(false)
    end
end

function InventoryState:reset()
    self.visible = false
    self.scroll = 0
    self._scrollMax = 0
    self.hoveredItem = nil
    self.hoverTimer = 0
    self.searchText = ""
    self.sortBy = "name"
    self.sortOrder = "asc"
    self._searchInputActive = false
    self._searchRect = nil
    self._sortRect = nil
    self.drag = nil
    self.dragItem = nil
    self.dragStartIndex = nil
    self.contextMenu = {
        visible = false,
        x = 0,
        y = 0,
        item = nil,
        options = {}
    }
    self.contextMenuActive = false
    self._scrollDragging = false
    self._scrollDragOffset = 0
end

return InventoryState
