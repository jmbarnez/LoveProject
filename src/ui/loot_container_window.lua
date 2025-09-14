local Content = require("src.content.content")
local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local Notifications = require("src.ui.notifications")
local Util = require("src.core.util")
local Tooltip = require("src.ui.tooltip")

local LootContainerWindow = {}

local currentContainer = nil
local currentPlayer = nil
local currentCamera = nil
local isOpen = false

-- Window state
local windowW = 520
local windowH = 360
local windowX = 0
local windowY = 0
local dragging = false
local dragDX = 0
local dragDY = 0
local _closeButton = nil
local _slotRects = {}
local _transferAllButton = nil
local hoveredItem = nil
local hoverTimer = 0

local function worldToScreen(wx, wy, camera)
    if not camera then return 0, 0 end
    local vw, vh = Viewport.getDimensions()
    local sx = (wx - camera.x) * camera.scale + vw * 0.5
    local sy = (wy - camera.y) * camera.scale + vh * 0.5
    return sx, sy
end

local function getCargoCapacity(player)
    if player and player.ship and player.ship.cargo and player.ship.cargo.capacity then
        return player.ship.cargo.capacity
    end
    return 0/0 -- NaN indicates unlimited
end

local function getCargoUsed(player)
    if not player or not player.inventory then return 0 end
    local used = 0
    for id, qty in pairs(player.inventory) do
        local def = (Content.getItem and Content.getItem(id)) or (Content.getTurret and Content.getTurret(id))
        if def and def.volume then used = used + (def.volume * qty) end
    end
    return used
end

local function tryTransfer(player, stack, maxQty)
    local qty = math.min(stack.qty or 1, maxQty or stack.qty or 1)
    local def = (Content.getItem and Content.getItem(stack.id)) or (Content.getTurret and Content.getTurret(stack.id))
    local volume = (def and def.volume) or 0
    local cap = getCargoCapacity(player)
    local used = getCargoUsed(player)
    local canTake = qty
    if cap == cap and volume > 0 then -- finite capacity and volumetric item
        local free = math.max(0, cap - used)
        canTake = math.min(qty, math.floor(free / volume))
    end
    if canTake <= 0 then return 0 end
    local Cargo = require("src.core.cargo")
    -- Aggregate add to ensure single, consistent notification
    Cargo.add(player, stack.id, canTake)
    stack.qty = stack.qty - canTake
    return canTake
end

function LootContainerWindow.open(container, player, camera)
    currentContainer = container
    currentPlayer = player
    currentCamera = camera
    isOpen = true
    
    -- Position window near the container
    local containerPos = currentContainer.entity.components.position
    if containerPos then
        local sx, sy = worldToScreen(containerPos.x, containerPos.y, currentCamera)
        local sw, sh = Viewport.getDimensions()
        windowX = math.floor(math.max(50, math.min(sw - windowW - 50, sx + 50)))
        windowY = math.floor(math.max(50, math.min(sh - windowH - 50, sy - windowH/2)))
    end
end

function LootContainerWindow.close()
    currentContainer = nil
    currentPlayer = nil
    currentCamera = nil
    isOpen = false
end

function LootContainerWindow.isOpen()
    return isOpen
end

function LootContainerWindow.getRect()
    if not isOpen then return nil end
    return { x = windowX, y = windowY, w = windowW, h = windowH }
end

function LootContainerWindow.draw()
    if not isOpen or not currentContainer then return end

    local containerPos = currentContainer.entity.components.position
    if not containerPos then
        LootContainerWindow.close()
        return
    end

    local x, y, w, h = windowX, windowY, windowW, windowH

    -- Window
    Theme.drawGradientGlowRect(x, y, w, h, 8,
        Theme.colors.bg1, Theme.colors.bg0,
        Theme.colors.accent, Theme.effects.glowWeak)
    Theme.drawEVEBorder(x, y, w, h, 8, Theme.colors.border, 6)

    -- Title bar
    local titleH = 24
    Theme.drawGradientGlowRect(x, y, w, titleH, 8,
        Theme.colors.bg3, Theme.colors.bg2,
        Theme.colors.accent, Theme.effects.glowWeak)
    
    Theme.setColor(Theme.colors.textHighlight)
    love.graphics.setFont(Theme.fonts and Theme.fonts.medium or love.graphics.getFont())
    local font = love.graphics.getFont()
    local textWidth = font:getWidth("Loot Container")
    local textHeight = font:getHeight()
    love.graphics.print("Loot Container", math.floor(x + (w - textWidth) / 2), math.floor(y + (titleH - textHeight) / 2))
    love.graphics.setFont(Theme.fonts and Theme.fonts.normal or love.graphics.getFont())

    -- Close button
    local closeSize = 20
    local closeX = x + w - 22
    local closeY = y + 2
    _closeButton = { x = closeX, y = closeY, w = closeSize, h = closeSize }
    local mx, my = Viewport.getMousePosition()
    local closeHover = mx >= closeX and mx <= closeX + closeSize and my >= closeY and my <= closeY + closeSize
    Theme.drawCloseButton(_closeButton, closeHover)

    -- Grid layout
    local slotSize = 72
    local padding = 8
    local startY = y + titleH + 8
    local contentW = w - 16
    local cols = math.floor(contentW / (slotSize + padding))
    if cols < 1 then cols = 1 end
    local startX = x + (w - cols * (slotSize + padding) + padding) / 2

    local items = {}
    if currentContainer.items then
        for _, stack in ipairs(currentContainer.items) do
            table.insert(items, { id = stack.id, qty = stack.qty })
        end
    end

    -- Sort by name
    table.sort(items, function(a,b)
        local an = (Content.getItem(a.id) and Content.getItem(a.id).name) or (Content.getTurret(a.id) and Content.getTurret(a.id).name) or a.id
        local bn = (Content.getItem(b.id) and Content.getItem(b.id).name) or (Content.getTurret(b.id) and Content.getTurret(b.id).name) or b.id
        return an < bn
    end)

    love.graphics.push()
    love.graphics.setScissor(x, y + titleH, w, h - titleH - 24) -- Leave space for bottom bar

    _slotRects = {}
    for i, it in ipairs(items) do
        local index = i - 1
        local row = math.floor(index / cols)
        local col = index % cols
        local sx = startX + col * (slotSize + padding)
        local sy = startY + row * (slotSize + padding)
        local dx = math.floor(sx + 0.5)
        local dy = math.floor(sy + 0.5)

        -- Slot background
        Theme.drawGradientGlowRect(dx, dy, slotSize, slotSize, 4,
            Theme.colors.bg1, Theme.colors.bg0, Theme.colors.border, Theme.effects.glowWeak)

        -- Get item definition
        local def = Content.getItem(it.id) or Content.getTurret(it.id)
        local name = (def and def.name) or it.id
        local value = (def and def.value) or 0

        -- Icon
        if def and def.icon and type(def.icon) == "userdata" then
            Theme.setColor({1,1,1,1})
            local scale = math.min((slotSize - 8) / def.icon:getWidth(), (slotSize - 8) / def.icon:getHeight())
            love.graphics.draw(def.icon, dx + 4, dy + 4, 0, scale, scale)
        else
            Theme.setColor(Theme.colors.text)
            love.graphics.printf(name, math.floor(dx + 4), math.floor(dy + slotSize/2 - 7), slotSize - 8, "center")
        end

        -- Name
        Theme.setColor(Theme.colors.text)
        love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
        love.graphics.printf(name, math.floor(dx), math.floor(dy + slotSize - 20), slotSize, "center")

        -- Quantity
        Theme.setColor(Theme.colors.accent)
        love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
        love.graphics.printf(Util.formatNumber(it.qty), math.floor(dx), math.floor(dy + 2), slotSize - 4, "right")

        _slotRects[i] = { x = dx, y = dy, w = slotSize, h = slotSize, stack = it }

        -- Check for hover
        if mx >= dx and mx <= dx + slotSize and my >= dy and my <= dy + slotSize then
            if hoveredItem and hoveredItem.stack.id == it.id then
                hoverTimer = hoverTimer + love.timer.getDelta()
            else
                hoveredItem = { stack = it, def = def }
                hoverTimer = 0
            end
        end
    end

    love.graphics.setScissor()
    love.graphics.pop()

    -- Draw bottom bar (without credits)
    local barH = 24
    local barY = y + h - barH
    Theme.drawGradientGlowRect(x, barY, w, barH, 8, Theme.colors.bg3, Theme.colors.bg2, Theme.colors.border, Theme.effects.glowWeak)

    -- Transfer All button
    local buttonW = 80
    local buttonH = 18
    local buttonX = x + 8
    local buttonY = barY + 3
    _transferAllButton = { x = buttonX, y = buttonY, w = buttonW, h = buttonH }
    
    local mx, my = Viewport.getMousePosition()
    local buttonHover = mx >= buttonX and mx <= buttonX + buttonW and my >= buttonY and my <= buttonY + buttonH
    local buttonColor = buttonHover and Theme.colors.bg2 or Theme.colors.bg1
    
    -- Button background
    Theme.drawGradientGlowRect(buttonX, buttonY, buttonW, buttonH, 3,
        buttonColor, Theme.colors.bg0, Theme.colors.accent, Theme.effects.glowWeak)
    Theme.drawEVEBorder(buttonX, buttonY, buttonW, buttonH, 3, Theme.colors.border, 1)
    
    -- Button text
    Theme.setColor(Theme.colors.textHighlight)
    love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
    love.graphics.printf("Transfer All", math.floor(buttonX), math.floor(buttonY + 2), buttonW, "center")

    -- Item count only (no credits display)
    local itemCount = #items
    local itemText = itemCount .. " items"
    love.graphics.setFont(Theme.fonts and Theme.fonts.medium or love.graphics.getFont())
    local itemTextWidth = font:getWidth(itemText)
    local startX = x + w - itemTextWidth - 8
    Theme.setColor(Theme.colors.textSecondary)
    love.graphics.print(itemText, math.floor(startX), math.floor(barY + (barH - font:getHeight()) / 2))

end

function LootContainerWindow.mousepressed(mx, my, button)
    if not isOpen then return false end

    if button == 1 then
        -- Close button
        if _closeButton then
            local btn = _closeButton
            if mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
                LootContainerWindow.close()
                return true
            end
        end

        -- Title bar drag
        local titleRect = { x = windowX, y = windowY, w = windowW, h = 32 }
        if mx >= titleRect.x and mx <= titleRect.x + titleRect.w and my >= titleRect.y and my <= titleRect.y + titleRect.h then
            dragging = true
            dragDX = mx - windowX
            dragDY = my - windowY
            return true
        end

        -- Transfer All button
        if _transferAllButton then
            local btn = _transferAllButton
            if mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
                -- Transfer all items
                for i = #currentContainer.items, 1, -1 do
                    local stack = currentContainer.items[i]
                    tryTransfer(currentPlayer, stack, stack.qty)
                    if stack.qty <= 0 then
                        table.remove(currentContainer.items, i)
                    end
                end
                if #currentContainer.items == 0 then
                    -- Mark container entity as dead so it gets removed from world
                    if currentContainer.entity then
                        currentContainer.entity.dead = true
                    end
                    LootContainerWindow.close()
                end
                return true
            end
        end

        -- Item slots
        for i, slot in ipairs(_slotRects) do
            if mx >= slot.x and mx <= slot.x + slot.w and my >= slot.y and my <= slot.y + slot.h then
                -- Find the corresponding item in the container
                for j, containerStack in ipairs(currentContainer.items) do
                    if containerStack.id == slot.stack.id then
                        tryTransfer(currentPlayer, containerStack, containerStack.qty)
                        if containerStack.qty <= 0 then
                            table.remove(currentContainer.items, j)
                        end
                        if #currentContainer.items == 0 then
                            -- Mark container entity as dead so it gets removed from world
                            if currentContainer.entity then
                                currentContainer.entity.dead = true
                            end
                            LootContainerWindow.close()
                        end
                        return true
                    end
                end
            end
        end
    end

    -- Close if clicking outside window
    if not (mx >= windowX and mx <= windowX + windowW and my >= windowY and my <= windowY + windowH) then
        LootContainerWindow.close()
        return true
    end

    return false
end

function LootContainerWindow.mousereleased(mx, my, button)
    if not isOpen then return false end
    if button == 1 and dragging then
        dragging = false
        return true
    end
    return false
end

function LootContainerWindow.mousemoved(mx, my, dx, dy)
    if not isOpen then return false end
    if dragging then
        local sw, sh = Viewport.getDimensions()
        windowX = math.floor(math.max(0, math.min(sw - windowW, mx - dragDX)))
        windowY = math.floor(math.max(0, math.min(sh - windowH, my - dragDY)))
        return true
    end
    return false
end

function LootContainerWindow.update(dt)
    if not isOpen then return end

    -- Clear hover if mouse is no longer over the item
    if hoveredItem then
        local mx, my = Viewport.getMousePosition()
        local stillHovering = false

        -- Check if mouse is still over one of the slots
        if _slotRects then
            for _, slot in ipairs(_slotRects) do
                if mx >= slot.x and mx <= slot.x + slot.w and my >= slot.y and my <= slot.y + slot.h then
                    stillHovering = true
                    break
                end
            end
        end

        if not stillHovering then
            hoveredItem = nil
            hoverTimer = 0
        end
    end
end

return LootContainerWindow
