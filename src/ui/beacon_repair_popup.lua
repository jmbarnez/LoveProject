local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local Window = require("src.ui.common.window")
local Notifications = require("src.ui.notifications")
local Content = require("src.content.content")
local IconSystem = require("src.core.icon_system")

local BeaconRepairPopup = {}
BeaconRepairPopup.__index = BeaconRepairPopup

BeaconRepairPopup.visible = false
BeaconRepairPopup.window = nil
BeaconRepairPopup.station = nil
BeaconRepairPopup.player = nil
BeaconRepairPopup.requirements = {}
BeaconRepairPopup.canRepair = false
BeaconRepairPopup.repairButton = nil
BeaconRepairPopup.onRepairAttempt = nil
BeaconRepairPopup.interactionRange = 220

local function getPlayerItemCount(player, itemId)
    local cargo = player and player.components and player.components.cargo
    if not cargo or not cargo.getQuantity then return 0 end
    local count = cargo:getQuantity(itemId)
    return count or 0
end

local function prettyName(itemId, def)
    if def and def.name then
        return def.name
    end
    local name = itemId:gsub("_", " ")
    return name:gsub("%f[%a].", string.upper)
end

function BeaconRepairPopup.init()
    BeaconRepairPopup.window = Window.new({
        title = "Beacon Repair",
        width = 500,
        height = 400,
        minWidth = 400,
        minHeight = 350,
        useLoadPanelTheme = true,
        bottomBarHeight = 60,
        draggable = true,
        resizable = false,
        closable = true,
        drawContent = BeaconRepairPopup.drawContent,
        onClose = function()
            BeaconRepairPopup.visible = false
        end
    })
end

function BeaconRepairPopup.show(station, player, onRepairAttempt)
    if not station or not player then return end

    if not BeaconRepairPopup.window then
        BeaconRepairPopup.init()
    end

    BeaconRepairPopup.station = station
    BeaconRepairPopup.player = player
    BeaconRepairPopup.onRepairAttempt = onRepairAttempt

    BeaconRepairPopup.visible = true
    BeaconRepairPopup.window.visible = true
    BeaconRepairPopup.refresh()
end

function BeaconRepairPopup.hide()
    BeaconRepairPopup.visible = false
    BeaconRepairPopup.station = nil
    BeaconRepairPopup.player = nil
    BeaconRepairPopup.requirements = {}
    BeaconRepairPopup.canRepair = false
    BeaconRepairPopup.onRepairAttempt = nil
    BeaconRepairPopup.repairButton = nil
    if BeaconRepairPopup.window then
        BeaconRepairPopup.window.visible = false
    end
end

function BeaconRepairPopup.refresh()
    local station = BeaconRepairPopup.station
    local player = BeaconRepairPopup.player

    local requirements = {}
    local canRepair = true

    if station and station.components and station.components.repairable then
        local list = station.components.repairable.repairCost or {}
        for _, entry in ipairs(list) do
            local itemId = entry.item
            local needed = entry.amount or 0
            local success, def = pcall(Content.getItem, itemId)
            if not success then def = nil end
            local have = getPlayerItemCount(player, itemId)
            local hasEnough = have >= needed
            if not hasEnough then
                canRepair = false
            end
            requirements[#requirements + 1] = {
                itemId = itemId,
                def = def,
                name = prettyName(itemId, def),
                need = needed,
                have = have,
                hasEnough = hasEnough,
            }
        end
    else
        canRepair = false
    end

    BeaconRepairPopup.requirements = requirements
    BeaconRepairPopup.canRepair = canRepair
end

function BeaconRepairPopup.drawContent(self, x, y, w, h)
    local centerX = x + w * 0.5
    local centerY = y + h * 0.5
    
    -- Draw title
    love.graphics.setFont(Theme.fonts.large)
    Theme.setColor(Theme.colors.text)
    love.graphics.printf("🔧 BEACON REPAIR 🔧", x + 20, y + 20, w - 40, "center")
    
    -- Draw description
    love.graphics.setFont(Theme.fonts.small)
    Theme.setColor(Theme.colors.textSecondary)
    local description = "Repair the defensive beacon to reactivate the protective no-spawn field."
    love.graphics.printf(description, x + 20, y + 50, w - 40, "center")
    
    -- Draw requirements section
    love.graphics.setFont(Theme.fonts.medium)
    Theme.setColor(Theme.colors.text)
    love.graphics.printf("Required Materials", x + 20, y + 80, w - 40, "center")
    
    -- Draw requirements as cards
    local cardWidth = 120
    local cardHeight = 140
    local cardSpacing = 15
    local startX = centerX - ((#BeaconRepairPopup.requirements * cardWidth + (#BeaconRepairPopup.requirements - 1) * cardSpacing) * 0.5)
    local cardY = y + 110
    
    for i, req in ipairs(BeaconRepairPopup.requirements) do
        local cardX = startX + (i - 1) * (cardWidth + cardSpacing)
        
        -- Card background
        local cardColor = req.hasEnough and {0.2, 0.6, 0.2, 1.0} or {0.6, 0.2, 0.2, 1.0}
        local bgColor = req.hasEnough and {0.1, 0.3, 0.1, 0.9} or {0.3, 0.1, 0.1, 0.9}
        
        -- Card background
        Theme.setColor(bgColor)
        love.graphics.rectangle("fill", cardX, cardY, cardWidth, cardHeight, 8, 8)
        
        -- Card border
        Theme.setColor(cardColor)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", cardX, cardY, cardWidth, cardHeight, 8, 8)
        
        -- Item icon
        local iconSize = 64
        local iconX = cardX + (cardWidth - iconSize) * 0.5
        local iconY = cardY + 15
        
        if req.def and req.def.icon then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(req.def.icon, iconX, iconY, 0, iconSize / 128, iconSize / 128)
        else
            -- Fallback icon
            love.graphics.setFont(Theme.fonts.large)
            Theme.setColor(0.8, 0.8, 0.8, 1)
            love.graphics.printf("📦", iconX - 16, iconY - 16, iconSize + 32, "center")
        end
        
        -- Item name
        love.graphics.setFont(Theme.fonts.small)
        Theme.setColor(Theme.colors.text)
        love.graphics.printf(req.name, cardX + 5, iconY + iconSize + 5, cardWidth - 10, "center")
        
        -- Amount text
        local amountText = string.format("%d / %d", req.have, req.need)
        local amountColor = req.hasEnough and Theme.colors.success or Theme.colors.danger
        Theme.setColor(amountColor)
        love.graphics.setFont(Theme.fonts.normal)
        love.graphics.printf(amountText, cardX + 5, cardY + cardHeight - 25, cardWidth - 10, "center")
    end
    
    -- Draw status message
    local statusY = cardY + cardHeight + 20
    love.graphics.setFont(Theme.fonts.medium)
    if BeaconRepairPopup.canRepair then
        Theme.setColor(Theme.colors.success)
        love.graphics.printf("✓ All materials ready for repair", x + 20, statusY, w - 40, "center")
    else
        Theme.setColor(Theme.colors.danger)
        love.graphics.printf("✗ Missing required materials", x + 20, statusY, w - 40, "center")
    end
    
    -- Draw repair button
    local buttonWidth = 160
    local buttonHeight = 40
    local buttonX = centerX - buttonWidth * 0.5
    local buttonY = y + h - 50
    
    -- Create button object for click handling
    BeaconRepairPopup.repairButton = {_rect = {x = buttonX, y = buttonY, w = buttonWidth, h = buttonHeight}}
    
    -- Get hover state
    local mx, my = Viewport.getMousePosition()
    local hover = Theme.handleButtonClick(BeaconRepairPopup.repairButton, mx, my)
    
    -- Button color based on repair availability
    local buttonColor = BeaconRepairPopup.canRepair and Theme.colors.success or Theme.colors.danger
    local buttonText = BeaconRepairPopup.canRepair and "REPAIR BEACON" or "MISSING MATERIALS"
    
    -- Draw styled button
    Theme.drawStyledButton(buttonX, buttonY, buttonWidth, buttonHeight, buttonText, hover, love.timer.getTime(), buttonColor, false)
end

function BeaconRepairPopup.onRepairButtonPressed()
    if not BeaconRepairPopup.visible or not BeaconRepairPopup.station or not BeaconRepairPopup.player then
        return
    end

    if not BeaconRepairPopup.canRepair then
        Notifications.add("Insufficient materials for repair", "error")
        return
    end

    if BeaconRepairPopup.onRepairAttempt then
        local success = BeaconRepairPopup.onRepairAttempt(BeaconRepairPopup.station, BeaconRepairPopup.player)
        if success then
            Notifications.add("Beacon station repaired successfully!", "success")
            BeaconRepairPopup.hide()
        else
            Notifications.add("Insufficient materials for repair", "error")
            BeaconRepairPopup.refresh()
        end
    end
end

function BeaconRepairPopup.update(dt)
    if not BeaconRepairPopup.visible then return end

    local station = BeaconRepairPopup.station
    local player = BeaconRepairPopup.player
    if not station or not station.components or not station.components.repairable then
        BeaconRepairPopup.hide()
        return
    end

    if not station.components.repairable.broken then
        BeaconRepairPopup.hide()
        return
    end

    if not player or not player.components or not player.components.position then
        BeaconRepairPopup.hide()
        return
    end

    local stationPos = station.components.position
    if not stationPos then
        BeaconRepairPopup.hide()
        return
    end

    local playerPos = player.components.position
    local dx = playerPos.x - stationPos.x
    local dy = playerPos.y - stationPos.y
    local distSq = dx * dx + dy * dy
    if distSq > (BeaconRepairPopup.interactionRange * BeaconRepairPopup.interactionRange) then
        BeaconRepairPopup.hide()
        return
    end

    BeaconRepairPopup.refresh()
end

function BeaconRepairPopup.mousepressed(x, y, button)
    if not BeaconRepairPopup.visible or not BeaconRepairPopup.window then
        return false
    end

    if BeaconRepairPopup.window:mousepressed(x, y, button) then
        return true, false
    end

    if button == 1 and BeaconRepairPopup.repairButton and BeaconRepairPopup.repairButton._rect then
        local clicked = Theme.handleButtonClick(BeaconRepairPopup.repairButton, x, y, function()
            BeaconRepairPopup.onRepairButtonPressed()
        end)
        if clicked then
            return true, false
        end
    end

    return false
end

function BeaconRepairPopup.mousereleased(x, y, button)
    if not BeaconRepairPopup.visible or not BeaconRepairPopup.window then
        return false
    end
    return BeaconRepairPopup.window:mousereleased(x, y, button)
end

function BeaconRepairPopup.mousemoved(x, y, dx, dy)
    if not BeaconRepairPopup.visible or not BeaconRepairPopup.window then
        return false
    end
    return BeaconRepairPopup.window:mousemoved(x, y, dx, dy)
end

function BeaconRepairPopup.getRect()
    if not BeaconRepairPopup.visible or not BeaconRepairPopup.window then
        return nil
    end
    return {
        x = BeaconRepairPopup.window.x,
        y = BeaconRepairPopup.window.y,
        w = BeaconRepairPopup.window.width,
        h = BeaconRepairPopup.window.height,
    }
end

return BeaconRepairPopup
