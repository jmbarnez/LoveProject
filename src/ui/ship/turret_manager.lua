--[[
    Ship Turret Manager
    
    Handles turret-specific operations including:
    - Turret selection and management
    - Turret configuration
    - Turret dropdown handling
    - Turret state updates
]]

local Theme = require("src.core.theme")
local Content = require("src.content.content")
local Dropdown = require("src.ui.common.dropdown")

local TurretManager = {}

function TurretManager.draw(self, x, y, w, h)
    local state = self.state
    if not state then return end
    
    local turrets = state:getTurrets()
    if not turrets or #turrets == 0 then
        TurretManager.drawNoTurrets(x, y, w, h)
        return
    end
    
    -- Turret list background
    Theme.setColor(Theme.colors.bg1)
    love.graphics.rectangle("fill", x, y, w, h)
    
    -- Turret list border
    Theme.setColor(Theme.colors.border)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h)
    
    -- Title
    Theme.setColor(Theme.colors.text)
    Theme.setFont("medium")
    love.graphics.print("Turrets", x + 12, y + 12)
    
    -- Draw turret list
    local listY = y + 40
    local listH = h - 52
    local itemHeight = 32
    
    for i, turret in ipairs(turrets) do
        local itemY = listY + (i - 1) * itemHeight
        local isSelected = state:getSelectedTurret() == i
        local isHovered = state.hoveredTurret == i
        
        TurretManager.drawTurretItem(self, turret, x + 8, itemY, w - 16, itemHeight, i, isSelected, isHovered)
    end
end

function TurretManager.drawNoTurrets(x, y, w, h)
    -- Background
    Theme.setColor(Theme.colors.bg1)
    love.graphics.rectangle("fill", x, y, w, h)
    
    -- Border
    Theme.setColor(Theme.colors.border)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h)
    
    -- No turrets message
    Theme.setColor(Theme.colors.textSecondary)
    Theme.setFont("medium")
    local text = "No turrets equipped"
    local textW = Theme.fonts.medium:getWidth(text)
    local textH = Theme.fonts.medium:getHeight()
    local textX = x + (w - textW) * 0.5
    local textY = y + (h - textH) * 0.5
    love.graphics.print(text, textX, textY)
end

function TurretManager.drawTurretItem(self, turret, x, y, w, h, index, selected, hovered)
    local state = self.state
    
    -- Item background
    local bgColor = selected and Theme.colors.accent or (hovered and Theme.colors.bg3 or Theme.colors.bg2)
    Theme.setColor(bgColor)
    love.graphics.rectangle("fill", x, y, w, h)
    
    -- Item border
    local borderColor = selected and Theme.colors.borderBright or Theme.colors.border
    Theme.setColor(borderColor)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h)
    
    -- Turret icon
    local iconSize = h - 8
    local iconX = x + 4
    local iconY = y + 4
    
    if turret.icon then
        local IconSystem = require("src.core.icon_system")
        IconSystem.drawIcon(turret.icon, iconX, iconY, iconSize)
    else
        -- Fallback icon
        Theme.setColor(Theme.colors.textSecondary)
        love.graphics.rectangle("fill", iconX, iconY, iconSize, iconSize)
    end
    
    -- Turret name
    local nameX = iconX + iconSize + 8
    local nameY = y + 8
    local nameW = w - (nameX - x) - 8
    
    Theme.setColor(Theme.colors.text)
    Theme.setFont("small")
    local turretName = turret.name or turret.id or "Unknown Turret"
    love.graphics.print(turretName, nameX, nameY)
    
    -- Turret status
    local statusY = nameY + 14
    local statusText = turret.enabled and "Enabled" or "Disabled"
    local statusColor = turret.enabled and Theme.colors.success or Theme.colors.danger
    Theme.setColor(statusColor)
    Theme.setFont("xsmall")
    love.graphics.print(statusText, nameX, statusY)
    
    -- Store item rect for interaction
    state.turretRects = state.turretRects or {}
    state.turretRects[index] = {x = x, y = y, w = w, h = h}
end

function TurretManager.handleClick(self, mx, my, button)
    if button ~= 1 then return false end
    
    local state = self.state
    if not state.turretRects then return false end
    
    for index, rect in pairs(state.turretRects) do
        if mx >= rect.x and mx < rect.x + rect.w and
           my >= rect.y and my < rect.y + rect.h then
            state:setSelectedTurret(index)
            return true
        end
    end
    
    return false
end

function TurretManager.handleRightClick(self, mx, my, button)
    if button ~= 2 then return false end
    
    local state = self.state
    if not state.turretRects then return false end
    
    for index, rect in pairs(state.turretRects) do
        if mx >= rect.x and mx < rect.x + rect.w and
           my >= rect.y and my < rect.y + rect.h then
            local turrets = state:getTurrets()
            local turret = turrets[index]
            
            if turret then
                local contextMenu = {
                    visible = true,
                    x = mx,
                    y = my,
                    turret = turret,
                    turretIndex = index,
                    options = {
                        {text = turret.enabled and "Disable" or "Enable", action = "toggle"},
                        {text = "Configure", action = "configure"},
                        {text = "Remove", action = "remove"}
                    }
                }
                state:setContextMenu(contextMenu)
                return true
            end
        end
    end
    
    return false
end

function TurretManager.handleHover(self, mx, my)
    local state = self.state
    if not state.turretRects then return false end
    
    for index, rect in pairs(state.turretRects) do
        if mx >= rect.x and mx < rect.x + rect.w and
           my >= rect.y and my < rect.y + rect.h then
            state.hoveredTurret = index
            return true
        end
    end
    
    state.hoveredTurret = nil
    return false
end

function TurretManager.toggleTurret(self, turretIndex)
    local state = self.state
    local turrets = state:getTurrets()
    local turret = turrets[turretIndex]
    
    if turret then
        turret.enabled = not turret.enabled
        
        -- Update player equipment
        if state:getPlayer() and state:getPlayer().components and state:getPlayer().components.equipment then
            local playerTurrets = state:getPlayer().components.equipment.turrets
            if playerTurrets and playerTurrets[turretIndex] then
                playerTurrets[turretIndex].enabled = turret.enabled
            end
        end
        
        return true
    end
    
    return false
end

function TurretManager.removeTurret(self, turretIndex)
    local state = self.state
    local turrets = state:getTurrets()
    
    if turrets[turretIndex] then
        table.remove(turrets, turretIndex)
        
        -- Update player equipment
        if state:getPlayer() and state:getPlayer().components and state:getPlayer().components.equipment then
            local playerTurrets = state:getPlayer().components.equipment.turrets
            if playerTurrets then
                table.remove(playerTurrets, turretIndex)
            end
        end
        
        -- Clear selection if removed turret was selected
        if state:getSelectedTurret() == turretIndex then
            state:setSelectedTurret(nil)
        end
        
        return true
    end
    
    return false
end

function TurretManager.configureTurret(self, turretIndex)
    local state = self.state
    local turrets = state:getTurrets()
    local turret = turrets[turretIndex]
    
    if turret then
        -- Open turret configuration UI
        -- This would typically open a separate configuration panel
        state:setInputActive(true, "turret_name")
        state:setInputValue(turret.name or "")
        return true
    end
    
    return false
end

function TurretManager.updateTurretsFromPlayer(self)
    local state = self.state
    local player = state:getPlayer()
    
    if player and player.components and player.components.equipment and player.components.equipment.turrets then
        state:setTurrets(player.components.equipment.turrets)
    end
end

function TurretManager.getTurretAtPosition(self, mx, my)
    local state = self.state
    if not state.turretRects then return nil end
    
    for index, rect in pairs(state.turretRects) do
        if mx >= rect.x and mx < rect.x + rect.w and
           my >= rect.y and my < rect.y + rect.h then
            return index, rect
        end
    end
    
    return nil
end

return TurretManager
