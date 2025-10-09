--[[
    Ship UI Input Handler
    
    Handles all input events for the Ship UI including:
    - Mouse interactions (clicks, drags, hovers)
    - Keyboard input
    - Text input
    - Context menu handling
]]

local Theme = require("src.core.theme")
local EquipmentGrid = require("src.ui.ship.equipment_grid")
local TurretManager = require("src.ui.ship.turret_manager")
local HotbarPreview = require("src.ui.ship.hotbar_preview")

local ShipInputHandler = {}

function ShipInputHandler.mousepressed(self, x, y, button)
    if not self:isVisible() then return false end
    
    -- Check if click is within window bounds
    if not self.window:isPointInside(x, y) then
        return false
    end
    
    -- Handle context menu clicks
    if self:handleContextMenuClick(x, y, button) then
        return true
    end
    
    -- Handle equipment grid clicks
    if self:handleEquipmentGridClick(x, y, button) then
        return true
    end
    
    -- Handle turret manager clicks
    if self:handleTurretManagerClick(x, y, button) then
        return true
    end
    
    -- Handle hotbar preview clicks
    if self:handleHotbarPreviewClick(x, y, button) then
        return true
    end
    
    return false
end

function ShipInputHandler.mousereleased(self, x, y, button)
    if not self:isVisible() then return false end
    
    -- Handle drag end
    if self.state:getDrag() then
        return self:handleDragEnd(x, y)
    end
    
    return false
end

function ShipInputHandler.mousemoved(self, x, y, dx, dy)
    if not self:isVisible() then return false end
    
    -- Handle drag update
    if self.state:getDrag() then
        EquipmentGrid.updateDrag(self, x, y)
        return true
    end
    
    -- Handle hovers
    local handled = false
    
    if self:handleEquipmentGridHover(x, y) then
        handled = true
    end
    
    if self:handleTurretManagerHover(x, y) then
        handled = true
    end
    
    if self:handleHotbarPreviewHover(x, y) then
        handled = true
    end
    
    return handled
end

function ShipInputHandler.keypressed(self, key)
    if not self:isVisible() then return false end
    
    -- Handle input field input
    if self.state:isInputActive() then
        return self:handleInputFieldKey(key)
    end
    
    -- Handle escape to close context menu
    if key == "escape" then
        if self.state:isContextMenuActive() then
            self.state:setContextMenuActive(false)
            self.state:setContextMenu({visible = false, x = 0, y = 0, slot = nil, options = {}})
            return true
        end
    end
    
    return false
end

function ShipInputHandler.textinput(self, text)
    if not self:isVisible() then return false end
    
    -- Handle input field text input
    if self.state:isInputActive() then
        return self:handleInputFieldText(text)
    end
    
    return false
end

function ShipInputHandler.handleContextMenuClick(self, x, y, button)
    local contextMenu = self.state:getContextMenu()
    if not contextMenu or not contextMenu.visible then
        return false
    end
    
    -- Check if click is within context menu
    local menuX = contextMenu.x
    local menuY = contextMenu.y
    local menuW = 150
    local menuH = #contextMenu.options * 24 + 8
    
    if x >= menuX and x < menuX + menuW and y >= menuY and y < menuY + menuH then
        -- Handle context menu option click
        local optionIndex = math.floor((y - menuY - 4) / 24) + 1
        if optionIndex >= 1 and optionIndex <= #contextMenu.options then
            local option = contextMenu.options[optionIndex]
            self:handleContextMenuAction(option.action, contextMenu)
            return true
        end
    end
    
    -- Click outside context menu - close it
    self.state:setContextMenuActive(false)
    self.state:setContextMenu({visible = false, x = 0, y = 0, slot = nil, options = {}})
    return true
end

function ShipInputHandler.handleEquipmentGridClick(self, x, y, button)
    -- Check if click is within equipment grid area
    local gridX = self.window.x + 12
    local gridY = self.window.y + 60
    local gridW = self.window.width - 24
    local gridH = self.window.height - 200
    
    if x >= gridX and x < gridX + gridW and y >= gridY and y < gridY + gridH then
        if button == 1 then
            return EquipmentGrid.handleSlotClick(self, x, y, button)
        elseif button == 2 then
            return EquipmentGrid.handleSlotRightClick(self, x, y, button)
        end
    end
    
    return false
end

function ShipInputHandler.handleTurretManagerClick(self, x, y, button)
    -- Check if click is within turret manager area
    local turretX = self.window.x + 12
    local turretY = self.window.y + 280
    local turretW = self.window.width - 24
    local turretH = 120
    
    if x >= turretX and x < turretX + turretW and y >= turretY and y < turretY + turretH then
        if button == 1 then
            return TurretManager.handleClick(self, x, y, button)
        elseif button == 2 then
            return TurretManager.handleRightClick(self, x, y, button)
        end
    end
    
    return false
end

function ShipInputHandler.handleHotbarPreviewClick(self, x, y, button)
    -- Check if click is within hotbar preview area
    local hotbarX = self.window.x + 12
    local hotbarY = self.window.y + 420
    local hotbarW = self.window.width - 24
    local hotbarH = 80
    
    if x >= hotbarX and x < hotbarX + hotbarW and y >= hotbarY and y < hotbarY + hotbarH then
        if button == 1 then
            return HotbarPreview.handleClick(self, x, y, button)
        elseif button == 2 then
            return HotbarPreview.handleRightClick(self, x, y, button)
        end
    end
    
    return false
end

function ShipInputHandler.handleEquipmentGridHover(self, x, y)
    local gridX = self.window.x + 12
    local gridY = self.window.y + 60
    local gridW = self.window.width - 24
    local gridH = self.window.height - 200
    
    if x >= gridX and x < gridX + gridW and y >= gridY and y < gridY + gridH then
        return EquipmentGrid.handleSlotHover(self, x, y)
    end
    
    return false
end

function ShipInputHandler.handleTurretManagerHover(self, x, y)
    local turretX = self.window.x + 12
    local turretY = self.window.y + 280
    local turretW = self.window.width - 24
    local turretH = 120
    
    if x >= turretX and x < turretX + turretW and y >= turretY and y < turretY + turretH then
        return TurretManager.handleHover(self, x, y)
    end
    
    return false
end

function ShipInputHandler.handleHotbarPreviewHover(self, x, y)
    local hotbarX = self.window.x + 12
    local hotbarY = self.window.y + 420
    local hotbarW = self.window.width - 24
    local hotbarH = 80
    
    if x >= hotbarX and x < hotbarX + hotbarW and y >= hotbarY and y < hotbarY + hotbarH then
        return HotbarPreview.handleHover(self, x, y)
    end
    
    return false
end

function ShipInputHandler.handleDragEnd(self, x, y)
    local dragStartSlot = self.state:getDragStartSlot()
    if not dragStartSlot then return false end
    
    -- Try to end drag on equipment grid
    local gridX = self.window.x + 12
    local gridY = self.window.y + 60
    local gridW = self.window.width - 24
    local gridH = self.window.height - 200
    
    if x >= gridX and x < gridX + gridW and y >= gridY and y < gridY + gridH then
        return EquipmentGrid.endDrag(self, x, y)
    end
    
    -- Clear drag state
    self.state:setDrag(nil)
    self.state:setDragStartSlot(nil)
    self.state:setDragItem(nil)
    
    return false
end

function ShipInputHandler.handleContextMenuAction(self, action, contextMenu)
    if action == "unequip" then
        -- Unequip item
        if contextMenu.slot then
            local grid = self.state:getEquipmentGrid()
            for i, slot in ipairs(grid) do
                if slot == contextMenu.slot then
                    self.state:clearSlotAt(i)
                    break
                end
            end
        end
    elseif action == "info" then
        -- Show item info
        if contextMenu.slot then
            -- Open item info tooltip or panel
            -- This would typically show detailed item information
        end
    elseif action == "toggle" then
        -- Toggle turret enabled/disabled
        if contextMenu.turretIndex then
            TurretManager.toggleTurret(self, contextMenu.turretIndex)
        end
    elseif action == "remove" then
        -- Remove turret
        if contextMenu.turretIndex then
            TurretManager.removeTurret(self, contextMenu.turretIndex)
        end
    elseif action == "configure" then
        -- Configure turret
        if contextMenu.turretIndex then
            TurretManager.configureTurret(self, contextMenu.turretIndex)
        end
    end
    
    -- Close context menu
    self.state:setContextMenuActive(false)
    self.state:setContextMenu({visible = false, x = 0, y = 0, slot = nil, options = {}})
end

function ShipInputHandler.handleInputFieldKey(self, key)
    if key == "return" or key == "kpenter" then
        -- Apply input
        self.state:setInputActive(false)
        return true
    elseif key == "escape" then
        -- Cancel input
        self.state:setInputActive(false)
        return true
    elseif key == "backspace" then
        -- Handle backspace
        local currentValue = self.state:getInputValue()
        if #currentValue > 0 then
            self.state:setInputValue(currentValue:sub(1, -2))
        end
        return true
    end
    
    return false
end

function ShipInputHandler.handleInputFieldText(self, text)
    local currentValue = self.state:getInputValue()
    self.state:setInputValue(currentValue .. text)
    return true
end

return ShipInputHandler
