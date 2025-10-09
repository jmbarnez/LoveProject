--[[
    Ship UI State Management
    
    Manages all state for the Ship UI including:
    - Equipment grid state
    - Turret management
    - Hotbar integration
    - Drag and drop state
    - UI interaction states
]]

local ShipState = {}

function ShipState.new()
    local state = {
        -- Core UI state
        visible = false,
        player = nil,
        
        -- Equipment grid state
        equipmentGrid = {},
        selectedSlot = nil,
        hoveredSlot = nil,
        
        -- Drag and drop state
        drag = nil,
        dragStartSlot = nil,
        dragItem = nil,
        
        -- Turret management
        turrets = {},
        selectedTurret = nil,
        turretDropdownVisible = false,
        
        -- Hotbar integration
        hotbarPreview = {},
        hotbarSlots = {},
        
        -- UI interaction states
        contextMenu = {
            visible = false,
            x = 0,
            y = 0,
            slot = nil,
            options = {}
        },
        contextMenuActive = false,
        
        -- Window state
        window = nil,
        
        -- Input states
        inputActive = false,
        inputType = nil, -- "turret_name", "module_name", etc.
        inputValue = "",
        inputRect = nil
    }
    
    return state
end

function ShipState:setVisible(visible)
    self.visible = visible
end

function ShipState:isVisible()
    return self.visible
end

function ShipState:setPlayer(player)
    self.player = player
    if player and player.components and player.components.equipment then
        self.equipmentGrid = player.components.equipment.grid or {}
    end
end

function ShipState:getPlayer()
    return self.player
end

function ShipState:setEquipmentGrid(grid)
    self.equipmentGrid = grid or {}
end

function ShipState:getEquipmentGrid()
    return self.equipmentGrid
end

function ShipState:setSelectedSlot(slot)
    self.selectedSlot = slot
end

function ShipState:getSelectedSlot()
    return self.selectedSlot
end

function ShipState:setHoveredSlot(slot)
    self.hoveredSlot = slot
end

function ShipState:getHoveredSlot()
    return self.hoveredSlot
end

function ShipState:setDrag(drag)
    self.drag = drag
end

function ShipState:getDrag()
    return self.drag
end

function ShipState:setDragStartSlot(slot)
    self.dragStartSlot = slot
end

function ShipState:getDragStartSlot()
    return self.dragStartSlot
end

function ShipState:setDragItem(item)
    self.dragItem = item
end

function ShipState:getDragItem()
    return self.dragItem
end

function ShipState:setTurrets(turrets)
    self.turrets = turrets or {}
end

function ShipState:getTurrets()
    return self.turrets
end

function ShipState:setSelectedTurret(turret)
    self.selectedTurret = turret
end

function ShipState:getSelectedTurret()
    return self.selectedTurret
end

function ShipState:setTurretDropdownVisible(visible)
    self.turretDropdownVisible = visible
end

function ShipState:isTurretDropdownVisible()
    return self.turretDropdownVisible
end

function ShipState:setHotbarPreview(preview)
    self.hotbarPreview = preview or {}
end

function ShipState:getHotbarPreview()
    return self.hotbarPreview
end

function ShipState:setHotbarSlots(slots)
    self.hotbarSlots = slots or {}
end

function ShipState:getHotbarSlots()
    return self.hotbarSlots
end

function ShipState:setContextMenu(menu)
    self.contextMenu = menu or {}
end

function ShipState:getContextMenu()
    return self.contextMenu
end

function ShipState:setContextMenuActive(active)
    self.contextMenuActive = active
end

function ShipState:isContextMenuActive()
    return self.contextMenuActive
end

function ShipState:setWindow(window)
    self.window = window
end

function ShipState:getWindow()
    return self.window
end

function ShipState:setInputActive(active, inputType)
    self.inputActive = active
    self.inputType = inputType
    if not active then
        self.inputValue = ""
        self.inputRect = nil
    end
end

function ShipState:isInputActive()
    return self.inputActive
end

function ShipState:getInputType()
    return self.inputType
end

function ShipState:setInputValue(value)
    self.inputValue = value
end

function ShipState:getInputValue()
    return self.inputValue
end

function ShipState:setInputRect(rect)
    self.inputRect = rect
end

function ShipState:getInputRect()
    return self.inputRect
end

function ShipState:updateFromPlayer()
    if not self.player or not self.player.components then
        return
    end
    
    -- Update equipment grid
    if self.player.components.equipment then
        self.equipmentGrid = self.player.components.equipment.grid or {}
    end
    
    -- Update turrets
    if self.player.components.equipment and self.player.components.equipment.turrets then
        self.turrets = self.player.components.equipment.turrets
    end
end

function ShipState:getSlotAt(index)
    if not self.equipmentGrid or not self.equipmentGrid[index] then
        return nil
    end
    return self.equipmentGrid[index]
end

function ShipState:setSlotAt(index, slot)
    if not self.equipmentGrid then
        self.equipmentGrid = {}
    end
    self.equipmentGrid[index] = slot
end

function ShipState:clearSlotAt(index)
    if self.equipmentGrid and self.equipmentGrid[index] then
        self.equipmentGrid[index] = nil
    end
end

function ShipState:getSlotType(slotData)
    if not slotData then return nil end
    return slotData.baseType or slotData.type
end

function ShipState:resolveModuleDisplayName(entry)
    if not entry then return nil end
    local module = entry.module
    if module then
        return module.proceduralName or module.name or entry.id
    end
    return entry.id
end

function ShipState:resolveSlotHeaderLabel(slotType)
    if slotType == "turret" then
        return "Turrets:"
    elseif slotType == "shield" then
        return "Shield Slots"
    elseif slotType == "utility" then
        return "Utility Slots"
    end
    return "Module Slots"
end

function ShipState:reset()
    self.visible = false
    self.selectedSlot = nil
    self.hoveredSlot = nil
    self.drag = nil
    self.dragStartSlot = nil
    self.dragItem = nil
    self.selectedTurret = nil
    self.turretDropdownVisible = false
    self.contextMenu = {
        visible = false,
        x = 0,
        y = 0,
        slot = nil,
        options = {}
    }
    self.contextMenuActive = false
    self.inputActive = false
    self.inputType = nil
    self.inputValue = ""
    self.inputRect = nil
end

return ShipState
